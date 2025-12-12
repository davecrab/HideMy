import Foundation
import SwiftUI

/// Represents a region to be blurred in an image
struct BlurRegion: Identifiable, Equatable {
    let id = UUID()

    /// The type of blur region
    enum RegionType: Equatable {
        case face  // Auto-detected face
        case custom  // User-defined region
    }

    /// The type of this region
    var type: RegionType

    /// Normalized bounds (0-1 coordinates, origin at bottom-left for Vision compatibility)
    var bounds: CGRect

    /// Rotation angle in radians
    var rotation: CGFloat = 0

    /// Whether this region has been blurred
    var isBlurred: Bool = false

    /// Whether this region is currently selected
    var isSelected: Bool = false

    // MARK: - Computed Properties

    /// Center point in normalized coordinates
    var center: CGPoint {
        CGPoint(x: bounds.midX, y: bounds.midY)
    }

    // MARK: - Initialization

    init(type: RegionType, bounds: CGRect, rotation: CGFloat = 0) {
        self.type = type
        self.bounds = bounds
        self.rotation = rotation
    }

    /// Create from a detected face bounds
    static func fromFace(bounds: CGRect) -> BlurRegion {
        BlurRegion(type: .face, bounds: bounds)
    }

    /// Create a custom region at a tap point
    static func customRegion(
        at normalizedPoint: CGPoint, size: CGSize = CGSize(width: 0.15, height: 0.1)
    ) -> BlurRegion {
        let bounds = CGRect(
            x: normalizedPoint.x - size.width / 2,
            y: normalizedPoint.y - size.height / 2,
            width: size.width,
            height: size.height
        ).clamped(to: CGRect(x: 0, y: 0, width: 1, height: 1))

        return BlurRegion(type: .custom, bounds: bounds)
    }

    // MARK: - Transform Methods

    /// Returns a new region with updated bounds
    func withBounds(_ newBounds: CGRect) -> BlurRegion {
        var copy = self
        copy.bounds = newBounds.clamped(to: CGRect(x: 0, y: 0, width: 1, height: 1))
        return copy
    }

    /// Returns a new region with updated rotation
    func withRotation(_ newRotation: CGFloat) -> BlurRegion {
        var copy = self
        copy.rotation = newRotation
        return copy
    }

    /// Returns a new region scaled by a factor
    func scaled(by factor: CGFloat) -> BlurRegion {
        let newWidth = bounds.width * factor
        let newHeight = bounds.height * factor
        let newX = bounds.midX - newWidth / 2
        let newY = bounds.midY - newHeight / 2

        let newBounds = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
        return withBounds(newBounds)
    }

    /// Returns a new region moved by a delta
    func moved(by delta: CGSize, in imageSize: CGSize) -> BlurRegion {
        let normalizedDeltaX = delta.width / imageSize.width
        let normalizedDeltaY = -delta.height / imageSize.height  // Flip Y for Vision coordinates

        let newBounds = CGRect(
            x: bounds.origin.x + normalizedDeltaX,
            y: bounds.origin.y + normalizedDeltaY,
            width: bounds.width,
            height: bounds.height
        )
        return withBounds(newBounds)
    }

    /// Returns a new region resized from a corner/edge
    func resized(by delta: CGSize, from handle: ResizeHandle, in imageSize: CGSize) -> BlurRegion {
        let normalizedDeltaX = delta.width / imageSize.width
        let normalizedDeltaY = -delta.height / imageSize.height

        var newBounds = bounds

        switch handle {
        case .topLeft:
            newBounds.origin.x += normalizedDeltaX
            newBounds.size.width -= normalizedDeltaX
            newBounds.size.height += normalizedDeltaY
        case .topRight:
            newBounds.size.width += normalizedDeltaX
            newBounds.size.height += normalizedDeltaY
        case .bottomLeft:
            newBounds.origin.x += normalizedDeltaX
            newBounds.origin.y += normalizedDeltaY
            newBounds.size.width -= normalizedDeltaX
            newBounds.size.height -= normalizedDeltaY
        case .bottomRight:
            newBounds.origin.y += normalizedDeltaY
            newBounds.size.width += normalizedDeltaX
            newBounds.size.height -= normalizedDeltaY
        case .top:
            newBounds.size.height += normalizedDeltaY
        case .bottom:
            newBounds.origin.y += normalizedDeltaY
            newBounds.size.height -= normalizedDeltaY
        case .left:
            newBounds.origin.x += normalizedDeltaX
            newBounds.size.width -= normalizedDeltaX
        case .right:
            newBounds.size.width += normalizedDeltaX
        }

        // Ensure minimum size
        let minSize: CGFloat = 0.03
        if newBounds.width < minSize {
            newBounds.size.width = minSize
        }
        if newBounds.height < minSize {
            newBounds.size.height = minSize
        }

        return withBounds(newBounds)
    }
}

// MARK: - Resize Handle

enum ResizeHandle: CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight
    case top, bottom, left, right

    var isCorner: Bool {
        switch self {
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            return true
        default:
            return false
        }
    }
}

// MARK: - CGRect Extension

extension CGRect {
    /// Returns a rect clamped to the given bounds
    func clamped(to bounds: CGRect) -> CGRect {
        var result = self

        // Clamp origin
        result.origin.x = max(bounds.minX, min(result.origin.x, bounds.maxX - result.width))
        result.origin.y = max(bounds.minY, min(result.origin.y, bounds.maxY - result.height))

        // Clamp size
        if result.maxX > bounds.maxX {
            result.size.width = bounds.maxX - result.origin.x
        }
        if result.maxY > bounds.maxY {
            result.size.height = bounds.maxY - result.origin.y
        }

        return result
    }
}
