import Foundation

/// Pure rules for "Lunchbox Defense": what each defender and bug costs and
/// does, the coin / slipper bookkeeping, and how the endless bug stream ramps
/// up. Distances are in board cells and damage in pebble hits, so the scene
/// is free to size the board per screen.
enum DefenseRules {
    static let lanes = 5
    static let startingCoins = 150
    /// Coins that trickle in on their own, so a run can never stall broke
    /// with an empty board.
    static let allowance = 25
    static let allowanceInterval: Double = 8
    /// A quiet opening to set up the first defenders.
    static let firstBugDelay: Double = 15
    static let waveLength: Double = 45

    static let piggyIncome = 25
    static let piggyInterval: Double = 12
    static let slingshotInterval: Double = 1.4
    static let firecrackerFuse: Double = 0.8
    static let firecrackerDamage: Double = 20
    /// Blast reach in cells either way along the lane; one lane to each side.
    static let firecrackerReach: Double = 1.5

    enum Defender: CaseIterable {
        case piggyBank, slingshot, schoolbag, firecracker

        var cost: Int {
            switch self {
            case .piggyBank, .schoolbag: 50
            case .slingshot: 100
            case .firecracker: 150
            }
        }

        /// Seconds of a 1-bite-per-second chewing it survives.
        var hp: Double {
            self == .schoolbag ? 30 : 4
        }

        /// Seconds before the same card can be played again. The wall and
        /// the bomb recharge slowly, or a full purse would spam them.
        var cooldown: Double {
            switch self {
            case .piggyBank, .slingshot: 5
            case .schoolbag: 20
            case .firecracker: 30
            }
        }
    }

    enum Bug: CaseIterable {
        case ant, roach, beetle

        var hp: Double {
            switch self {
            case .ant: 5
            case .roach: 3
            case .beetle: 16
            }
        }

        /// Cells per second.
        var speed: Double {
            switch self {
            case .ant: 0.3
            case .roach: 0.7
            case .beetle: 0.18
            }
        }

        /// Defender hp chewed per second.
        var bite: Double {
            self == .beetle ? 2 : 1
        }
    }

    static func wave(elapsed: Double) -> Int {
        Int(max(0, elapsed) / waveLength) + 1
    }

    /// Later waves' bugs are tougher, so a board that holds at one strength
    /// forever still falls eventually.
    static func hpScale(wave: Int) -> Double {
        1 + 0.2 * Double(max(1, wave) - 1)
    }

    /// Seconds between single bugs, tightening to a floor.
    static func spawnInterval(elapsed: Double) -> Double {
        max(1.2, 8 - 0.05 * elapsed)
    }

    /// The pack that storms in as each wave after the first begins.
    static func burstSize(wave: Int) -> Int {
        wave <= 1 ? 0 : min(1 + wave, 10)
    }

    /// Which bug to send for a uniform roll in [0, 1): ants at first, then
    /// fast roaches, then tanky beetles as the run goes on.
    static func bug(roll: Double, elapsed: Double) -> Bug {
        let beetle = min(0.25, max(0, (elapsed - 90) / 400))
        let roach = min(0.35, max(0, (elapsed - 45) / 200))
        if roll < beetle { return .beetle }
        if roll < beetle + roach { return .roach }
        return .ant
    }

    /// Whether a bug `laneOffset` lanes and `rowOffset` cells away from a
    /// firecracker is caught by its blast: the 3x3 block around it.
    static func isInBlast(laneOffset: Int, rowOffset: Double) -> Bool {
        abs(laneOffset) <= 1 && abs(rowOffset) <= firecrackerReach
    }

    struct Cell: Hashable {
        let lane: Int
        let row: Int
    }

    /// Coins, the occupied cells, card recharge and the lanes' slippers.
    struct Board {
        let rows: Int
        private(set) var coins = DefenseRules.startingCoins
        private(set) var occupied: Set<Cell> = []
        /// Lanes whose last-ditch slipper hasn't been thrown yet.
        private(set) var slippers = Set(0..<DefenseRules.lanes)
        private var readyAt: [Defender: Double] = [:]

        init(rows: Int) {
            self.rows = rows
        }

        /// Fraction of the card's recharge still to go: 0 = playable.
        func rechargeLeft(_ defender: Defender, now: Double) -> Double {
            max(0, readyAt[defender, default: 0] - now) / defender.cooldown
        }

        /// Places a defender if the cell is on the board and free, the card
        /// has recharged and the coins cover it.
        mutating func place(_ defender: Defender, at cell: Cell, now: Double) -> Bool {
            guard (0..<DefenseRules.lanes).contains(cell.lane), (0..<rows).contains(cell.row),
                  !occupied.contains(cell), rechargeLeft(defender, now: now) == 0,
                  coins >= defender.cost
            else { return false }
            coins -= defender.cost
            occupied.insert(cell)
            readyAt[defender] = now + defender.cooldown
            return true
        }

        /// The defender on `cell` was eaten or went off.
        mutating func clear(_ cell: Cell) {
            occupied.remove(cell)
        }

        mutating func earn(_ amount: Int) {
            coins += amount
        }

        /// A bug walked off the bottom of `lane`: its slipper swats the lane
        /// clear (true, once per lane), or the lunch is lost (false).
        mutating func breach(lane: Int) -> Bool {
            slippers.remove(lane) != nil
        }
    }
}
