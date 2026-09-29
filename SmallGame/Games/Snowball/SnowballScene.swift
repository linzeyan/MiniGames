import SpriteKit

/// "Snowball Fight" — drag to aim (slingshot), release to throw; tap the
/// ground to walk there. Clear every enemy to advance a level; score is
/// total enemies defeated.
final class SnowballScene: MiniGameScene {
    private enum T {
        static let playerSize = CGSize(width: 30, height: 40)
        static let enemySize = CGSize(width: 30, height: 40)
        static let ballRadius: CGFloat = 7
        static let hitRadius: CGFloat = 26
        static let throwCooldown: TimeInterval = 0.35
        static let enemyFlightTime = 1.15
        static let walkSpeed: CGFloat = 300
        static let aimDotCount = 9
        static let levelBannerDuration: TimeInterval = 1.2
    }

    private final class Enemy: SKSpriteNode {
        var nextThrow: TimeInterval = 0
        /// 0 for the ones that hold their ground; patrollers bounce between
        /// the screen edges, so the player has to lead the shot.
        var velocityX: CGFloat = 0
    }

    private final class Ball: SKShapeNode {
        var velocity = CGVector.zero
        var hostile = false
    }

    private let player = SKSpriteNode(texture: SnowballStyle.player, size: T.playerSize)
    private let hpLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var aimDots: [SKShapeNode] = []

    private var enemies: [Enemy] = []
    private var balls: [Ball] = []
    private var hp = SnowballRules.playerMaxHP
    private var level = 1
    private var defeated = 0
    private var lastThrow: TimeInterval = -1
    private var lastUpdate: TimeInterval = 0
    private var gameEnded = false
    private var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))

    // Two-handed control: one finger steers, the other aims. Sharing a single
    // finger between both meant guessing intent from drag distance, which ate
    // taps meant as "walk" and turned throws into a screen-long drag.
    private var moveTouch: UITouch?
    private var steering: RelativeSteering?
    private var moveDirection: CGFloat = 0
    private var aimTouch: UITouch?
    private var aimPoint: CGPoint?

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.85, green: 0.9, blue: 0.96, alpha: 1)
        // UIView defaults to single touch; without this the second hand is
        // never delivered and two-handed control silently does nothing.
        view.isMultipleTouchEnabled = true
        setUp()
    }

    override func restart() {
        removeAllChildren()
        enemies = []
        balls = []
        aimDots = []
        hp = SnowballRules.playerMaxHP
        level = 1
        defeated = 0
        lastThrow = -1
        lastUpdate = 0
        gameEnded = false
        hintShown = true // returning player, no need to re-show
        moveTouch = nil
        steering = nil
        moveDirection = 0
        aimTouch = nil
        aimPoint = nil
        isPaused = false
        setUp()
    }

    private func setUp() {
        addBackdrop("bg_snowball.jpg")
        hpLabel.fontSize = 20
        hpLabel.fontColor = .systemRed
        hpLabel.horizontalAlignmentMode = .left
        hpLabel.position = CGPoint(x: 16, y: size.height - 60)
        hpLabel.zPosition = 10
        addChild(hpLabel)

        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .darkGray
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: size.width - 16, y: size.height - 60)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        for tile in SnowballStyle.groundTiles(width: size.width, y: 82) {
            addChild(tile)
        }

        player.position = CGPoint(x: size.width / 2, y: 110)
        addChild(player)

        aimDots = SnowballStyle.aimDots(count: T.aimDotCount)
        for dot in aimDots {
            addChild(dot)
        }

        spawnLevel()
        updateHUD()
    }

    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false

    private func spawnLevel() {
        let config = SnowballRules.LevelConfig(level: level)
        let rows: [CGFloat] = [0.82, 0.72]
        for index in 0..<config.enemyCount {
            let enemy = Enemy(texture: SnowballStyle.enemy, color: .white, size: T.enemySize)
            // Alternate facing so the squad doesn't look copy-pasted.
            enemy.xScale = index % 2 == 0 ? 1 : -1
            // Fill a row before starting the next one: deriving columns from
            // half the squad stacked the level-1 pair in a single center column.
            let columns = min(config.enemyCount, 3)
            let column = index % columns
            let row = index / columns
            let spacing = size.width / CGFloat(columns + 1)
            enemy.position = CGPoint(x: spacing * CGFloat(column + 1),
                                     y: size.height * rows[min(row, rows.count - 1)])
            enemy.nextThrow = lastUpdate + Double(index) * 0.6 + config.throwInterval
            if index < config.movingCount {
                // Alternate headings so a patrolling squad spreads out
                // instead of marching in formation.
                enemy.velocityX = CGFloat(config.moveSpeed) * (index % 2 == 0 ? 1 : -1)
                enemy.xScale = enemy.velocityX < 0 ? -1 : 1
            }
            addChild(enemy)
            enemies.append(enemy)
        }
    }

    private func showBanner(_ text: String, duration: TimeInterval = T.levelBannerDuration) {
        addChild(SnowballStyle.banner(text,
                                      at: CGPoint(x: size.width / 2, y: size.height * 0.5),
                                      duration: duration))
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameEnded else { return }
        if isHeld {
            lastUpdate = currentTime
            return
        }
        if !hintShown {
            hintShown = true
            showBanner(String(localized: "hint.snowball"), duration: 3.0)
        }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }

        movePlayer(dt: dt)
        moveEnemies(dt: dt)
        updateBalls(dt: dt)
        updateEnemies(now: currentTime)
        updateAimGuide()
        updateHUD()
    }

    private func movePlayer(dt: TimeInterval) {
        guard moveDirection != 0 else { return }
        let half = T.playerSize.width / 2
        player.position.x = min(max(player.position.x + moveDirection * T.walkSpeed * dt, half),
                                size.width - half)
    }

    private func updateBalls(dt: TimeInterval) {
        for ball in balls {
            ball.velocity.dy -= CGFloat(SnowballRules.gravity) * dt
            ball.position.x += ball.velocity.dx * dt
            ball.position.y += ball.velocity.dy * dt

            if ball.hostile {
                if ball.position.distance(to: player.position) < T.hitRadius {
                    ball.removeFromParent()
                    playerHit()
                    continue
                }
            } else {
                if let enemy = enemies.first(where: { $0.position.distance(to: ball.position) < T.hitRadius }) {
                    ball.removeFromParent()
                    defeat(enemy)
                    continue
                }
            }
            if ball.position.y < -20 || ball.position.x < -30 || ball.position.x > size.width + 30 {
                ball.removeFromParent()
            }
        }
        balls.removeAll { $0.parent == nil }
    }

    private func moveEnemies(dt: TimeInterval) {
        let margin = T.enemySize.width / 2 + 8
        for enemy in enemies where enemy.velocityX != 0 {
            enemy.position.x += enemy.velocityX * dt
            if enemy.position.x < margin || enemy.position.x > size.width - margin {
                enemy.position.x = min(max(enemy.position.x, margin), size.width - margin)
                enemy.velocityX *= -1
                enemy.xScale = enemy.velocityX < 0 ? -1 : 1
            }
        }
    }

    private func updateEnemies(now: TimeInterval) {
        let config = SnowballRules.LevelConfig(level: level)
        for enemy in enemies where now >= enemy.nextThrow {
            enemy.nextThrow = now + config.throwInterval * (0.7 + rng.unit() * 0.6)
            let errorX = (rng.unit() * 2 - 1) * config.errorRadius
            let errorY = (rng.unit() * 2 - 1) * config.errorRadius * 0.5
            let aim = SnowballRules.aimVelocity(fromX: enemy.position.x, fromY: enemy.position.y,
                                                toX: player.position.x + errorX,
                                                toY: player.position.y + errorY,
                                                flightTime: T.enemyFlightTime)
            spawnBall(at: enemy.position,
                      velocity: CGVector(dx: aim.dx, dy: aim.dy),
                      hostile: true)
        }
    }

    private func spawnBall(at position: CGPoint, velocity: CGVector, hostile: Bool) {
        let ball = Ball(circleOfRadius: T.ballRadius)
        ball.fillColor = hostile ? .systemIndigo : .white
        ball.strokeColor = .gray
        ball.position = position
        ball.velocity = velocity
        ball.hostile = hostile
        addChild(ball)
        balls.append(ball)
    }

    private func playerHit() {
        hp -= 1
        Haptics.impact(.heavy)
        AudioManager.shared.play("sfx_hurt")
        player.run(.sequence([.fadeAlpha(to: 0.3, duration: 0.08), .fadeAlpha(to: 1, duration: 0.08)]))
        if hp <= 0 {
            endGame()
        }
    }

    private func defeat(_ enemy: Enemy) {
        defeated += 1
        Haptics.impact(.medium)
        AudioManager.shared.play("sfx_catch")
        enemies.removeAll { $0 === enemy }
        enemy.texture = SnowballStyle.enemyHit
        enemy.run(.sequence([.fadeOut(withDuration: 0.25), .removeFromParent()]))
        if enemies.isEmpty {
            level += 1
            showBanner(String(localized: "snowball.level \(level)"))
            spawnLevel()
        }
    }

    private func updateAimGuide() {
        guard let aimPoint else {
            for dot in aimDots { dot.alpha = 0 }
            return
        }
        let velocity = SnowballRules.playerLaunchVelocity(fromX: player.position.x,
                                                          fromY: player.position.y,
                                                          toX: aimPoint.x, toY: aimPoint.y)
        for (index, dot) in aimDots.enumerated() {
            let t = Double(index + 1) * 0.09
            let point = SnowballRules.position(startX: player.position.x, startY: player.position.y,
                                               vx: velocity.dx, vy: velocity.dy, t: t)
            dot.position = CGPoint(x: point.x, y: point.y)
            dot.alpha = 0.6 - Double(index) * 0.05
        }
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        Haptics.notify(.error)
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(defeated)
    }

    private func updateHUD() {
        hpLabel.text = String(repeating: "♥", count: max(0, hp))
        scoreLabel.text = "LV \(level)  ✕\(defeated)"
    }

    // MARK: - Touch: left half steers from where it lands, right half aims,
    // and a tap that never steers throws — so one hand can still shoot.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            claim(touch, at: touch.location(in: self))
        }
    }

    /// Each finger takes the role of the half it landed on, or the other role
    /// if that one is busy — so a second finger is never dead, and enemies on
    /// the movement side can still be targeted.
    private func claim(_ touch: UITouch, at location: CGPoint) {
        let prefersMove = location.x < size.width / 2
        if prefersMove, moveTouch == nil { return beginMove(touch, at: location) }
        if !prefersMove, aimTouch == nil { return beginAim(touch, at: location) }
        if moveTouch == nil {
            beginMove(touch, at: location)
        } else if aimTouch == nil {
            beginAim(touch, at: location)
        }
    }

    private func beginMove(_ touch: UITouch, at location: CGPoint) {
        moveTouch = touch
        steering = RelativeSteering(anchorX: location.x,
                                    isDigital: SettingsStore().usesDigitalControl)
        moveDirection = 0
    }

    private func beginAim(_ touch: UITouch, at location: CGPoint) {
        aimTouch = touch
        aimPoint = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if touch === moveTouch, var current = steering {
                moveDirection = current.update(touchX: location.x)
                steering = current
            } else if touch === aimTouch {
                aimPoint = location
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { release(touch, throwing: true) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches { release(touch, throwing: false) }
    }

    private func release(_ touch: UITouch, throwing: Bool) {
        if touch === moveTouch {
            // A finger that never left the dead zone was not walking anywhere,
            // so read it as a one-handed throw: standing still and tapping a
            // target should shoot rather than do nothing.
            let wasTap = steering?.hasSteered == false
            let location = touch.location(in: self)
            moveTouch = nil
            steering = nil
            moveDirection = 0
            if throwing, wasTap { throwBall(at: location) }
        } else if touch === aimTouch {
            if throwing, let aimPoint { throwBall(at: aimPoint) }
            aimTouch = nil
            aimPoint = nil
        }
    }

    private func throwBall(at target: CGPoint) {
        guard !gameEnded, lastUpdate - lastThrow > T.throwCooldown else { return }
        lastThrow = lastUpdate
        let velocity = SnowballRules.playerLaunchVelocity(fromX: player.position.x,
                                                          fromY: player.position.y,
                                                          toX: target.x, toY: target.y)
        spawnBall(at: player.position,
                  velocity: CGVector(dx: velocity.dx, dy: velocity.dy),
                  hostile: false)
        Haptics.impact(.light)
        AudioManager.shared.play("sfx_throw")
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
