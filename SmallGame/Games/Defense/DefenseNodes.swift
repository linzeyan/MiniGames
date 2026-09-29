import SpriteKit

/// A defender standing on a board cell.
final class DefenderNode: SKSpriteNode {
    var kind = DefenseRules.Defender.piggyBank
    var cell = DefenseRules.Cell(lane: 0, row: 0)
    var hp: Double = 0
    /// Game time of its next coin, shot or blast.
    var nextAction: TimeInterval = 0
}

/// A bug walking down its lane. `hp <= 0` means squashed: it may still be
/// on screen playing its death, but gameplay no longer sees it.
final class BugNode: SKSpriteNode {
    var kind = DefenseRules.Bug.ant
    var lane = 0
    var hp: Double = 0
}

/// A marble flying up a lane.
final class MarbleNode: SKShapeNode {
    var lane = 0
}

/// A card in the bottom tray: the defender and its price, with a shade that
/// drains as the card recharges.
final class CardNode: SKShapeNode {
    var kind = DefenseRules.Defender.piggyBank
    var shade = SKShapeNode()

    func show(selected: Bool, affordable: Bool, recharge: Double) {
        strokeColor = selected ? .systemYellow : DefenseStyle.wood
        lineWidth = selected ? 4 : 2
        alpha = affordable ? 1 : 0.5
        shade.yScale = recharge
    }
}

/// Textures and node factories for the lunchbox defense.
enum DefenseStyle {
    static let wood = UIColor(red: 0.45, green: 0.3, blue: 0.15, alpha: 1)
    static let slipper = SKTexture(imageNamed: "def_slipper")
    static let coin = SKTexture(imageNamed: "item_coin")
    private static let piggy = SKTexture(imageNamed: "def_piggy")
    private static let slingshot = SKTexture(imageNamed: "def_slingshot")
    private static let schoolbag = SKTexture(imageNamed: "def_schoolbag")
    private static let firecracker = SKTexture(imageNamed: "def_firecracker")
    private static let ant = SKTexture(imageNamed: "bug_ant")
    private static let roach = SKTexture(imageNamed: "bug_roach")
    private static let beetle = SKTexture(imageNamed: "bug_beetle")

    static func texture(for defender: DefenseRules.Defender) -> SKTexture {
        switch defender {
        case .piggyBank: piggy
        case .slingshot: slingshot
        case .schoolbag: schoolbag
        case .firecracker: firecracker
        }
    }

    static func makeDefender(_ kind: DefenseRules.Defender, cell: CGFloat) -> DefenderNode {
        let node = DefenderNode(texture: texture(for: kind), size: CGSize(width: cell * 0.8, height: cell * 0.8))
        node.kind = kind
        node.hp = kind.hp
        node.zPosition = 2
        if kind == .firecracker {
            // The lit fuse: jitter until it goes off.
            node.run(.repeatForever(.sequence([.rotate(toAngle: 0.15, duration: 0.05),
                                               .rotate(toAngle: -0.15, duration: 0.05)])))
        }
        return node
    }

    /// Size tells the kinds apart at a glance: the beetle is the one to worry about.
    static func makeBug(_ kind: DefenseRules.Bug, cell: CGFloat) -> BugNode {
        let (texture, scale): (SKTexture, CGFloat) = switch kind {
        case .ant: (ant, 0.62)
        case .roach: (roach, 0.7)
        case .beetle: (beetle, 0.92)
        }
        let node = BugNode(texture: texture, size: CGSize(width: cell * scale, height: cell * scale))
        node.kind = kind
        node.zPosition = 3
        return node
    }

    static func makeMarble(lane: Int) -> MarbleNode {
        let marble = MarbleNode(circleOfRadius: 5)
        marble.lane = lane
        marble.fillColor = UIColor(red: 0.55, green: 0.8, blue: 0.95, alpha: 1)
        marble.strokeColor = .white
        marble.lineWidth = 1.5
        marble.zPosition = 4
        return marble
    }

    static func makeCard(for kind: DefenseRules.Defender, size: CGSize) -> CardNode {
        let card = CardNode(rectOf: size, cornerRadius: 12)
        card.kind = kind
        card.fillColor = UIColor(red: 0.98, green: 0.94, blue: 0.82, alpha: 1)
        card.zPosition = 10
        let icon = SKSpriteNode(texture: texture(for: kind),
                                size: CGSize(width: size.height * 0.6, height: size.height * 0.6))
        icon.position = CGPoint(x: 0, y: 8)
        card.addChild(icon)
        let price = SKLabelNode(fontNamed: "Menlo-Bold")
        price.text = "\(kind.cost)"
        price.fontSize = 14
        price.fontColor = wood
        price.position = CGPoint(x: 0, y: -size.height / 2 + 7)
        card.addChild(price)
        // Drawn from the card's bottom edge so yScale drains it downward.
        card.shade.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: 0, width: size.width, height: size.height),
                                 cornerWidth: 12, cornerHeight: 12, transform: nil)
        card.shade.fillColor = UIColor(white: 0, alpha: 0.45)
        card.shade.strokeColor = .clear
        card.shade.position = CGPoint(x: 0, y: -size.height / 2)
        card.addChild(card.shade)
        card.show(selected: false, affordable: true, recharge: 0)
        return card
    }

    /// Checkerboard over the lawn so the cells read without grid lines.
    static func boardTiles(cell: CGFloat, rows: Int, bottom: CGFloat) -> [SKSpriteNode] {
        var tiles: [SKSpriteNode] = []
        for lane in 0..<DefenseRules.lanes {
            for row in 0..<rows {
                let tile = SKSpriteNode(color: UIColor(white: 1, alpha: (lane + row) % 2 == 0 ? 0.16 : 0.04),
                                        size: CGSize(width: cell, height: cell))
                tile.position = CGPoint(x: cell * (CGFloat(lane) + 0.5), y: bottom + cell * (CGFloat(row) + 0.5))
                tile.zPosition = -5
                tiles.append(tile)
            }
        }
        return tiles
    }

    /// Wooden desk the cards sit on.
    static func tray(width: CGFloat, height: CGFloat) -> SKShapeNode {
        let tray = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: height))
        tray.fillColor = wood.withAlphaComponent(0.85)
        tray.strokeColor = .clear
        tray.zPosition = 5
        return tray
    }

    /// Dark pill behind HUD text, which would otherwise sink into the lawn.
    static func pill(_ rect: CGRect) -> SKShapeNode {
        let pill = SKShapeNode(rect: rect, cornerRadius: rect.height / 2)
        pill.fillColor = UIColor(white: 0, alpha: 0.35)
        pill.strokeColor = .clear
        pill.zPosition = 10
        return pill
    }

    /// "+25" rising off whatever just earned it.
    static func floatingText(_ text: String, at position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = 18
        label.fontColor = .systemYellow
        label.position = position
        label.zPosition = 30
        label.run(.sequence([.group([.moveBy(x: 0, y: 36, duration: 0.8), .fadeOut(withDuration: 0.8)]),
                             .removeFromParent()]))
        return label
    }

    /// Center-screen announcement (wave start, opening hint) on a pill.
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

    static func blast(at position: CGPoint, radius: CGFloat) -> SKShapeNode {
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.fillColor = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 0.5)
        ring.strokeColor = UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1)
        ring.lineWidth = 4
        ring.position = position
        ring.zPosition = 25
        ring.setScale(0.2)
        ring.run(.sequence([.group([.scale(to: 1, duration: 0.18), .fadeOut(withDuration: 0.35)]),
                            .removeFromParent()]))
        return ring
    }
}
