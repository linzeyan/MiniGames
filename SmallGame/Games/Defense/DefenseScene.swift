import SpriteKit

/// "Lunchbox Defense" — bugs march down five lanes toward the lunchbox. Tap a
/// card in the tray, then a lawn cell, to place a defender. Each lane's
/// slipper swats one leak; the next leak there ends the run. Score is bugs
/// squashed.
final class DefenseScene: MiniGameScene {
    private enum T {
        static let gridBottom: CGFloat = 160
        /// Room above the board where bugs show up before they reach it.
        static let spawnZone: CGFloat = 200
        static let minRows = 4
        static let trayY: CGFloat = 76
        static let cardHeight: CGFloat = 80
        static let cardGap: CGFloat = 12
        static let slipperY: CGFloat = 142
        /// Points per second the slipper sweeps up its lane.
        static let slipperSpeed: CGFloat = 900
        /// In cells per second / cells.
        static let marbleSpeed: CGFloat = 7
        static let hitReach: CGFloat = 0.35
        static let biteReach: CGFloat = 0.55
    }

    private var board = DefenseRules.Board(rows: 0)
    private var cellSize: CGFloat = 0
    private var defenders: [DefenseRules.Cell: DefenderNode] = [:]
    private var bugs: [BugNode] = []
    private var marbles: [MarbleNode] = []
    private var cards: [CardNode] = []
    private var slippers: [Int: SKSpriteNode] = [:]
    private var selected: DefenseRules.Defender?
    private let coinLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let scoreLabel = SKLabelNode(fontNamed: "Menlo-Bold")

    /// Game clock: stops while the scene is held, so recharge and spawn
    /// timers don't run out behind the pause menu.
    private var elapsed: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    private var nextSpawn = DefenseRules.firstBugDelay
    private var nextAllowance = DefenseRules.allowanceInterval
    private var wave = 1
    private var squashed = 0
    private var gameEnded = false
    // Deferred to the first live frame so it doesn't fade away while the
    // instructions overlay is holding the scene.
    private var hintShown = false
    private var rng = SeededRandom(seed: UInt64.random(in: 1...UInt64.max))

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.45, green: 0.7, blue: 0.35, alpha: 1)
        setUp()
    }

    override func restart() {
        removeAllChildren()
        defenders = [:]
        bugs = []
        marbles = []
        cards = []
        slippers = [:]
        selected = nil
        elapsed = 0
        lastUpdate = 0
        nextSpawn = DefenseRules.firstBugDelay
        nextAllowance = DefenseRules.allowanceInterval
        wave = 1
        squashed = 0
        gameEnded = false
        hintShown = true // returning player, no need to re-show
        isPaused = false
        setUp()
    }

    private func setUp() {
        addBackdrop("bg_defense.jpg")
        cellSize = size.width / CGFloat(DefenseRules.lanes)
        // Tall phones get more rows; every phone keeps a strip up top where
        // bugs are seen coming before they reach the board.
        let rows = max(T.minRows, Int((size.height - T.gridBottom - T.spawnZone) / cellSize))
        board = DefenseRules.Board(rows: rows)
        for tile in DefenseStyle.boardTiles(cell: cellSize, rows: rows, bottom: T.gridBottom) {
            addChild(tile)
        }
        addChild(DefenseStyle.tray(width: size.width, height: T.slipperY - 18))
        for lane in 0..<DefenseRules.lanes {
            let slipper = SKSpriteNode(texture: DefenseStyle.slipper, size: CGSize(width: 34, height: 34))
            slipper.position = CGPoint(x: laneX(lane), y: T.slipperY)
            slipper.zPosition = 6
            addChild(slipper)
            slippers[lane] = slipper
        }
        let kinds = DefenseRules.Defender.allCases
        let cardWidth = (size.width - T.cardGap * CGFloat(kinds.count + 1)) / CGFloat(kinds.count)
        for (index, kind) in kinds.enumerated() {
            let card = DefenseStyle.makeCard(for: kind, size: CGSize(width: cardWidth, height: T.cardHeight))
            card.position = CGPoint(x: T.cardGap + cardWidth / 2 + CGFloat(index) * (cardWidth + T.cardGap),
                                    y: T.trayY)
            addChild(card)
            cards.append(card)
        }
        setUpHUD()
        updateHUD()
    }

    private func setUpHUD() {
        let top = size.height - 70
        addChild(DefenseStyle.pill(CGRect(x: 10, y: top - 18, width: 170, height: 36)))
        let coin = SKSpriteNode(texture: DefenseStyle.coin, size: CGSize(width: 24, height: 24))
        coin.position = CGPoint(x: 32, y: top)
        coin.zPosition = 11
        addChild(coin)
        for label in [coinLabel, scoreLabel] {
            label.fontSize = 18
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.zPosition = 11
            addChild(label)
        }
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: 50, y: top)
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.position = CGPoint(x: 166, y: top)
    }

    private func laneX(_ lane: Int) -> CGFloat {
        cellSize * (CGFloat(lane) + 0.5)
    }

    private func center(of cell: DefenseRules.Cell) -> CGPoint {
        CGPoint(x: laneX(cell.lane), y: T.gridBottom + cellSize * (CGFloat(cell.row) + 0.5))
    }

    /// The board cell under a touch; the board itself rejects off-grid ones.
    private func boardCell(at point: CGPoint) -> DefenseRules.Cell? {
        guard point.y >= T.gridBottom else { return nil }
        return DefenseRules.Cell(lane: Int(point.x / cellSize), row: Int((point.y - T.gridBottom) / cellSize))
    }

    private func showBanner(_ text: String, duration: TimeInterval) {
        addChild(DefenseStyle.banner(text, at: CGPoint(x: size.width / 2, y: size.height * 0.62),
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
            showBanner(String(localized: "hint.defense"), duration: 3.0)
        }
        let dt = lastUpdate == 0 ? 0 : min(currentTime - lastUpdate, 1.0 / 30.0)
        lastUpdate = currentTime
        guard dt > 0 else { return }
        elapsed += dt

        if elapsed >= nextAllowance {
            nextAllowance += DefenseRules.allowanceInterval
            earn(DefenseRules.allowance, at: CGPoint(x: 80, y: size.height - 110))
        }
        spawnBugs()
        moveBugs(dt: dt)
        runDefenders()
        moveMarbles(dt: dt)
        updateHUD()
    }

    private func earn(_ amount: Int, at position: CGPoint) {
        board.earn(amount)
        addChild(DefenseStyle.floatingText("+\(amount)", at: position))
    }

    // MARK: - Bugs

    private func spawnBugs() {
        let current = DefenseRules.wave(elapsed: elapsed)
        if current > wave {
            wave = current
            showBanner(String(localized: "defense.wave \(wave)"), duration: 2.0)
            AudioManager.shared.play("sfx_frenzy")
            for queue in 0..<DefenseRules.burstSize(wave: wave) {
                spawnBug(queue: queue)
            }
        }
        guard elapsed >= nextSpawn else { return }
        nextSpawn = elapsed + DefenseRules.spawnInterval(elapsed: elapsed)
        spawnBug(queue: 0)
    }

    /// `queue` stacks a burst above the screen so its bugs file in one after
    /// another instead of landing on top of each other.
    private func spawnBug(queue: Int) {
        let kind = DefenseRules.bug(roll: rng.unit(), elapsed: elapsed)
        let bug = DefenseStyle.makeBug(kind, cell: cellSize)
        bug.lane = Int(rng.next() % UInt64(DefenseRules.lanes))
        bug.hp = kind.hp * DefenseRules.hpScale(wave: wave)
        bug.position = CGPoint(x: laneX(bug.lane), y: size.height + cellSize * (0.5 + 0.7 * CGFloat(queue)))
        addChild(bug)
        bugs.append(bug)
    }

    private func moveBugs(dt: TimeInterval) {
        for bug in bugs where bug.hp > 0 {
            let meal = defender(chewedBy: bug)
            // A waddle while walking and a faster chomp while eating keep the
            // static sprites from reading as stuck.
            bug.zRotation = meal == nil ? sin(elapsed * 9 + Double(bug.lane)) * 0.08 : sin(elapsed * 24) * 0.18
            if let meal {
                meal.hp -= bug.kind.bite * dt
                if meal.hp <= 0 { remove(meal) }
                continue
            }
            bug.position.y -= CGFloat(bug.kind.speed) * cellSize * dt
            if bug.position.y < T.gridBottom {
                breach(by: bug)
            }
        }
        bugs.removeAll { $0.hp <= 0 }
    }

    private func defender(chewedBy bug: BugNode) -> DefenderNode? {
        defenders.values.first {
            $0.cell.lane == bug.lane && bug.position.y > $0.position.y
                && bug.position.y - $0.position.y < cellSize * T.biteReach
        }
    }

    /// A bug got past the board: the lane's slipper sweeps up it once,
    /// squashing everything in the lane; with no slipper left, lunch is lost.
    private func breach(by bug: BugNode) {
        guard board.breach(lane: bug.lane) else { return endGame() }
        let sweep = (size.height - T.slipperY) / T.slipperSpeed
        slippers.removeValue(forKey: bug.lane)?.run(.sequence([
            .group([.moveTo(y: size.height + 40, duration: sweep), .rotate(byAngle: .pi * 4, duration: sweep)]),
            .removeFromParent()
        ]))
        Haptics.impact(.heavy)
        AudioManager.shared.play("sfx_spring")
        for victim in bugs where victim.hp > 0 && victim.lane == bug.lane && victim.position.y < size.height {
            // Each bug goes when the slipper reaches it.
            squash(victim, after: (victim.position.y - T.slipperY) / T.slipperSpeed)
        }
    }

    private func hurt(_ bug: BugNode, by damage: Double) {
        bug.hp -= damage
        if bug.hp <= 0 {
            squash(bug)
        } else {
            bug.run(.sequence([.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.05),
                               .colorize(withColorBlendFactor: 0, duration: 0.15)]))
        }
    }

    /// Dead to gameplay at once; the flattening plays after `delay`.
    private func squash(_ bug: BugNode, after delay: TimeInterval = 0) {
        bug.hp = 0
        squashed += 1
        Haptics.impact(.light)
        AudioManager.shared.play("sfx_catch")
        bug.run(.sequence([.wait(forDuration: delay),
                           .group([.scaleY(to: 0.2, duration: 0.15), .fadeOut(withDuration: 0.3)]),
                           .removeFromParent()]))
    }

    // MARK: - HUD and input

    private func updateHUD() {
        coinLabel.text = "\(board.coins)"
        scoreLabel.text = "✕\(squashed)"
        for card in cards {
            card.show(selected: card.kind == selected,
                      affordable: board.coins >= card.kind.cost,
                      recharge: board.rechargeLeft(card.kind, now: elapsed))
        }
    }

    private func endGame() {
        guard !gameEnded else { return }
        gameEnded = true
        Haptics.notify(.error)
        AudioManager.shared.play("sfx_gameover")
        onGameOver?(squashed)
    }

    /// Tap a card to pick it up (again to put it back), then a cell to place
    /// it. A card that can't be played yet refuses the pick right away,
    /// rather than failing later on the lawn.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !gameEnded, !isHeld, let point = touches.first?.location(in: self),
              !isUnderPauseButton(point) else { return }
        if let card = cards.first(where: { $0.contains(point) }) {
            if card.kind == selected {
                selected = nil
            } else if board.coins >= card.kind.cost, board.rechargeLeft(card.kind, now: elapsed) == 0 {
                selected = card.kind
                Haptics.impact(.light)
            } else {
                Haptics.notify(.warning)
            }
        } else if let kind = selected, let cell = boardCell(at: point) {
            guard board.place(kind, at: cell, now: elapsed) else {
                Haptics.notify(.warning)
                return
            }
            place(kind, at: cell)
            selected = nil
        }
        updateHUD()
    }
}

extension DefenseScene {
    // MARK: - Defenders

    private func place(_ kind: DefenseRules.Defender, at cell: DefenseRules.Cell) {
        let defender = DefenseStyle.makeDefender(kind, cell: cellSize)
        defender.cell = cell
        defender.position = center(of: cell)
        defender.nextAction = switch kind {
        case .piggyBank: elapsed + DefenseRules.piggyInterval / 2
        case .slingshot: elapsed
        case .schoolbag: .infinity
        case .firecracker: elapsed + DefenseRules.firecrackerFuse
        }
        addChild(defender)
        defenders[cell] = defender
        Haptics.impact(.medium)
        AudioManager.shared.play("sfx_land")
    }

    private func remove(_ defender: DefenderNode) {
        board.clear(defender.cell)
        defenders[defender.cell] = nil
        defender.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
    }

    private func runDefenders() {
        for defender in defenders.values where elapsed >= defender.nextAction {
            switch defender.kind {
            case .piggyBank:
                defender.nextAction = elapsed + DefenseRules.piggyInterval
                earn(DefenseRules.piggyIncome, at: defender.position)
            case .slingshot:
                // Hold fire until a bug is on screen in the lane ahead.
                guard bugs.contains(where: { $0.hp > 0 && $0.lane == defender.cell.lane
                                        && $0.position.y > defender.position.y && $0.position.y < size.height })
                else { continue }
                defender.nextAction = elapsed + DefenseRules.slingshotInterval
                shoot(from: defender)
            case .firecracker:
                explode(defender)
            case .schoolbag:
                break
            }
        }
    }

    private func shoot(from slingshot: DefenderNode) {
        let marble = DefenseStyle.makeMarble(lane: slingshot.cell.lane)
        marble.position = CGPoint(x: slingshot.position.x, y: slingshot.position.y + cellSize * 0.3)
        addChild(marble)
        marbles.append(marble)
        slingshot.run(.sequence([.scaleY(to: 0.85, duration: 0.06), .scaleY(to: 1, duration: 0.1)]))
    }

    private func moveMarbles(dt: TimeInterval) {
        for marble in marbles {
            marble.position.y += T.marbleSpeed * cellSize * dt
            if let bug = bugs.first(where: { $0.hp > 0 && $0.lane == marble.lane
                                        && abs($0.position.y - marble.position.y) < cellSize * T.hitReach }) {
                marble.removeFromParent()
                hurt(bug, by: 1)
            } else if marble.position.y > size.height {
                marble.removeFromParent()
            }
        }
        marbles.removeAll { $0.parent == nil }
    }

    private func explode(_ firecracker: DefenderNode) {
        remove(firecracker)
        addChild(DefenseStyle.blast(at: firecracker.position, radius: cellSize * 1.5))
        Haptics.impact(.heavy)
        AudioManager.shared.play("sfx_hurt")
        for bug in bugs where bug.hp > 0 {
            let rows = Double((bug.position.y - firecracker.position.y) / cellSize)
            if DefenseRules.isInBlast(laneOffset: bug.lane - firecracker.cell.lane, rowOffset: rows) {
                hurt(bug, by: DefenseRules.firecrackerDamage)
            }
        }
    }
}
