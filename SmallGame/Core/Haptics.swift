import UIKit

/// Central haptics helper so game scenes share one intensity vocabulary
/// instead of talking to UIKit generators directly.
enum Haptics {
    /// Checked per call: the player can turn haptics off mid-session from
    /// Settings, and every game asks for feedback through here.
    private static var isEnabled: Bool { SettingsStore().isHapticsEnabled }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notify(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard isEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }
}
