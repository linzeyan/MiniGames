import SpriteKit

/// "Bug Swarm" — bugs close in from every side of a summer-night field.
/// Slide anywhere to walk; the weapons fire on their own. Candy from squashed
/// bugs levels the kid up, and each level picks one of three upgrades.
/// Score is bugs squashed.
final class SwarmScene: MiniGameScene {
    private enum T {
        static let playerSize = CGSize(width: 30, height: 40)
        /// Kid-to-bug-center distances.
        static let contact: CGFloat = 22
        static let magnet: CGFloat = 70
        static let pickUp: CGFloat = 16
        static let candyPull: CGFloat = 420
        /// Bug-center distances for a marble or top to connect.
        static let marbleHit: CGFloat = 16
        static let topHit: CGFloat = 22
        /// How far around the kid each bug aims, so the swarm surrounds.
        static let spread: CGFloat = 36
        /// Keeps the kid below the HUD.
        static let hudHeight: CGFloat = 110
    }

    private let player = SKSpriteNode(texture: SwarmStyle.player, size: T.playerSize)
    private let stickBase = SwarmStyle.stickBase()
    private let stickKnob = SwarmStyle.stickKnob()
    private lazy var hud = SwarmHUD(width: size.width, top: size.height - 62)

    private var bugs: [SwarmBugNode] = []
    private var candies: [CandyNode] = []
    private var marbles: [FlyingMarble] = []
    private var tops: [SKSpriteNode] = []
    /// Weapons the kid has, by level; the run starts with marbles.
    private var levels: [SwarmRules.Weapon: Int] = [.marbles: 1]
    private var sneakers = 0
    private var hp = SwarmRules.playerMaxHP
    private var level = 1
    private var xp = 0
    /// Non-empty while a level-up waits for a pick; gameplay is frozen.
    private var offers: [OfferCard] = []
    private var offerLayer: SKNode?
    private var squashed = 0

    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var nextSpawn: TimeInterval = 1
    private var nextVolley: TimeInterval = 0
    private var nextZap: TimeInterval = 0
    private var immuneUntil: TimeInterval = 0
    private var topAngle: CGFloat = 0
    private var gameEnded = false
    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false
    private var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))

    private var stickTouch: UITouch?
    private var stick: SwarmRules.Stick?
    private var move = CGVector.zero

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.12, green: 0.22, blue: 0.2, alpha: 1)
        setUp()
    }

    override func restart() {
        removeAllChildren()
        bugs = []
        candies = []
        marbles = []
        tops = []
        levels = [.marbles: 1]
        sneakers = 0
        hp = SwarmRules.playerMaxHP
        level = 1
        xp = 0
        offers = []
        offerLayer = nil
        squashed = 0
        elapsed = 0
        lastUpdate = 0
        nextSpawn = 1
        nextVolley = 0
        nextZap = 0
        immuneUntil = 0
        gameEnded = false
        hintShown = true // returning player, no need to re-show
        stickTouch = nil
        stick = nil
        move = .zero
        isPaused = false
        setUp()
    }

    private func setUp() {
        addBackdrop("bg_swarm.jpg")
        player.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        player.removeAllActions() // a hit blink left over from the last run
        player.alpha = 1
        player.zPosition = 5
        addChild(player)
        addChild(stickBase)
        addChild(stickKnob)
        addChild(hud)
        updateHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameEnded else { return }
        if isHeld || !offers.isEmpty {
            lastUpdate = currentTime
            return
        }
        if !hintShown {
            hintShown = true
            addChild(SwarmStyle.banner(String(localized: "hint.swarm"),
                                       at: CGPoint(x: size.width / 2, y: size.height * 0.3), duration: 3))
        }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }
        elapsed += dt

        movePlayer(dt: dt)
        spawnBugs()
        moveBugs(dt: dt)
        fireMarbles()
        moveMarbles(dt: dt)
        spinTops(dt: dt)
        zap()
        collectCandy(dt: dt)
        updateHUD()
    }

    private func movePlayer(dt: TimeInterval) {
        let speed = SwarmRules.speed(sneakers: sneakers) * dt
        player.position.x = min(max(player.position.x + move.dx * speed, 16), size.width - 16)
        player.position.y = min(max(player.position.y + move.dy * speed, 24), size.height - T.hudHeight)
        if abs(move.dx) > 0.1 {
            player.xScale = move.dx < 0 ? -1 : 1
        }
    }

    // MARK: - Bugs

    private func spawnBugs() {
        guard elapsed >= nextSpawn, bugs.count < SwarmRules.maxBugs else { return }
        nextSpawn = elapsed + SwarmRules.spawnInterval(elapsed: elapsed)
        let kind = SwarmRules.bug(roll: rng.unit(), elapsed: elapsed)
        let bug = SwarmStyle.makeBug(kind)
        bug.hp = kind.hp * SwarmRules.hpScale(elapsed: elapsed)
        bug.aim = CGVector(dx: (rng.unit() * 2 - 1) * T.spread, dy: (rng.unit() * 2 - 1) * T.spread)
        bug.position = SwarmRules.edgePoint(roll: rng.unit(), size: size, margin: 30)
        addChild(bug)
        bugs.append(bug)
    }

    private func moveBugs(dt: TimeInterval) {
        for bug in bugs where bug.hp > 0 {
            let away = bug.position.distance(to: player.position)
            if away < T.contact {
                hurtPlayer()
            }
            // Aim off to the side from afar, straight in up close, or the
            // ring would never touch the kid.
            let pull = min(1, away / 150)
            let dx = player.position.x + bug.aim.dx * pull - bug.position.x
            let dy = player.position.y + bug.aim.dy * pull - bug.position.y
            let distance = max(1, (dx * dx + dy * dy).squareRoot())
            let step = min(distance, bug.kind.speed * dt)
            bug.position.x += dx / distance * step
            bug.position.y += dy / distance * step
            bug.xScale = dx < 0 ? -1 : 1
        }
        bugs.removeAll { $0.hp <= 0 }
    }

    private func hurtPlayer() {
        guard elapsed >= immuneUntil else { return }
        immuneUntil = elapsed + SwarmRules.hitGrace
        hp -= 1
        Haptics.impact(.heavy)
        AudioManager.shared.play("sfx_hurt")
        player.run(.repeat(.sequence([.fadeAlpha(to: 0.3, duration: 0.1), .fadeAlpha(to: 1, duration: 0.1)]),
                           count: 5))
        if hp <= 0 {
            endGame()
        }
    }

    private func hurt(_ bug: SwarmBugNode, by damage: Double) {
        bug.hp -= damage
        guard bug.hp <= 0 else {
            bug.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.04),
                               .colorize(withColorBlendFactor: 0, duration: 0.12)]))
            return
        }
        squashed += 1
        AudioManager.shared.play("sfx_catch")
        let candy = SwarmStyle.makeCandy(xp: bug.kind.xp, at: bug.position)
        addChild(candy)
        candies.append(candy)
        bug.run(.sequence([.group([.scaleY(to: 0.2, duration: 0.15), .fadeOut(withDuration: 0.25)]),
                           .removeFromParent()]))
    }

    // MARK: - Experience

    private func collectCandy(dt: TimeInterval) {
        for candy in candies {
            let away = candy.position.distance(to: player.position)
            if away < T.pickUp {
                candy.removeFromParent()
                gainXP(candy.xp)
            } else if away < T.magnet {
                let step = min(away, T.candyPull * dt)
                candy.position.x += (player.position.x - candy.position.x) / away * step
                candy.position.y += (player.position.y - candy.position.y) / away * step
            }
        }
        candies.removeAll { $0.parent == nil }
    }

    private func gainXP(_ amount: Int) {
        xp += amount
        guard offers.isEmpty, xp >= SwarmRules.xpToNext(level: level) else { return }
        xp -= SwarmRules.xpToNext(level: level)
        level += 1
        showOffers()
    }

    /// Freezes play under a dimmed field with three upgrade cards.
    private func showOffers() {
        Haptics.notify(.success)
        AudioManager.shared.play("sfx_frenzy")
        let upgrades = SwarmRules.offers(levels: levels, sneakers: sneakers, using: &rng)
        let (layer, cards) = SwarmStyle.offerLayer(upgrades, levels: levels, size: size)
        addChild(layer)
        offerLayer = layer
        offers = cards
        stickTouch = nil
        stick = nil
        move = .zero
        showStick(nil)
    }

    private func pick(_ upgrade: SwarmRules.Upgrade) {
        switch upgrade {
        case let .weapon(weapon):
            levels[weapon, default: 0] += 1
            if weapon == .tops {
                let top = SwarmStyle.makeTop()
                addChild(top)
                tops.append(top)
            }
        case .sneakers:
            sneakers += 1
        case .bun:
            hp = min(SwarmRules.playerMaxHP, hp + 1)
        }
        offerLayer?.removeFromParent()
        offerLayer = nil
        offers = []
        Haptics.impact(.medium)
        gainXP(0) // candy banked past the threshold chains straight into the next pick
    }

    // MARK: - HUD and input

    private func updateHUD() {
        hud.show(hp: hp, level: level, seconds: Int(elapsed), squashed: squashed,
                 progress: CGFloat(xp) / CGFloat(SwarmRules.xpToNext(level: level)))
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        showStick(nil)
        Haptics.notify(.error)
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(squashed)
    }

    private func showStick(_ touch: CGPoint?) {
        stickBase.alpha = touch == nil ? 0 : 1
        stickKnob.alpha = stickBase.alpha
        if let touch, let stick {
            stickBase.position = stick.anchor
            stickKnob.position = touch
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gameEnded, let touch = touches.first else { return }
        let point = touch.location(in: self)
        if !offers.isEmpty {
            if let card = offers.first(where: { $0.contains(point) }) {
                pick(card.upgrade)
            }
            return
        }
        guard stickTouch == nil, !isUnderPauseButton(point) else { return }
        stickTouch = touch
        stick = SwarmRules.Stick(anchor: point, isDigital: SettingsStore().usesDigitalControl)
        showStick(point)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stickTouch, touches.contains(stickTouch), var current = stick else { return }
        let point = stickTouch.location(in: self)
        move = current.update(touch: point)
        stick = current
        showStick(point)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let stickTouch, touches.contains(stickTouch) else { return }
        self.stickTouch = nil
        stick = nil
        move = .zero
        showStick(nil)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
}

extension SwarmScene {
    // MARK: - Weapons

    private func fireMarbles() {
        guard let marbleLevel = levels[.marbles], elapsed >= nextVolley else { return }
        let screen = CGRect(origin: .zero, size: size)
        let targets = bugs.filter { $0.hp > 0 && screen.contains($0.position) }
            .sorted { $0.position.distance(to: player.position) < $1.position.distance(to: player.position) }
            .prefix(SwarmRules.marbleCount(level: marbleLevel))
        guard !targets.isEmpty else { return }
        nextVolley = elapsed + SwarmRules.marbleInterval(level: marbleLevel)
        AudioManager.shared.play("sfx_throw")
        for target in targets {
            let dx = target.position.x - player.position.x
            let dy = target.position.y - player.position.y
            let distance = max(1, (dx * dx + dy * dy).squareRoot())
            let marble = SwarmStyle.makeMarble(at: player.position,
                                               velocity: CGVector(dx: dx / distance * SwarmRules.marbleSpeed,
                                                                  dy: dy / distance * SwarmRules.marbleSpeed))
            addChild(marble)
            marbles.append(marble)
        }
    }

    private func moveMarbles(dt: TimeInterval) {
        let screen = CGRect(origin: .zero, size: size).insetBy(dx: -20, dy: -20)
        for marble in marbles {
            marble.position.x += marble.velocity.dx * dt
            marble.position.y += marble.velocity.dy * dt
            if let bug = bugs.first(where: { $0.hp > 0 && $0.position.distance(to: marble.position) < T.marbleHit }) {
                marble.removeFromParent()
                hurt(bug, by: SwarmRules.marbleDamage)
            } else if !screen.contains(marble.position) {
                marble.removeFromParent()
            }
        }
        marbles.removeAll { $0.parent == nil }
    }

    private func spinTops(dt: TimeInterval) {
        guard !tops.isEmpty else { return }
        topAngle += SwarmRules.topSpin * dt
        for (index, top) in tops.enumerated() {
            let angle = topAngle + CGFloat(index) * 2 * .pi / CGFloat(tops.count)
            top.position = CGPoint(x: player.position.x + cos(angle) * SwarmRules.topOrbit,
                                   y: player.position.y + sin(angle) * SwarmRules.topOrbit)
            top.zRotation -= 12 * dt
            for bug in bugs where bug.hp > 0 && elapsed >= bug.topImmuneUntil
                && bug.position.distance(to: top.position) < T.topHit {
                bug.topImmuneUntil = elapsed + SwarmRules.topHitGap
                hurt(bug, by: SwarmRules.topDamage)
            }
        }
    }

    private func zap() {
        guard let swatter = levels[.swatter], elapsed >= nextZap else { return }
        nextZap = elapsed + SwarmRules.swatterInterval(level: swatter)
        let reach = SwarmRules.swatterReach(level: swatter)
        addChild(SwarmStyle.zap(at: player.position, radius: reach))
        AudioManager.shared.play("sfx_spring")
        for bug in bugs where bug.hp > 0 && bug.position.distance(to: player.position) < reach {
            hurt(bug, by: SwarmRules.swatterDamage)
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
