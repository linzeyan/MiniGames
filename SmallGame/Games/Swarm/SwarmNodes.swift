import SpriteKit

/// A bug closing in on the kid. `hp <= 0` means squashed: it may still be
/// on screen fading out, but gameplay no longer sees it.
final class SwarmBugNode: SKSpriteNode {
    var kind = SwarmRules.Bug.ant
    var hp: Double = 0
    /// Offset from the kid this bug heads for, so the swarm closes in as a
    /// ring instead of stacking into one sprite.
    var aim = CGVector.zero
    var topImmuneUntil: TimeInterval = 0
}

/// Experience dropped by a squashed bug.
final class CandyNode: SKShapeNode {
    var xp = 1
}

final class FlyingMarble: SKSpriteNode {
    var velocity = CGVector.zero
}

/// XP bar across the top, clear of the pause button, with hearts and
/// level / time / score on the row below.
final class SwarmHUD: SKNode {
    private let hearts = SKLabelNode(fontNamed: "Menlo-Bold")
    private let status = SKLabelNode(fontNamed: "Menlo-Bold")
    private let xpFill: SKSpriteNode

    init(width: CGFloat, top: CGFloat) {
        let barWidth = width - 100
        xpFill = SKSpriteNode(color: .systemYellow, size: CGSize(width: barWidth, height: 10))
        super.init()
        addChild(SwarmStyle.pill(CGRect(x: 16, y: top - 5, width: barWidth, height: 10), alpha: 0.4))
        xpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        xpFill.position = CGPoint(x: 16, y: top)
        xpFill.zPosition = 11
        addChild(xpFill)
        addChild(SwarmStyle.pill(CGRect(x: 10, y: top - 44, width: barWidth + 12, height: 30)))
        hearts.fontColor = UIColor(red: 1, green: 0.4, blue: 0.45, alpha: 1)
        hearts.horizontalAlignmentMode = .left
        hearts.position = CGPoint(x: 22, y: top - 29)
        status.fontColor = .white
        status.horizontalAlignmentMode = .right
        status.position = CGPoint(x: barWidth + 10, y: top - 29)
        for label in [hearts, status] {
            label.fontSize = 16
            label.verticalAlignmentMode = .center
            label.zPosition = 11
            addChild(label)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(hp: Int, level: Int, seconds: Int, squashed: Int, progress: CGFloat) {
        hearts.text = String(repeating: "♥", count: max(0, hp))
        status.text = "Lv\(level)  \(seconds / 60):\(String(format: "%02d", seconds % 60))  ✕\(squashed)"
        xpFill.xScale = min(1, progress)
    }
}

/// One of the three level-up choices.
final class OfferCard: SKShapeNode {
    var upgrade = SwarmRules.Upgrade.bun
}

/// Textures and node factories for the bug swarm.
enum SwarmStyle {
    static let player = SKTexture(imageNamed: "player_stand")
    static let top = SKTexture(imageNamed: "item_top")
    private static let marble = SKTexture(imageNamed: "item_marble")
    private static let ant = SKTexture(imageNamed: "bug_ant")
    private static let mosquito = SKTexture(imageNamed: "bug_mosquito")
    private static let beetle = SKTexture(imageNamed: "bug_beetle")
    private static let swatter = SKTexture(imageNamed: "item_swatter")
    private static let shoe = SKTexture(imageNamed: "item_shoe")
    private static let bun = SKTexture(imageNamed: "item_bun")

    static func makeBug(_ kind: SwarmRules.Bug) -> SwarmBugNode {
        let (texture, side): (SKTexture, CGFloat) = switch kind {
        case .ant: (ant, 30)
        case .mosquito: (mosquito, 28)
        case .beetle: (beetle, 46)
        }
        let node = SwarmBugNode(texture: texture, size: CGSize(width: side, height: side))
        node.kind = kind
        node.zPosition = 3
        return node
    }

    /// Beetles drop the bigger, gold candy worth more.
    static func makeCandy(xp: Int, at position: CGPoint) -> CandyNode {
        let candy = CandyNode(circleOfRadius: xp > 1 ? 7 : 5)
        candy.xp = xp
        candy.fillColor = xp > 1 ? .systemYellow : UIColor(red: 1, green: 0.45, blue: 0.7, alpha: 1)
        candy.strokeColor = .white
        candy.lineWidth = 1.5
        candy.position = position
        candy.zPosition = 1
        return candy
    }

    static func makeMarble(at position: CGPoint, velocity: CGVector) -> FlyingMarble {
        let node = FlyingMarble(texture: marble, size: CGSize(width: 14, height: 14))
        node.position = position
        node.velocity = velocity
        node.zPosition = 4
        return node
    }

    static func makeTop() -> SKSpriteNode {
        let node = SKSpriteNode(texture: top, size: CGSize(width: 28, height: 28))
        node.zPosition = 4
        return node
    }

    /// The swatter's discharge: an electric ring out to its reach.
    static func zap(at position: CGPoint, radius: CGFloat) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.fillColor = UIColor(red: 0.4, green: 0.8, blue: 1, alpha: 0.18)
        ring.strokeColor = UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1)
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.position = position
        ring.zPosition = 2
        ring.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        return ring
    }

    /// Faint ring at the thumb's anchor, so the invisible stick has a
    /// visible center; the knob sits under the thumb.
    static func stickBase() -> SKShapeNode {
        let base = SKShapeNode(circleOfRadius: RelativeSteering.fullThrow)
        base.strokeColor = UIColor(white: 1, alpha: 0.35)
        base.lineWidth = 2
        base.zPosition = 15
        base.alpha = 0
        return base
    }

    static func stickKnob() -> SKShapeNode {
        let knob = SKShapeNode(circleOfRadius: 16)
        knob.fillColor = UIColor(white: 1, alpha: 0.3)
        knob.strokeColor = .clear
        knob.zPosition = 15
        knob.alpha = 0
        return knob
    }

    static func pill(_ rect: CGRect, alpha: CGFloat = 0.35) -> SKShapeNode {
        let pill = SKShapeNode(rect: rect, cornerRadius: rect.height / 2)
        pill.fillColor = UIColor(white: 0, alpha: alpha)
        pill.strokeColor = .clear
        pill.zPosition = 10
        return pill
    }

    /// Center-screen announcement (opening hint) on a pill.
    static func banner(_ text: String, at position: CGPoint, duration: TimeInterval) -> SKNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 17
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        let width = label.frame.width + 32
        let banner = pill(CGRect(x: -width / 2, y: -20, width: width, height: 40))
        banner.addChild(label)
        banner.position = position
        banner.zPosition = 20
        banner.run(.sequence([.wait(forDuration: duration), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        return banner
    }

    /// Dims the field under a title and the upgrade cards to pick from.
    static func offerLayer(_ upgrades: [SwarmRules.Upgrade], levels: [SwarmRules.Weapon: Int],
                           size: CGSize) -> (SKNode, [OfferCard]) {
        let layer = SKNode()
        layer.zPosition = 40
        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.5), size: size)
        dim.position = CGPoint(x: size.width / 2, y: size.height / 2)
        layer.addChild(dim)
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = String(localized: "swarm.level_up")
        title.fontSize = 24
        title.fontColor = .white
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 150)
        layer.addChild(title)
        let cardSize = CGSize(width: size.width - 48, height: 76)
        let cards = upgrades.enumerated().map { index, upgrade in
            let nextLevel = switch upgrade {
            case let .weapon(weapon): levels[weapon, default: 0] + 1
            case .sneakers, .bun: 0
            }
            let card = offerCard(upgrade, nextLevel: nextLevel, size: cardSize)
            card.position = CGPoint(x: size.width / 2, y: size.height / 2 + 80 - CGFloat(index) * 92)
            layer.addChild(card)
            return card
        }
        return (layer, cards)
    }

    /// Level-up card: icon, name with the level it goes to, one-line effect.
    private static func offerCard(_ upgrade: SwarmRules.Upgrade, nextLevel: Int, size: CGSize) -> OfferCard {
        let card = OfferCard(rectOf: size, cornerRadius: 16)
        card.upgrade = upgrade
        card.fillColor = UIColor(red: 0.98, green: 0.94, blue: 0.82, alpha: 1)
        card.strokeColor = UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1)
        card.lineWidth = 2
        let (icon, name, detail) = describe(upgrade)
        let image = SKSpriteNode(texture: icon, size: CGSize(width: size.height - 24, height: size.height - 24))
        image.position = CGPoint(x: -size.width / 2 + size.height / 2, y: 0)
        card.addChild(image)
        let left = -size.width / 2 + size.height + 4
        let title = SKLabelNode(fontNamed: "Menlo-Bold")
        title.text = nextLevel > 0 ? "\(name)  Lv \(nextLevel)" : name
        title.fontSize = 18
        title.fontColor = UIColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1)
        title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: left, y: 4)
        card.addChild(title)
        let body = SKLabelNode(fontNamed: "Menlo")
        body.text = detail
        body.fontSize = 13
        body.fontColor = title.fontColor
        body.horizontalAlignmentMode = .left
        body.position = CGPoint(x: left, y: -18)
        card.addChild(body)
        return card
    }

    private static func describe(_ upgrade: SwarmRules.Upgrade) -> (SKTexture, String, String) {
        switch upgrade {
        case .weapon(.marbles):
            (marble, String(localized: "swarm.marbles"), String(localized: "swarm.marbles.detail"))
        case .weapon(.tops):
            (top, String(localized: "swarm.tops"), String(localized: "swarm.tops.detail"))
        case .weapon(.swatter):
            (swatter, String(localized: "swarm.swatter"), String(localized: "swarm.swatter.detail"))
        case .sneakers:
            (shoe, String(localized: "swarm.sneakers"), String(localized: "swarm.sneakers.detail"))
        case .bun:
            (bun, String(localized: "swarm.bun"), String(localized: "swarm.bun.detail"))
        }
    }
}
