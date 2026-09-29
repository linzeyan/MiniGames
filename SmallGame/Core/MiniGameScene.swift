import SpriteKit

/// Base class for the game scenes.
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

    /// Adds a painted backdrop behind gameplay, aspect-filling `rect`
    /// (default: the whole scene). Crops through the texture rect instead of
    /// overscaling the node, so a backdrop never bleeds past its rect —
    /// fishing stacks a sky image directly on top of a water image.
    func addBackdrop(_ imageName: String, in rect: CGRect? = nil) {
        let rect = rect ?? CGRect(origin: .zero, size: size)
        let full = SKTexture(imageNamed: imageName)
        let imageAspect = full.size().width / full.size().height
        let rectAspect = rect.width / rect.height
        let crop = imageAspect > rectAspect
            ? CGRect(x: (1 - rectAspect / imageAspect) / 2, y: 0, width: rectAspect / imageAspect, height: 1)
            : CGRect(x: 0, y: (1 - imageAspect / rectAspect) / 2, width: 1, height: imageAspect / rectAspect)
        let node = SKSpriteNode(texture: SKTexture(rect: crop, in: full), size: rect.size)
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        node.zPosition = -10
        addChild(node)
    }
}
