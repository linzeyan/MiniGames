import SpriteKit

/// "Gone Fishing" — tap anywhere in the water to cast the hook to that spot,
/// tap again to reel it back. Only the reel-up catches: every creature the
/// hook touches on the way up is hauled in together. Score attack with time
/// extensions for good play; deep fish pay more, junk costs points.
final class FishingScene: MiniGameScene {
    private enum T {
        static let waterLine: CGFloat = 0.72   // fraction of scene height
        static let sinkSpeed: CGFloat = 160
        static let reelSpeed: CGFloat = 220
        static let catchRadiusX: CGFloat = 26
        static let catchRadiusY: CGFloat = 22
        static let fishCount = 6
        static let fishSize = CGSize(width: 34, height: 16)
    }

    // FishNode / HookState / FishingStyle live in FishingNodes.swift.

    private let fisher = SKSpriteNode(texture: FishingStyle.fisher, size: CGSize(width: 30, height: 38))
    private let hook = SKShapeNode(circleOfRadius: 5)
    private let line = SKShapeNode()
    private let timeLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let comboLabel = SKLabelNode(fontNamed: "Menlo")

    private var fishes: [FishNode] = []
    private var hookedFish: [FishNode] = []
    private var state = HookState.idle
    private var score = 0
    private var combo = 0
    private var comboExpiry: TimeInterval = 0
    private var timeLeft = FishingRules.sessionDuration
    private var lastUpdate: TimeInterval = 0
    private var gameEnded = false
    private var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))

    private var waterTop: CGFloat { size.height * T.waterLine }
    private var rodTip: CGPoint { CGPoint(x: size.width / 2, y: waterTop + 40) }

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.55, green: 0.78, blue: 0.92, alpha: 1)
        setUp()
    }

    override func restart() {
        removeAllChildren()
        fishes = []
        hookedFish = []
        state = .idle
        hintShown = true // returning player, no need to re-show
        score = 0
        combo = 0
        comboExpiry = 0
        timeLeft = FishingRules.sessionDuration
        lastUpdate = 0
        gameEnded = false
        nextFrenzy = 0
        frenzyUntil = 0
        isPaused = false
        setUp()
    }

    private func setUp() {
        // Water body below the waterline.
        let water = SKSpriteNode(color: UIColor(red: 0.1, green: 0.3, blue: 0.55, alpha: 1),
                                 size: CGSize(width: size.width, height: waterTop))
        water.anchorPoint = CGPoint(x: 0.5, y: 1)
        water.position = CGPoint(x: size.width / 2, y: waterTop)
        water.zPosition = -1
        addChild(water)

        // Rowboat straddling the waterline; the fisher stands on its deck.
        let boat = FishingStyle.makeBoat()
        boat.position = CGPoint(x: size.width / 2, y: waterTop + 6)
        boat.zPosition = 1
        addChild(boat)

        fisher.position = CGPoint(x: size.width / 2, y: waterTop + 6 + 19)
        fisher.zPosition = 2
        addChild(fisher)

        hook.fillColor = .white
        hook.strokeColor = .lightGray
        hook.position = rodTip
        hook.zPosition = 2
        addChild(hook)

        line.strokeColor = .white
        line.lineWidth = 1
        addChild(line)

        timeLabel.fontSize = 20
        timeLabel.horizontalAlignmentMode = .left
        timeLabel.position = CGPoint(x: 16, y: size.height - 60)
        timeLabel.zPosition = 10
        addChild(timeLabel)

        // Stacked down the left edge: the top-right corner belongs to the
        // pause button, and centred text lands under the Dynamic Island.
        scoreLabel.fontSize = 22
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 16, y: size.height - 90)
        scoreLabel.zPosition = 10
        addChild(scoreLabel)

        comboLabel.fontSize = 15
        comboLabel.fontColor = .systemOrange
        comboLabel.horizontalAlignmentMode = .left
        comboLabel.position = CGPoint(x: 16, y: size.height - 116)
        comboLabel.zPosition = 10
        comboLabel.alpha = 0
        addChild(comboLabel)

        for _ in 0..<T.fishCount {
            spawnFish(anywhere: true)
        }
        updateHUD()
    }

    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false

    private func showHint(_ text: String) {
        addChild(FishingOverlay.hint(text, at: CGPoint(x: size.width / 2, y: waterTop + 90)))
    }

    private func spawnFish(anywhere: Bool = false) {
        let species = FishingRules.randomSpecies(rng: &rng)
        let fish = FishingStyle.makeNode(for: species,
                                         direction: rng.unit() < 0.5 ? 1 : -1)
        let depth = species.depthRange.lowerBound
            + rng.unit() * (species.depthRange.upperBound - species.depthRange.lowerBound)
        let y = waterTop - 30 - CGFloat(depth) * (waterTop - 60)
        let x: CGFloat = anywhere
            ? CGFloat(rng.unit()) * size.width
            : (fish.direction > 0 ? -T.fishSize.width : size.width + T.fishSize.width)
        fish.position = CGPoint(x: x, y: y)
        addChild(fish)
        fishes.append(fish)
    }

    override func update(_ currentTime: TimeInterval) {
        guard !gameEnded else { return }
        if isHeld {
            lastUpdate = currentTime
            return
        }
        if !hintShown {
            hintShown = true
            showHint(String(localized: "hint.fishing"))
        }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }

        timeLeft -= dt
        if timeLeft <= 0 {
            endGame()
            return
        }

        expireCombo(now: currentTime)
        updateFrenzy(now: currentTime)
        moveFishes(dt: dt)
        advanceHook(dt: dt)
        drawLine()
        updateHUD()
    }

    // MARK: - Frenzy: every so often a school of fish floods the water.

    private var nextFrenzy: TimeInterval = 0
    private var frenzyUntil: TimeInterval = 0

    private func updateFrenzy(now: TimeInterval) {
        if nextFrenzy == 0 {
            nextFrenzy = now + FishingRules.frenzyInterval * (0.8 + rng.unit() * 0.4)
            return
        }
        guard now >= nextFrenzy else { return }
        nextFrenzy = now + FishingRules.frenzyInterval * (0.8 + rng.unit() * 0.4)
        frenzyUntil = now + FishingRules.frenzyDuration
        for _ in 0..<FishingRules.frenzyBurstCount {
            spawnFish(anywhere: true)
        }
        Haptics.impact(.medium)
        AudioManager.shared.play("sfx_frenzy")
        showBanner(String(localized: "fishing.frenzy"))
    }

    // MARK: - Combo: a chain across hauls, shown as a brief flash.

    /// Go quiet for longer than the window and the chain starts over.
    private func expireCombo(now: TimeInterval) {
        guard combo > 0, now > comboExpiry else { return }
        combo = 0
    }

    private func showCombo() {
        guard combo > 1 else { return }
        comboLabel.text = "combo ×\(combo)"
        comboLabel.removeAllActions()
        comboLabel.alpha = 1
        comboLabel.run(.sequence([
            .wait(forDuration: FishingRules.comboDisplayDuration),
            .fadeOut(withDuration: 0.25)
        ]))
    }

    private func showBanner(_ text: String) {
        addChild(FishingOverlay.banner(text, at: CGPoint(x: size.width / 2, y: size.height * 0.5)))
    }

    private func moveFishes(dt: TimeInterval) {
        for fish in fishes {
            // Hooked fish are dragged by the line, not swimming.
            if fish.hooked { continue }
            fish.position.x += fish.direction * CGFloat(fish.species.swimSpeed) * dt
            if fish.position.x < -60 || fish.position.x > size.width + 60 {
                fish.removeFromParent()
            }
        }
        fishes.removeAll { $0.parent == nil }
        // Refill toward the target population; during a frenzy the water
        // temporarily holds far more fish, then decays back to normal.
        let target = lastUpdate < frenzyUntil
            ? T.fishCount + FishingRules.frenzyBurstCount
            : T.fishCount
        for _ in 0..<max(0, target - fishes.count) {
            spawnFish()
        }
    }

    private func advanceHook(dt: TimeInterval) {
        switch state {
        case .idle:
            hook.position = rodTip
        case .casting(let target):
            // Dropping the line never catches — fish only hook while the
            // hook rests in place or on the reel back up.
            moveHook(toward: target, speed: T.sinkSpeed, dt: dt)
            if hook.position.distance(to: target) < 3 {
                state = .waiting
            }
        case .waiting:
            break // the resting hook never catches — only the reel-up does
        case .reeling:
            moveHook(toward: rodTip, speed: T.reelSpeed, dt: dt)
            checkContact()
            if hook.position.distance(to: rodTip) < 3 {
                resolveCatch()
            }
        }
        // The whole string of hooked fish trails below the hook.
        for (index, fish) in hookedFish.enumerated() {
            fish.position = CGPoint(x: hook.position.x,
                                    y: hook.position.y - 12 - CGFloat(index) * 16)
        }
    }

    private func moveHook(toward target: CGPoint, speed: CGFloat, dt: TimeInterval) {
        let dx = target.x - hook.position.x
        let dy = target.y - hook.position.y
        let length = max(0.001, (dx * dx + dy * dy).squareRoot())
        let step = min(speed * dt, length)
        hook.position.x += dx / length * step
        hook.position.y += dy / length * step
    }

    /// Anything within reach of the hook gets caught — but only during the
    /// reel-up. Everything touched accumulates on the line.
    private func checkContact() {
        for fish in fishes where !fish.hooked && fish.position.y < waterTop {
            guard abs(fish.position.x - hook.position.x) < T.catchRadiusX,
                  abs(fish.position.y - hook.position.y) < T.catchRadiusY else { continue }
            fish.hooked = true
            hookedFish.append(fish)
            if fish.species.isJunk {
                Haptics.impact(.rigid)
                AudioManager.shared.play("sfx_land")
            } else {
                Haptics.impact(.medium) // the bite cue — the game's key moment
                AudioManager.shared.play("sfx_jump")
                showFloat(String(localized: "fishing.bite"), color: .systemOrange)
            }
        }
    }

    /// The hook is back at the surface — settle every fish on the line.
    private func resolveCatch() {
        state = .idle
        hook.position = rodTip
        let haul = hookedFish
        hookedFish = []
        guard !haul.isEmpty else { return }

        var netPoints = 0
        for fish in haul {
            if fish.species.isJunk {
                netPoints += fish.species.points
                combo = 0
                removeFish(fish)
            } else {
                netPoints += fish.species.points + combo * FishingRules.comboBonus
                combo += 1
                comboExpiry = lastUpdate + FishingRules.comboWindow
                removeFish(fish, caught: true)
            }
        }
        showCombo()
        let previousScore = score
        score = max(0, score + netPoints)
        if netPoints > 0 {
            Haptics.notify(.success)
            AudioManager.shared.play("sfx_catch")
            showFloat(String(localized: "fishing.caught \(netPoints)"), color: .systemGreen)
        } else {
            showFloat(String(localized: "fishing.junk \(netPoints)"), color: .systemRed)
        }
        let bonus = FishingRules.timeBonus(from: previousScore, to: score)
        if bonus > 0 {
            timeLeft += bonus
            showBanner(String(localized: "fishing.time_bonus \(Int(bonus))"))
        }
    }

    private func removeFish(_ fish: FishNode, caught: Bool = false) {
        fishes.removeAll { $0 === fish }
        if caught {
            // Fly the fish up to the fisher so the catch reads instantly.
            fish.run(.sequence([
                .group([.move(to: fisher.position, duration: 0.35),
                        .scale(to: 0.4, duration: 0.35)]),
                .removeFromParent()
            ]))
        } else {
            fish.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        // moveFishes() replenishes toward the population target next frame.
    }

    private func showFloat(_ text: String, color: UIColor) {
        addChild(FishingOverlay.floater(text, color: color,
                                        at: CGPoint(x: hook.position.x,
                                                    y: min(hook.position.y + 30,
                                                           size.height - 130))))
    }

    private func drawLine() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: fisher.position.x, y: fisher.position.y + 10))
        path.addLine(to: hook.position)
        line.path = path
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(max(0, score))
    }

    private func updateHUD() {
        timeLabel.text = "⏱ \(max(0, Int(timeLeft)))s"
        scoreLabel.text = "\(score)"
    }

    // MARK: - Touch: tap where the hook should go; tap again to reel back.

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // Never act on the pause button's corner: stealing those near-misses
        // is what made pause feel unresponsive.
        guard !isUnderPauseButton(touch.location(in: self)) else { return }
        switch state {
        case .idle:
            let location = touch.location(in: self)
            // The line is exactly as long as the tap is deep: clamp the
            // target into the water body so the hook always submerges.
            let target = CGPoint(x: min(max(location.x, 20), size.width - 20),
                                 y: min(max(location.y, 30), waterTop - 15))
            state = .casting(target: target)
        case .casting, .waiting:
            state = .reeling
        case .reeling:
            break // already coming up
        }
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
