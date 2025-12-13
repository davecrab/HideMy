import SwiftUI

/// Defines the different privacy modes for face covering
enum PrivacyMode: String, CaseIterable, Identifiable {
    case fullBlur = "fullBlur"
    case blurNoFinalPixelate = "blurNoFinalPixelate"
    case pixelateOnly = "pixelateOnly"
    case blackBox = "blackBox"
    case whiteBox = "whiteBox"
    case customBox = "customBox"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBlur: return "Full Blur"
        case .blurNoFinalPixelate: return "Blur (No Final Pixelate)"
        case .pixelateOnly: return "Pixelate Only"
        case .blackBox: return "Black Box"
        case .whiteBox: return "White Box"
        case .customBox: return "Custom Color Box"
        }
    }

    var description: String {
        switch self {
        case .fullBlur: return "Pixelate → Blur → Pixelate (maximum privacy)"
        case .blurNoFinalPixelate: return "Pixelate → Blur (smoother look)"
        case .pixelateOnly: return "Pixelate only (classic mosaic)"
        case .blackBox: return "Solid black rectangle"
        case .whiteBox: return "Solid white rectangle"
        case .customBox: return "Solid color of your choice"
        }
    }

    /// Localized display name for the privacy mode
    var localizedName: String {
        switch self {
        case .fullBlur: return String(localized: "privacyMode.fullBlur")
        case .blurNoFinalPixelate: return String(localized: "privacyMode.blurNoFinalPixelate")
        case .pixelateOnly: return String(localized: "privacyMode.pixelateOnly")
        case .blackBox: return String(localized: "privacyMode.blackBox")
        case .whiteBox: return String(localized: "privacyMode.whiteBox")
        case .customBox: return String(localized: "privacyMode.customBox")
        }
    }

    /// Localized description for the privacy mode
    var localizedDescription: String {
        switch self {
        case .fullBlur: return String(localized: "privacyMode.fullBlur.description")
        case .blurNoFinalPixelate:
            return String(localized: "privacyMode.blurNoFinalPixelate.description")
        case .pixelateOnly: return String(localized: "privacyMode.pixelateOnly.description")
        case .blackBox: return String(localized: "privacyMode.blackBox.description")
        case .whiteBox: return String(localized: "privacyMode.whiteBox.description")
        case .customBox: return String(localized: "privacyMode.customBox.description")
        }
    }

    var iconName: String {
        switch self {
        case .fullBlur: return "circle.grid.3x3.fill"
        case .blurNoFinalPixelate: return "drop.fill"
        case .pixelateOnly: return "square.grid.3x3.fill"
        case .blackBox: return "rectangle.fill"
        case .whiteBox: return "rectangle"
        case .customBox: return "paintpalette.fill"
        }
    }

    var isBoxMode: Bool {
        switch self {
        case .blackBox, .whiteBox, .customBox:
            return true
        default:
            return false
        }
    }
}

/// Manages privacy settings for the app
class PrivacySettings: ObservableObject {
    static let shared = PrivacySettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let privacyMode = "privacyMode"
        static let customBoxColorRed = "customBoxColorRed"
        static let customBoxColorGreen = "customBoxColorGreen"
        static let customBoxColorBlue = "customBoxColorBlue"
        static let customBoxColorAlpha = "customBoxColorAlpha"
    }

    @Published var privacyMode: PrivacyMode {
        didSet {
            defaults.set(privacyMode.rawValue, forKey: Keys.privacyMode)
        }
    }

    @Published var customBoxColor: Color {
        didSet {
            saveCustomColor()
        }
    }

    private init() {
        // Load privacy mode
        if let savedMode = defaults.string(forKey: Keys.privacyMode),
            let mode = PrivacyMode(rawValue: savedMode)
        {
            self.privacyMode = mode
        } else {
            self.privacyMode = .fullBlur  // Default
        }

        // Load custom color
        let red = defaults.double(forKey: Keys.customBoxColorRed)
        let green = defaults.double(forKey: Keys.customBoxColorGreen)
        let blue = defaults.double(forKey: Keys.customBoxColorBlue)
        let alpha = defaults.object(forKey: Keys.customBoxColorAlpha) as? Double ?? 1.0

        if red != 0 || green != 0 || blue != 0 {
            self.customBoxColor = Color(
                red: red,
                green: green,
                blue: blue,
                opacity: alpha
            )
        } else {
            self.customBoxColor = .gray  // Default custom color
        }
    }

    private func saveCustomColor() {
        let uiColor = UIColor(customBoxColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        defaults.set(Double(red), forKey: Keys.customBoxColorRed)
        defaults.set(Double(green), forKey: Keys.customBoxColorGreen)
        defaults.set(Double(blue), forKey: Keys.customBoxColorBlue)
        defaults.set(Double(alpha), forKey: Keys.customBoxColorAlpha)
    }

    /// Returns the UIColor for box modes
    func getBoxColor() -> UIColor {
        switch privacyMode {
        case .blackBox:
            return .black
        case .whiteBox:
            return .white
        case .customBox:
            return UIColor(customBoxColor)
        default:
            return .black
        }
    }
}
