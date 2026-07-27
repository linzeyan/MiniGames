import SpriteKit

/// Transient on-screen text for the fishing scene: hints, banners, and the
/// per-catch floaters. Factored out of FishingScene so the scene keeps only
/// gameplay state — the labels need nothing but a position and a string.
enum FishingOverlay {
    /// Bottom hint shown once at the start of a session.
    static func hint(_ text: String, at position: CGPoint) -> SKLabelNode {
        let label = makeLabel(text, font: "Menlo", size: 14, color: .white, at: position)
        label.run(.sequence([.wait(forDuration: 3.5),
                             .fadeOut(withDuration: 0.5),
                             .removeFromParent()]))
        return label
    }

    /// Center-screen announcement for big moments (frenzy, time bonus).
    static func banner(_ text: String, at position: CGPoint) -> SKLabelNode {
        let label = makeLabel(text, font: "Menlo-Bold", size: 24, color: .systemOrange, at: position)
        label.zPosition = 20
        label.run(.sequence([.wait(forDuration: 1.6),
                             .fadeOut(withDuration: 0.4),
                             .removeFromParent()]))
        return label
    }

    /// Floating outcome text above the hook — the player must always know
    /// whether that was a catch or junk.
    static func floater(_ text: String, color: UIColor, at position: CGPoint) -> SKLabelNode {
        let label = makeLabel(text, font: "Menlo-Bold", size: 18, color: color, at: position)
        label.zPosition = 15
        label.run(.group([
            .moveBy(x: 0, y: 44, duration: 1.0),
            .sequence([.wait(forDuration: 0.7), .fadeOut(withDuration: 0.3), .removeFromParent()])
        ]))
        return label
    }

    private static func makeLabel(_ text: String, font: String, size: CGFloat,
                                  color: UIColor, at position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: font)
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.position = position
        label.zPosition = 10
        return label
    }
}
