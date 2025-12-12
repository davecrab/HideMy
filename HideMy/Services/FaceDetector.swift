import UIKit
import Vision

/// Service for detecting faces in images using Apple's Vision framework
class FaceDetector {

    /// Detects faces in the given image and returns their bounding boxes in normalized coordinates (0-1)
    /// - Parameter image: The UIImage to analyze for faces
    /// - Returns: An array of DetectedFace objects containing face bounding boxes
    static func detectFaces(in image: UIImage) async -> [DetectedFace] {
        guard let cgImage = image.cgImage else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    print("Face detection error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let faces = observations.map { observation in
                    // Expand bounding box slightly for better coverage
                    let expandedBounds = expandBoundingBox(observation.boundingBox, by: 0.1)
                    return DetectedFace(bounds: expandedBounds)
                }

                continuation.resume(returning: faces)
            }

            // Configure request for accuracy
            request.revision = VNDetectFaceRectanglesRequestRevision3

            let handler = VNImageRequestHandler(
                cgImage: cgImage, orientation: imageOrientation(from: image), options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform face detection: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    /// Detects faces with landmarks for more precise detection
    /// - Parameter image: The UIImage to analyze
    /// - Returns: An array of DetectedFace objects with expanded bounds to include full face area
    static func detectFacesWithLandmarks(in image: UIImage) async -> [DetectedFace] {
        guard let cgImage = image.cgImage else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { request, error in
                if let error = error {
                    print("Face landmarks detection error: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                    return
                }

                guard let observations = request.results as? [VNFaceObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let faces = observations.map { observation in
                    // Expand the bounding box slightly to ensure full face coverage
                    let expandedBounds = expandBoundingBox(observation.boundingBox, by: 0.15)
                    return DetectedFace(bounds: expandedBounds)
                }

                continuation.resume(returning: faces)
            }

            let handler = VNImageRequestHandler(
                cgImage: cgImage, orientation: imageOrientation(from: image), options: [:])

            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform face landmarks detection: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    /// Expands a normalized bounding box by a percentage while keeping it within valid bounds
    /// - Parameters:
    ///   - rect: The original normalized rect (0-1 range)
    ///   - percentage: The percentage to expand by (e.g., 0.1 for 10%)
    /// - Returns: The expanded rect clamped to valid normalized bounds
    private static func expandBoundingBox(_ rect: CGRect, by percentage: CGFloat) -> CGRect {
        let widthExpansion = rect.width * percentage
        let heightExpansion = rect.height * percentage

        var expandedRect = rect.insetBy(dx: -widthExpansion, dy: -heightExpansion)

        // Clamp to valid normalized coordinates (0-1)
        expandedRect.origin.x = max(0, expandedRect.origin.x)
        expandedRect.origin.y = max(0, expandedRect.origin.y)
        expandedRect.size.width = min(1 - expandedRect.origin.x, expandedRect.size.width)
        expandedRect.size.height = min(1 - expandedRect.origin.y, expandedRect.size.height)

        return expandedRect
    }

    /// Converts UIImage orientation to CGImagePropertyOrientation for Vision framework
    /// - Parameter image: The UIImage to get orientation from
    /// - Returns: The corresponding CGImagePropertyOrientation
    private static func imageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:
            return .up
        case .down:
            return .down
        case .left:
            return .left
        case .right:
            return .right
        case .upMirrored:
            return .upMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}

// MARK: - Detected Face Model

/// Represents a detected face in an image
struct DetectedFace: Identifiable {
    let id = UUID()
    let bounds: CGRect  // Normalized coordinates (0-1), origin at bottom-left (Vision coordinates)

    /// Convert to BlurRegion for use in the editor
    func toBlurRegion() -> BlurRegion {
        BlurRegion.fromFace(bounds: bounds)
    }
}
