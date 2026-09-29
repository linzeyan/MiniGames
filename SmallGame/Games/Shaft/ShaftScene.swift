import SpriteKit

/// Kenney "Platformer Pack Redux" themed platform: theme encodes behaviour
/// (grass = safe, spikes = hurt, snow = crumbles, sand = conveyor).
final class PlatformNode: SKSpriteNode {
    let kind: PlatformKind
    let index: Int
    /// Conveyor push direction: -1 or 1 (0 for other kinds).
    let beltDirection: CGFloat

    init(kind: PlatformKind, index: Int, size: CGSize, beltDirection: CGFloat = 0) {
        self.kind = kind
        self.index = index
        self.beltDirection = beltDirection
        let imageName = switch kind {
        case .normal, .spring: "platform_grass"
        case .spike: "tile_spikes"
        case .conveyor: "platform_sand"
        case .fragile: "platform_snow"
        }
        super.init(texture: SKTexture(imageNamed: imageName), color: .white, size: size)
        if kind == .spring {
            let spring = SKSpriteNode(texture: SKTexture(imageNamed: "tile_spring"),
                                      size: CGSize(width: 22, height: 22))
            spring.position = CGPoint(x: 0, y: size.height / 2 + 10)
            addChild(spring)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// "Down We Go" — descend as far as possible. Platforms scroll upward;
/// ceiling spikes hurt, falling off the bottom ends the run.
final class ShaftScene: MiniGameScene {
    private enum T {
        static let gravity: CGFloat = -1400
        static let maxFallSpeed: CGFloat = -900
        static let moveSpeed: CGFloat = 240
        static let baseScrollSpeed: CGFloat = 85
        static let platformSize = CGSize(width: 88, height: 16)
        static let playerSize = CGSize(width: 26, height: 34)
        static let verticalGap: CGFloat = 95
        static let springVelocity: CGFloat = 780
        static let beltSpeed: CGFloat = 95
        static let ceilingHeight: CGFloat = 90
        static let hurtCooldown: TimeInterval = 0.8
        static let fragileLifetime: TimeInterval = 0.35
    }

    private enum Tex {
        static let stand = SKTexture(imageNamed: "player_stand")
        static let jump = SKTexture(imageNamed: "player_jump")
    }

    private let player = SKSpriteNode(texture: Tex.stand, size: T.playerSize)
    private let ceiling = SKSpriteNode(texture: SKTexture(imageNamed: "tile_spikes"), size: .zero)
    private let depthLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private var platforms: [PlatformNode] = []
    private var currentPlatform: PlatformNode?
    private var velocityY: CGFloat = 0
    private var moveDirection: CGFloat = 0
    private var steering: RelativeSteering?
    private var hp = ShaftRules.maxHP
    private var depth = 0
    private var spawnedCount = 0
    private var generator = ShaftRules.PlatformGenerator(seed: UInt64.random(in: 1...UInt64.max))
    private var lastUpdate: TimeInterval = 0
    private var lastHurt: TimeInterval = -1
    private var gameEnded = false

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(white: 0.09, alpha: 1)
        setUp()
    }

    override func restart() {
        removeAllChildren()
        platforms = []
        currentPlatform = nil
        velocityY = 0
        moveDirection = 0
        steering = nil
        hp = ShaftRules.maxHP
        depth = 0
        spawnedCount = 0
        generator = ShaftRules.PlatformGenerator(seed: UInt64.random(in: 1...UInt64.max))
        lastUpdate = 0
        lastHurt = -1
        gameEnded = false
        hintShown = true // returning player, no need to re-show
        isPaused = false
        setUp()
    }

    private func setUp() {
        addBackdrop("bg_shaft.jpg")
        ceiling.size = CGSize(width: size.width, height: T.ceilingHeight)
        ceiling.position = CGPoint(x: size.width / 2, y: size.height - T.ceilingHeight / 2)
        ceiling.zRotation = .pi // spikes point downward
        addChild(ceiling)

        depthLabel.fontSize = 20
        depthLabel.horizontalAlignmentMode = .left
        depthLabel.position = CGPoint(x: 16, y: size.height - T.ceilingHeight + 20)
        depthLabel.zPosition = 10
        addChild(depthLabel)

        hpLabel.fontSize = 20
        hpLabel.horizontalAlignmentMode = .right
        hpLabel.position = CGPoint(x: size.width - 16, y: size.height - T.ceilingHeight + 20)
        hpLabel.zPosition = 10
        addChild(hpLabel)

        // Opening layout: player standing on a safe platform, more below.
        let firstY = size.height * 0.62
        let first = makePlatform(kind: .normal, xRatio: 0.5, y: firstY)
        var y = firstY - T.verticalGap
        while y > -T.platformSize.height {
            let next = generator.next(depth: spawnedCount)
            _ = makePlatform(kind: next.kind, xRatio: next.xRatio, y: y)
            y -= T.verticalGap
        }
        player.position = CGPoint(x: first.position.x, y: first.position.y + platformTopOffset)
        addChild(player)
        currentPlatform = first
        updateHUD()
    }

    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false

    private var platformTopOffset: CGFloat {
        T.platformSize.height / 2 + T.playerSize.height / 2
    }

    private func showHint(_ text: String) {
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = text
        hint.fontSize = 16
        hint.fontColor = .lightGray
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.78)
        hint.zPosition = 10
        addChild(hint)
        hint.run(.sequence([.wait(forDuration: 2.5), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    @discardableResult
    private func makePlatform(kind: PlatformKind, xRatio: Double, y: CGFloat) -> PlatformNode {
        let belt: CGFloat = kind == .conveyor ? (Bool.random() ? 1 : -1) : 0
        let node = PlatformNode(kind: kind, index: spawnedCount, size: T.platformSize, beltDirection: belt)
        node.position = CGPoint(x: size.width * xRatio, y: y)
        addChild(node)
        platforms.append(node)
        spawnedCount += 1
        return node
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameEnded else { return }
        if isHeld {
            lastUpdate = currentTime
            return
        }
        if !hintShown {
            hintShown = true
            showHint(String(localized: "hint.shaft"))
        }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }

        scrollPlatforms(dt: dt, now: currentTime)
        movePlayer(dt: dt)
        resolveVertical(dt: dt, now: currentTime)
        checkBounds(now: currentTime)
        updateAppearance()
        updateHUD()
    }

    private func updateAppearance() {
        player.texture = currentPlatform == nil ? Tex.jump : Tex.stand
        if moveDirection != 0 {
            player.xScale = moveDirection < 0 ? -1 : 1
        }
    }

    private func scrollPlatforms(dt: TimeInterval, now: TimeInterval) {
        let speed = T.baseScrollSpeed * ShaftRules.scrollMultiplier(depth: depth)
        for platform in platforms {
            platform.position.y += speed * dt
        }
        // Spawn below once the lowest platform has risen a full gap.
        if let lowest = platforms.map(\.position.y).min(), lowest > -T.platformSize.height + T.verticalGap {
            let next = generator.next(depth: spawnedCount)
            _ = makePlatform(kind: next.kind, xRatio: next.xRatio, y: lowest - T.verticalGap)
        }
        // Drop platforms that scrolled into the ceiling.
        for platform in platforms where platform.position.y > size.height - T.ceilingHeight + 10 {
            if currentPlatform === platform { currentPlatform = nil }
            platform.removeFromParent()
        }
        platforms.removeAll { $0.parent == nil }
    }

    private func movePlayer(dt: TimeInterval) {
        var dx = moveDirection * T.moveSpeed * dt
        if let platform = currentPlatform, platform.kind == .conveyor {
            dx += platform.beltDirection * T.beltSpeed * dt
        }
        player.position.x = min(max(player.position.x + dx, T.playerSize.width / 2),
                                size.width - T.playerSize.width / 2)
    }

    private func resolveVertical(dt: TimeInterval, now: TimeInterval) {
        if let platform = currentPlatform {
            // Riding: follow the platform up; step off the edge and fall.
            // A crumbled platform removes itself, and riding a parentless node
            // pins the player to a stale position forever — gravity never runs
            // and the run soft-locks.
            let halfSpan = (T.platformSize.width + T.playerSize.width) / 2
            if platform.parent == nil || abs(player.position.x - platform.position.x) > halfSpan {
                currentPlatform = nil
                velocityY = 0
            } else {
                player.position.y = platform.position.y + platformTopOffset
                return
            }
        }
        let previousBottom = player.position.y - T.playerSize.height / 2
        velocityY = max(velocityY + T.gravity * dt, T.maxFallSpeed)
        player.position.y += velocityY * dt
        let newBottom = player.position.y - T.playerSize.height / 2

        guard velocityY < 0 else { return }
        for platform in platforms {
            let top = platform.position.y + T.platformSize.height / 2
            let halfSpan = (T.platformSize.width + T.playerSize.width) / 2
            guard previousBottom >= top, newBottom <= top,
                  abs(player.position.x - platform.position.x) < halfSpan else { continue }
            land(on: platform, now: now)
            break
        }
    }

    private func land(on platform: PlatformNode, now: TimeInterval) {
        player.position.y = platform.position.y + platformTopOffset
        velocityY = 0
        hp = ShaftRules.hpAfterLanding(hp, on: platform.kind)

        if platform.index > depth {
            depth = platform.index
        }

        switch platform.kind {
        case .spring:
            velocityY = T.springVelocity
            Haptics.impact(.light)
            AudioManager.shared.play("sfx_spring")
            return
        case .spike:
            Haptics.impact(.heavy)
            AudioManager.shared.play("sfx_hurt")
            if hp <= 0 {
                endGame()
                return
            }
        case .fragile:
            platform.run(.sequence([
                .wait(forDuration: T.fragileLifetime),
                .fadeOut(withDuration: 0.1),
                .removeFromParent()
            ]))
            Haptics.impact(.soft)
        case .normal, .conveyor:
            Haptics.impact(.soft)
        }
        currentPlatform = platform
    }

    private func checkBounds(now: TimeInterval) {
        // Ceiling spikes: damage with cooldown, then shove downward.
        let playerTop = player.position.y + T.playerSize.height / 2
        if playerTop >= size.height - T.ceilingHeight, now - lastHurt > T.hurtCooldown {
            lastHurt = now
            hp = max(0, hp - ShaftRules.ceilingDamage)
            Haptics.impact(.heavy)
            AudioManager.shared.play("sfx_hurt")
            currentPlatform = nil
            velocityY = -350
            if hp <= 0 {
                endGame()
                return
            }
        }
        if playerTop < 0 {
            endGame()
        }
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        Haptics.notify(.error)
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(depth)
    }

    private func updateHUD() {
        depthLabel.text = "\(depth) F"
        hpLabel.text = String(repeating: "♥", count: max(0, hp))
        hpLabel.fontColor = hp <= 3 ? .systemRed : .white
    }

    // MARK: - Touch: where the finger lands is the origin; slide to steer.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard steering == nil, let touch = touches.first else { return }
        steering = RelativeSteering(anchorX: touch.location(in: self).x,
                                    isDigital: SettingsStore().usesDigitalControl)
        moveDirection = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard var current = steering, let touch = touches.first else { return }
        moveDirection = current.update(touchX: touch.location(in: self).x)
        steering = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseTouch()
    }

    private func releaseTouch() {
        steering = nil
        moveDirection = 0
    }
}
