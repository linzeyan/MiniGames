import SpriteKit

/// "Up We Go" — charge jumps to climb an endless tower. Hold to charge and
/// steer toward your finger; release to jump. Falling off the bottom ends
/// the run.
final class TowerScene: MiniGameScene {
    private enum T {
        static let platformSize = CGSize(width: 92, height: 16)
        static let playerSize = CGSize(width: 26, height: 34)
        static let maxFallSpeed: CGFloat = -1000
        static let cameraLine: CGFloat = 0.62
        static let fragileLifetime: TimeInterval = 0.4
        static let movingSpeed: CGFloat = 70
        static let graceBeforeScroll: TimeInterval = 3.0
    }

    private final class TowerPlatform: SKSpriteNode {
        let kind: PlatformKind
        let index: Int
        var vx: CGFloat = 0

        init(kind: PlatformKind, index: Int, size: CGSize) {
            self.kind = kind
            self.index = index
            let imageName = switch kind {
            case .fragile: "platform_snow"
            case .conveyor: "platform_planet" // moving platform
            default: "platform_grass"
            }
            super.init(texture: SKTexture(imageNamed: imageName), color: .white, size: size)
            if kind == .conveyor {
                vx = Bool.random() ? T.movingSpeed : -T.movingSpeed
            }
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    }

    private enum Tex {
        static let stand = SKTexture(imageNamed: "player_stand")
        static let jump = SKTexture(imageNamed: "player_jump")
        static let duck = SKTexture(imageNamed: "player_duck")
    }

    private let player = SKSpriteNode(texture: Tex.stand, size: T.playerSize)
    private let chargeBar = SKSpriteNode(color: .systemOrange, size: CGSize(width: 0, height: 5))
    private let floorLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    private var platforms: [TowerPlatform] = []
    private var currentPlatform: TowerPlatform?
    private var velocityY: CGFloat = 0
    private var floor = 0
    private var spawnedCount = 0
    private var highestY: CGFloat = 0
    private var lastX: CGFloat = 0
    private var generator = TowerRules.PlatformGenerator(seed: UInt64.random(in: 1...UInt64.max))
    private var lastUpdate: TimeInterval = 0
    private var startTime: TimeInterval = 0
    private var gameEnded = false

    private var touchActive = false
    private var chargeStart: TimeInterval = 0
    private var moveDirection: CGFloat = 0
    private var steering: RelativeSteering?

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.07, green: 0.1, blue: 0.18, alpha: 1)
        setUp()
    }

    override func restart() {
        removeAllChildren()
        platforms = []
        currentPlatform = nil
        velocityY = 0
        floor = 0
        spawnedCount = 0
        highestY = 0
        generator = TowerRules.PlatformGenerator(seed: UInt64.random(in: 1...UInt64.max))
        lastUpdate = 0
        startTime = 0
        gameEnded = false
        hintShown = true // returning player, no need to re-show
        touchActive = false
        moveDirection = 0
        steering = nil
        isPaused = false
        setUp()
    }

    private func setUp() {
        addBackdrop("bg_tower.jpg")
        floorLabel.fontSize = 20
        floorLabel.horizontalAlignmentMode = .left
        floorLabel.position = CGPoint(x: 16, y: size.height - 60)
        floorLabel.zPosition = 10
        addChild(floorLabel)

        // Wide safe ground, then generated floors upward.
        let ground = TowerPlatform(kind: .normal, index: 0, size: CGSize(width: size.width * 0.9, height: 16))
        ground.position = CGPoint(x: size.width / 2, y: 60)
        addChild(ground)
        platforms.append(ground)
        spawnedCount = 1
        highestY = ground.position.y
        lastX = ground.position.x
        fillPlatforms()

        player.position = CGPoint(x: ground.position.x, y: ground.position.y + standOffset)
        addChild(player)
        currentPlatform = ground

        chargeBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        chargeBar.isHidden = true
        chargeBar.zPosition = 5
        addChild(chargeBar)
        updateHUD()
    }

    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false

    private var standOffset: CGFloat {
        T.platformSize.height / 2 + T.playerSize.height / 2
    }

    private func showHint(_ text: String) {
        let hint = SKLabelNode(fontNamed: "Menlo")
        hint.text = text
        hint.fontSize = 15
        hint.fontColor = .lightGray
        hint.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        hint.zPosition = 10
        addChild(hint)
        hint.run(.sequence([.wait(forDuration: 3.0), .fadeOut(withDuration: 0.5), .removeFromParent()]))
    }

    private func fillPlatforms() {
        while highestY < size.height + 60 {
            let next = generator.next(floor: spawnedCount, previousX: lastX,
                                      width: size.width, platformWidth: T.platformSize.width)
            let node = TowerPlatform(kind: next.kind, index: spawnedCount, size: T.platformSize)
            node.position = CGPoint(x: next.x, y: highestY + next.dy)
            addChild(node)
            platforms.append(node)
            spawnedCount += 1
            highestY = node.position.y
            lastX = node.position.x
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameEnded else { return }
        if isHeld {
            lastUpdate = currentTime
            startTime = 0 // grace period restarts once the overlay closes
            return
        }
        if !hintShown {
            hintShown = true
            showHint(String(localized: "hint.tower"))
        }
        if startTime == 0 { startTime = currentTime }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }

        movePlatforms(dt: dt)
        autoScroll(dt: dt, now: currentTime)
        steerPlayer(dt: dt)
        resolveVertical(dt: dt)
        followCamera()
        fillPlatforms()
        pruneBelowScreen()
        updateChargeBar(now: currentTime)
        updateAppearance()
        updateHUD()

        if player.position.y + T.playerSize.height / 2 < 0 {
            endGame()
        }
    }

    private func movePlatforms(dt: TimeInterval) {
        let margin = T.platformSize.width / 2 + 4
        for platform in platforms where platform.vx != 0 {
            platform.position.x += platform.vx * dt
            if platform.position.x < margin || platform.position.x > size.width - margin {
                platform.vx = -platform.vx
                platform.position.x = min(max(platform.position.x, margin), size.width - margin)
            }
            if currentPlatform === platform {
                player.position.x += platform.vx * dt
            }
        }
    }

    private func autoScroll(dt: TimeInterval, now: TimeInterval) {
        guard now - startTime > T.graceBeforeScroll else { return }
        let drop = CGFloat(TowerRules.autoScrollSpeed(floor: floor)) * dt
        shiftWorld(by: -drop, movePlayer: currentPlatform != nil)
    }

    private func shiftWorld(by dy: CGFloat, movePlayer: Bool) {
        for platform in platforms {
            platform.position.y += dy
        }
        highestY += dy
        if movePlayer {
            player.position.y += dy
        }
    }

    private func steerPlayer(dt: TimeInterval) {
        guard moveDirection != 0 else { return }
        player.position.x += moveDirection * CGFloat(TowerRules.moveSpeed) * dt
        player.position.x = min(max(player.position.x, T.playerSize.width / 2),
                                size.width - T.playerSize.width / 2)
    }

    private func resolveVertical(dt: TimeInterval) {
        if let platform = currentPlatform {
            let halfSpan = (platform.size.width + T.playerSize.width) / 2
            if platform.parent == nil || abs(player.position.x - platform.position.x) > halfSpan {
                currentPlatform = nil
                velocityY = 0
            } else {
                player.position.y = platform.position.y + standOffset
                return
            }
        }
        let previousBottom = player.position.y - T.playerSize.height / 2
        velocityY = max(velocityY - CGFloat(TowerRules.gravity) * dt, T.maxFallSpeed)
        player.position.y += velocityY * dt
        let newBottom = player.position.y - T.playerSize.height / 2

        guard velocityY < 0 else { return }
        for platform in platforms {
            let top = platform.position.y + platform.size.height / 2
            let halfSpan = (platform.size.width + T.playerSize.width) / 2
            guard previousBottom >= top, newBottom <= top,
                  abs(player.position.x - platform.position.x) < halfSpan else { continue }
            land(on: platform)
            break
        }
    }

    private func land(on platform: TowerPlatform) {
        player.position.y = platform.position.y + standOffset
        velocityY = 0
        currentPlatform = platform
        Haptics.impact(.soft)
        AudioManager.shared.play("sfx_land")
        if platform.index > floor {
            floor = platform.index
        }
        if platform.kind == .fragile {
            platform.run(.sequence([
                .wait(forDuration: T.fragileLifetime),
                .fadeOut(withDuration: 0.1),
                .removeFromParent()
            ]))
        }
    }

    private func followCamera() {
        let line = size.height * T.cameraLine
        if player.position.y > line {
            shiftWorld(by: line - player.position.y, movePlayer: false)
            player.position.y = line
        }
    }

    private func pruneBelowScreen() {
        for platform in platforms where platform.position.y < -30 {
            if currentPlatform === platform { currentPlatform = nil }
            platform.removeFromParent()
        }
        platforms.removeAll { $0.parent == nil }
    }

    private func updateAppearance() {
        if currentPlatform == nil {
            player.texture = Tex.jump
        } else {
            player.texture = touchActive ? Tex.duck : Tex.stand
        }
        if moveDirection != 0 {
            player.xScale = moveDirection < 0 ? -1 : 1
        }
    }

    private func updateChargeBar(now: TimeInterval) {
        guard touchActive, currentPlatform != nil else {
            chargeBar.isHidden = true
            return
        }
        let charge = min(1, (now - chargeStart) / TowerRules.fullChargeDuration)
        chargeBar.isHidden = false
        chargeBar.size.width = 40 * CGFloat(charge)
        chargeBar.position = CGPoint(x: player.position.x - 20,
                                     y: player.position.y + T.playerSize.height / 2 + 10)
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        Haptics.notify(.error)
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(floor)
    }

    private func updateHUD() {
        floorLabel.text = "\(floor) F"
    }

    // MARK: - Touch: hold to charge, slide from the touch-down point to
    // steer, release to jump.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !touchActive, let touch = touches.first else { return }
        touchActive = true
        chargeStart = lastUpdate
        steering = RelativeSteering(anchorX: touch.location(in: self).x,
                                    isDigital: SettingsStore().usesDigitalControl)
        moveDirection = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touchActive, var current = steering, let touch = touches.first else { return }
        moveDirection = current.update(touchX: touch.location(in: self).x)
        steering = current
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finishTouch()
    }

    private func finishTouch() {
        defer {
            touchActive = false
            moveDirection = 0
            steering = nil
            chargeBar.isHidden = true
        }
        guard touchActive, currentPlatform != nil, !gameEnded else { return }
        let hold = lastUpdate - chargeStart
        velocityY = CGFloat(TowerRules.jumpVelocity(holdDuration: hold))
        currentPlatform = nil
        Haptics.impact(.light)
        AudioManager.shared.play("sfx_jump")
    }
}
