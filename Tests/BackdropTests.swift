import SpriteKit
import Testing
@testable import SmallGame

struct BackdropTests {
    /// Backdrops are generated at one aspect but shown on every iPhone and in
    /// fishing's short sky strip. A stretched backdrop reads as broken art, and
    /// one that spills past its rect paints over its neighbour (sky over water).
    /// The rects cover both crop branches: narrower than the image (trim the
    /// sides) and wider (trim top and bottom — iPhone SE, the sky strip).
    @Test(arguments: [
        CGRect(x: 0, y: 0, width: 300, height: 700),     // narrower than the art
        CGRect(x: 0, y: 0, width: 375, height: 667),     // iPhone SE: wider
        CGRect(x: 0, y: 688, width: 440, height: 268)    // fishing sky strip
    ])
    func fillsItsRectWithoutDistortion(rect: CGRect) throws {
        let scene = MiniGameScene(size: CGSize(width: rect.width, height: rect.maxY))
        scene.addBackdrop("bg_tower.jpg", in: rect)

        let node = try #require(scene.children.first as? SKSpriteNode)
        #expect(node.size == rect.size)
        #expect(node.position == CGPoint(x: rect.midX, y: rect.midY))

        let crop = try #require(node.texture).textureRect()
        #expect(crop.minX >= 0 && crop.minY >= 0 && crop.maxX <= 1 && crop.maxY <= 1)
        let image = SKTexture(imageNamed: "bg_tower.jpg").size()
        let shownAspect = (crop.width * image.width) / (crop.height * image.height)
        #expect(abs(shownAspect - rect.width / rect.height) < 0.001)
    }
}
