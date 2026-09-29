import SpriteKit

/// A creature (or junk) swimming in the water.
final class FishNode: SKSpriteNode {
    var species = FishingRules.species[0]
    var direction: CGFloat = 1
    var hooked = false
}

/// What the hook is currently doing.
enum HookState {
    case idle
    case casting(target: CGPoint)
    case waiting
    case reeling
}

/// Sprite lookup + styling: which body texture, tint, and display size each
/// species gets. The species table's `body` indexes into `bodies`; hue tints
/// over the neutral bodies give every species its own look.
enum FishingStyle {
    static let fisher = SKTexture(imageNamed: "player_stand")
    private static let bodies = ["fish_a", "fish_long", "fish_round", "shark", "swordfish",
                                 "ray", "turtle", "octopus", "jellyfish"].map { SKTexture(imageNamed: $0) }
    private static let can = SKTexture(imageNamed: "junk_can")
    private static let boot = SKTexture(imageNamed: "junk_boot")

    static func texture(for species: FishingRules.FishSpecies) -> SKTexture {
        if species.isJunk {
            return species.nameKey == "junk.can" ? can : boot
        }
        return bodies[species.body % bodies.count]
    }

    static func makeNode(for species: FishingRules.FishSpecies, direction: CGFloat) -> FishNode {
        let texture = texture(for: species)
        // Keep each creature's own proportions from its sprite.
        let aspect = texture.size().height / max(1, texture.size().width)
        let width: CGFloat = species.isJunk ? 24 : 42
        let node = FishNode(texture: texture, color: .clear,
                            size: CGSize(width: width, height: width * aspect))
        node.species = species
        node.direction = direction
        if !species.isJunk {
            if let hue = species.hue {
                node.color = UIColor(hue: hue, saturation: 0.85, brightness: 0.95, alpha: 1)
                node.colorBlendFactor = 0.75
            }
            // Higher value = bigger creature, an instant read of what's worth chasing.
            node.setScale(0.7 + CGFloat(min(species.points, 120)) / 120 * 0.6)
        }
        // Sprites face right; flip horizontally when swimming left.
        if direction < 0 {
            node.xScale = -node.xScale
        }
        return node
    }

    /// Rowboat hull the fisher stands on.
    static func makeBoat() -> SKShapeNode {
        let hull = CGMutablePath()
        hull.move(to: CGPoint(x: -50, y: 0))
        hull.addLine(to: CGPoint(x: 50, y: 0))
        hull.addLine(to: CGPoint(x: 30, y: -16))
        hull.addLine(to: CGPoint(x: -30, y: -16))
        hull.closeSubpath()
        let boat = SKShapeNode(path: hull)
        boat.fillColor = UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1)
        boat.strokeColor = UIColor(red: 0.4, green: 0.25, blue: 0.13, alpha: 1)
        boat.lineWidth = 2
        return boat
    }

    /// Fishing rod from the fisher's hand to the tip the line hangs from.
    static func makeRod(from hand: CGPoint, to tip: CGPoint) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: hand)
        path.addLine(to: tip)
        let rod = SKShapeNode(path: path)
        rod.strokeColor = UIColor(red: 0.4, green: 0.25, blue: 0.13, alpha: 1) // the boat's trim
        rod.lineWidth = 3
        rod.lineCap = .round
        rod.zPosition = 3 // held in front of the fisher (2)
        return rod
    }
}
