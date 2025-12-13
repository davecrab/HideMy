import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Handles secure face blurring that cannot be reversed or reconstructed
class ImageBlurrer {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    /// Blur intensity levels
    enum BlurIntensity: CGFloat, CaseIterable {
        case light = 0.25
        case medium = 0.5
        case strong = 0.75
        case maximum = 1.0

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .medium: return "Medium"
            case .strong: return "Strong"
            case .maximum: return "Maximum"
            }
        }

        /// Returns the pixel block divisor (higher = more pixelated)
        var pixelDivisor: CGFloat {
            switch self {
            case .light: return 16
            case .medium: return 10
            case .strong: return 6
            case .maximum: return 4
            }
        }
    }

    /// Applies a secure, irreversible blur to regions in an image
    /// Uses heavy pixelation combined with blur to ensure facial features cannot be recovered
    /// - Parameters:
    ///   - image: The original image
    ///   - regions: Array of blur regions with normalized coordinates and rotation
    ///   - intensity: The blur intensity level (affects pixel size)
    ///   - mode: The privacy mode to use (defaults to current setting)
    /// - Returns: The blurred image, or nil if blurring failed
    static func applySecureBlur(
        to image: UIImage,
        regions: [BlurRegionData],
        intensity: CGFloat = 0.75,
        mode: PrivacyMode? = nil
    ) -> UIImage? {
        let privacyMode = mode ?? PrivacySettings.shared.privacyMode

        // Handle box modes separately
        if privacyMode.isBoxMode {
            let color = PrivacySettings.shared.getBoxColor()
            return applySolidBlock(to: image, regions: regions, color: color)
        }

        guard let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        var resultImage = ciImage

        for region in regions {
            // Convert normalized rect to pixel coordinates
            // Vision uses bottom-left origin, Core Image also uses bottom-left
            let pixelRect = CGRect(
                x: region.bounds.origin.x * imageSize.width,
                y: region.bounds.origin.y * imageSize.height,
                width: region.bounds.width * imageSize.width,
                height: region.bounds.height * imageSize.height
            )

            // Expand the rect slightly to ensure full coverage
            let expandedRect = pixelRect.insetBy(
                dx: -pixelRect.width * 0.15,
                dy: -pixelRect.height * 0.15
            )

            // Apply secure blur to this region
            if let blurredRegion = applySecureBlurToRegion(
                resultImage,
                region: expandedRect,
                rotation: region.rotation,
                intensity: intensity,
                mode: privacyMode
            ) {
                resultImage = blurredRegion
            }
        }

        // Render the final image
        guard let outputCGImage = context.createCGImage(resultImage, from: resultImage.extent)
        else {
            return nil
        }

        return UIImage(
            cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Legacy method for backward compatibility with simple CGRect arrays
    static func applySecureBlur(
        to image: UIImage,
        faceRects: [CGRect],
        intensity: CGFloat = 0.75
    ) -> UIImage? {
        let regions = faceRects.map { BlurRegionData(bounds: $0, rotation: 0) }
        return applySecureBlur(to: image, regions: regions, intensity: intensity)
    }

    /// Applies a secure, irreversible blur to a specific region
    /// Uses multiple passes of pixelation and blur to ensure data is destroyed
    private static func applySecureBlurToRegion(
        _ image: CIImage,
        region: CGRect,
        rotation: CGFloat,
        intensity: CGFloat,
        mode: PrivacyMode = .fullBlur
    ) -> CIImage? {
        // First, crop the region we want to blur
        let clampedRegion = region.intersection(image.extent)
        guard !clampedRegion.isEmpty else { return image }

        // Calculate pixel size based on intensity (0.25 to 1.0)
        // Higher intensity = larger pixels = more blur
        let baseDivisor: CGFloat = 4 + (1 - intensity) * 16  // Range: 4 to 20
        let pixelSize = max(clampedRegion.width, clampedRegion.height) / baseDivisor

        var blurredRegion = image.cropped(to: clampedRegion)

        // If there's rotation, we need to handle it
        if abs(rotation) > 0.01 {
            blurredRegion =
                applyRotatedBlur(
                    to: blurredRegion,
                    in: image,
                    region: clampedRegion,
                    rotation: rotation,
                    pixelSize: pixelSize,
                    intensity: intensity,
                    mode: mode
                ) ?? blurredRegion
        } else {
            blurredRegion = applyBlurPipeline(
                to: blurredRegion,
                pixelSize: pixelSize,
                intensity: intensity,
                mode: mode
            )
        }

        // Composite the blurred region back onto the original image
        let composited = blurredRegion.composited(over: image)

        return composited
    }

    /// Applies the blur pipeline based on the privacy mode
    private static func applyBlurPipeline(
        to image: CIImage,
        pixelSize: CGFloat,
        intensity: CGFloat,
        mode: PrivacyMode
    ) -> CIImage {
        var result = image

        switch mode {
        case .fullBlur:
            // Step 1: Heavy pixelation - this destroys fine detail irreversibly
            if let pixellated = applyPixelation(to: result, scale: pixelSize) {
                result = pixellated
            }

            // Step 2: Apply Gaussian blur on top of pixelation for additional security
            let blurRadius = pixelSize * 0.5 * intensity
            if let blurred = applyGaussianBlur(to: result, radius: blurRadius) {
                result = blurred
            }

            // Step 3: Re-pixelate to ensure uniform blocks (prevents gradient analysis)
            if let pixellated = applyPixelation(to: result, scale: pixelSize * 1.2) {
                result = pixellated
            }

        case .blurNoFinalPixelate:
            // Step 1: Heavy pixelation
            if let pixellated = applyPixelation(to: result, scale: pixelSize) {
                result = pixellated
            }

            // Step 2: Apply Gaussian blur (no final pixelation for smoother look)
            let blurRadius = pixelSize * 0.5 * intensity
            if let blurred = applyGaussianBlur(to: result, radius: blurRadius) {
                result = blurred
            }

        case .pixelateOnly:
            // Only pixelation, no blur
            if let pixellated = applyPixelation(to: result, scale: pixelSize) {
                result = pixellated
            }

        default:
            // Box modes are handled separately, but fallback to full blur
            if let pixellated = applyPixelation(to: result, scale: pixelSize) {
                result = pixellated
            }
            let blurRadius = pixelSize * 0.5 * intensity
            if let blurred = applyGaussianBlur(to: result, radius: blurRadius) {
                result = blurred
            }
            if let pixellated = applyPixelation(to: result, scale: pixelSize * 1.2) {
                result = pixellated
            }
        }

        return result
    }

    /// Applies blur to a rotated rectangular region
    private static func applyRotatedBlur(
        to region: CIImage,
        in originalImage: CIImage,
        region rect: CGRect,
        rotation: CGFloat,
        pixelSize: CGFloat,
        intensity: CGFloat,
        mode: PrivacyMode = .fullBlur
    ) -> CIImage? {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // Create a larger work area to accommodate rotation
        let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
        let workRect = CGRect(
            x: center.x - diagonal / 2,
            y: center.y - diagonal / 2,
            width: diagonal,
            height: diagonal
        ).intersection(originalImage.extent)

        var workImage = originalImage.cropped(to: workRect)

        // Rotate around center
        let rotateTransform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: -rotation)
            .translatedBy(x: -center.x, y: -center.y)

        workImage = workImage.transformed(by: rotateTransform)

        // Apply blur pipeline based on mode
        workImage = applyBlurPipeline(
            to: workImage,
            pixelSize: pixelSize,
            intensity: intensity,
            mode: mode
        )

        // Rotate back
        let inverseTransform = CGAffineTransform(translationX: center.x, y: center.y)
            .rotated(by: rotation)
            .translatedBy(x: -center.x, y: -center.y)

        workImage = workImage.transformed(by: inverseTransform)

        // Crop to original region bounds
        workImage = workImage.cropped(to: rect)

        return workImage
    }

    /// Applies pixelation effect to an image
    private static func applyPixelation(to image: CIImage, scale: CGFloat) -> CIImage? {
        let pixelateFilter = CIFilter.pixellate()
        pixelateFilter.inputImage = image
        pixelateFilter.scale = Float(max(scale, 8))  // Minimum 8px blocks
        pixelateFilter.center = CGPoint(x: image.extent.midX, y: image.extent.midY)

        return pixelateFilter.outputImage
    }

    /// Applies Gaussian blur to an image
    private static func applyGaussianBlur(to image: CIImage, radius: CGFloat) -> CIImage? {
        let blurFilter = CIFilter.gaussianBlur()
        blurFilter.inputImage = image
        blurFilter.radius = Float(max(radius, 3))

        // Clamp to extent to prevent edge bleeding
        return blurFilter.outputImage?.cropped(to: image.extent)
    }

    /// Creates a solid color block over regions (maximum privacy)
    static func applySolidBlock(
        to image: UIImage,
        regions: [BlurRegionData],
        color: UIColor = .black
    ) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        var resultImage = ciImage

        for region in regions {
            let pixelRect = CGRect(
                x: region.bounds.origin.x * imageSize.width,
                y: region.bounds.origin.y * imageSize.height,
                width: region.bounds.width * imageSize.width,
                height: region.bounds.height * imageSize.height
            )

            let expandedRect = pixelRect.insetBy(
                dx: -pixelRect.width * 0.1,
                dy: -pixelRect.height * 0.1
            )

            // Create a solid color rectangle
            var colorImage = CIImage(color: CIColor(color: color))
                .cropped(to: expandedRect)

            // Apply rotation if needed
            if abs(region.rotation) > 0.01 {
                let center = CGPoint(x: expandedRect.midX, y: expandedRect.midY)
                let transform = CGAffineTransform(translationX: center.x, y: center.y)
                    .rotated(by: region.rotation)
                    .translatedBy(x: -center.x, y: -center.y)
                colorImage = colorImage.transformed(by: transform).cropped(to: expandedRect)
            }

            resultImage = colorImage.composited(over: resultImage)
        }

        guard let outputCGImage = context.createCGImage(resultImage, from: resultImage.extent)
        else {
            return nil
        }

        return UIImage(
            cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Blur Region Data

/// Simple struct for passing blur region data to the blurrer
struct BlurRegionData {
    let bounds: CGRect  // Normalized coordinates (0-1)
    let rotation: CGFloat  // Radians
}
