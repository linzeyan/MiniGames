import SpriteKit

/// Base class for the four game scenes.
/// The scene reports game-over upward via `onGameOver`; SwiftUI
/// (`GameHostView`) owns navigation, overlays, and score persistence, so
/// scenes stay focused on gameplay.
class MiniGameScene: SKScene {
    /// Set by GameHostView before the scene is presented.
    var onGameOver: ((_ score: Int) -> Void)?

    /// Freezes gameplay while an overlay (instructions / pause menu) is up.
    /// Unlike SKScene.isPaused this keeps the scene RENDERING — an SKView
    /// paused before its first frame shows nothing but gray.
    var isHeld = false

    /// Subclasses reset all gameplay state for a fresh run.
    func restart() {
        // Default: no-op; concrete scenes override.
    }

    /// Top-right corner reserved for GameHostView's pause button.
    ///
    /// SpriteKit cannot swallow the SwiftUI button's touches, so a scene that
    /// acts on every tap (fishing casts a line) steals the near-misses and
    /// the button feels dead. Scenes like that must ignore this corner.
    /// Sized generously to cover the tallest safe-area inset.
    func isUnderPauseButton(_ point: CGPoint) -> Bool {
        point.x > size.width - 88 && point.y > size.height - 124
    }
}
