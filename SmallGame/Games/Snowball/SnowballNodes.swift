import SpriteKit

/// Textures and node factories for the snowball fight. Kept out of the scene
/// so it holds gameplay state only — none of this needs to know the rules.
enum SnowballStyle {
    static let player = SKTexture(imageNamed: "player_stand")
    static let enemy = SKTexture(imageNamed: "enemy_stand")
    static let enemyHit = SKTexture(imageNamed: "enemy_hit")

    /// Decorative snow strip under everyone's feet.
    static func groundTiles(width: CGFloat, y: CGFloat) -> [SKSpriteNode] {
        let tileWidth: CGFloat = 92
        var tiles: [SKSpriteNode] = []
        var tileX = tileWidth / 2
        while tileX - tileWidth / 2 < width {
            let tile = SKSpriteNode(texture: SKTexture(imageNamed: "platform_snow"),
                                    size: CGSize(width: tileWidth, height: 16))
            tile.position = CGPoint(x: tileX, y: y)
            tile.zPosition = -1
            tiles.append(tile)
            tileX += tileWidth
        }
        return tiles
    }

    /// Dotted trajectory preview; the scene positions them while aiming.
    static func aimDots(count: Int) -> [SKShapeNode] {
        (0..<count).map { _ in
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = .darkGray
            dot.strokeColor = .clear
            dot.alpha = 0
            dot.zPosition = 5
            return dot
        }
    }

    /// Center-screen announcement (level up, opening hint).
    static func banner(_ text: String, at position: CGPoint, duration: TimeInterval) -> SKLabelNode {
        let banner = SKLabelNode(fontNamed: "Menlo-Bold")
        banner.text = text
        banner.fontSize = 22
        banner.fontColor = .darkGray
        banner.position = position
        banner.zPosition = 20
        banner.run(.sequence([.wait(forDuration: duration),
                              .fadeOut(withDuration: 0.3),
                              .removeFromParent()]))
        return banner
    }
}
