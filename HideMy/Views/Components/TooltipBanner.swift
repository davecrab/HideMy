import SwiftUI

/// Keys for storing tooltip dismissal state in UserDefaults
enum TooltipKey: String {
    case photoGridSelect = "tooltip_photoGrid_select"
    case photoEditBlur = "tooltip_photoEdit_blur"

    var defaultsKey: String {
        return rawValue
    }
}

/// A reusable dismissible tooltip banner component
struct TooltipBanner: View {
    let icon: String
    let message: LocalizedStringKey
    let tooltipKey: TooltipKey
    var backgroundColor: Color = .blue
    var iconColor: Color = .white
    var textColor: Color = .white

    @State private var isDismissed: Bool
    @State private var isVisible: Bool = true

    init(
        icon: String,
        message: LocalizedStringKey,
        tooltipKey: TooltipKey,
        backgroundColor: Color = .blue,
        iconColor: Color = .white,
        textColor: Color = .white
    ) {
        self.icon = icon
        self.message = message
        self.tooltipKey = tooltipKey
        self.backgroundColor = backgroundColor
        self.iconColor = iconColor
        self.textColor = textColor

        // Check if already dismissed
        self._isDismissed = State(
            initialValue: UserDefaults.standard.bool(forKey: tooltipKey.defaultsKey))
    }

    var body: some View {
        if !isDismissed && isVisible {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .accessibilityHidden(true)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(textColor.opacity(0.8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("accessibility.dismissTooltip"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(backgroundColor.gradient)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }

        // Persist dismissal
        UserDefaults.standard.set(true, forKey: tooltipKey.defaultsKey)

        // Update state after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isDismissed = true
        }
    }
}

/// A helper class to manage tooltip state
class TooltipManager {
    static let shared = TooltipManager()

    private init() {}

    /// Resets a specific tooltip so it will show again
    func resetTooltip(_ key: TooltipKey) {
        UserDefaults.standard.removeObject(forKey: key.defaultsKey)
    }

    /// Resets all tooltips so they will show again
    func resetAllTooltips() {
        for key in [TooltipKey.photoGridSelect, TooltipKey.photoEditBlur] {
            UserDefaults.standard.removeObject(forKey: key.defaultsKey)
        }
    }

    /// Checks if a tooltip has been dismissed
    func isTooltipDismissed(_ key: TooltipKey) -> Bool {
        return UserDefaults.standard.bool(forKey: key.defaultsKey)
    }
}

#Preview("Tooltip Banner") {
    VStack {
        TooltipBanner(
            icon: "hand.tap",
            message: "photoGrid.tooltip",
            tooltipKey: .photoGridSelect
        )

        TooltipBanner(
            icon: "faceid",
            message: "photoEdit.tooltip.blur",
            tooltipKey: .photoEditBlur,
            backgroundColor: .purple
        )

        Spacer()
    }
}
