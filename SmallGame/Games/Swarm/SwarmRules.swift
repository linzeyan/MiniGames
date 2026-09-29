import CoreGraphics

/// Pure rules for "Bug Swarm": the bugs, the auto-firing weapons and their
/// levels, experience, the level-up offers, and the thumbstick. The kid never
/// aims — moving is the only input, as in the survivor genre.
enum SwarmRules {
    static let playerMaxHP = 5
    /// Points per second at sneakers level 0.
    static let playerSpeed: CGFloat = 150
    /// Seconds of immunity after a hit, so one crowd can't drain every heart at once.
    static let hitGrace: Double = 1.0
    static let maxLevel = 5
    static let maxSneakers = 3
    /// Spawns wait past this many live bugs: every weapon scans them all each frame.
    static let maxBugs = 150

    enum Bug: CaseIterable {
        case ant, mosquito, beetle

        /// Ants and mosquitoes start as one-marble kills: the opening
        /// marble alone has to keep up with the spawn rate.
        var hp: Double {
            self == .beetle ? 10 : 1
        }

        /// Points per second.
        var speed: CGFloat {
            switch self {
            case .ant: 55
            case .mosquito: 100
            case .beetle: 35
            }
        }

        /// Experience its candy is worth.
        var xp: Int {
            self == .beetle ? 3 : 1
        }
    }

    enum Weapon: CaseIterable {
        case marbles, tops, swatter
    }

    enum Upgrade: Hashable {
        case weapon(Weapon)
        case sneakers
        case bun
    }

    /// Seconds between bugs, tightening to a floor.
    static func spawnInterval(elapsed: Double) -> Double {
        max(0.2, 1.5 - 0.007 * elapsed)
    }

    /// Bugs harden over time so a maxed build still falls eventually.
    static func hpScale(elapsed: Double) -> Double {
        1 + max(0, elapsed) / 90
    }

    /// Which bug to send for a uniform roll in [0, 1): ants first, then fast
    /// mosquitoes from 30 s, tanky beetles from a minute.
    static func bug(roll: Double, elapsed: Double) -> Bug {
        let beetle = min(0.2, max(0, (elapsed - 60) / 300))
        let mosquito = min(0.35, max(0, (elapsed - 30) / 150))
        if roll < beetle { return .beetle }
        if roll < beetle + mosquito { return .mosquito }
        return .ant
    }

    /// A point `margin` off screen, `roll` (0..<1) of the way around the edge.
    static func edgePoint(roll: Double, size: CGSize, margin: CGFloat) -> CGPoint {
        let width = size.width + 2 * margin
        let height = size.height + 2 * margin
        var along = CGFloat(roll) * 2 * (width + height)
        if along < width { return CGPoint(x: along - margin, y: -margin) }
        along -= width
        if along < height { return CGPoint(x: size.width + margin, y: along - margin) }
        along -= height
        if along < width { return CGPoint(x: along - margin, y: size.height + margin) }
        return CGPoint(x: -margin, y: along - width - margin)
    }

    /// Candy needed for the next level: early levels come quickly so the
    /// build takes shape in the first minute.
    static func xpToNext(level: Int) -> Int {
        4 + 3 * (max(1, level) - 1)
    }

    // MARK: - Weapons by level (1...maxLevel)

    static let marbleDamage: Double = 1
    static let marbleSpeed: CGFloat = 420
    static func marbleInterval(level: Int) -> Double {
        max(0.3, 0.8 - 0.12 * Double(level - 1))
    }

    /// Marbles per volley, each at a different bug.
    static func marbleCount(level: Int) -> Int {
        1 + (level - 1) / 2
    }

    static let topDamage: Double = 1
    static let topOrbit: CGFloat = 64
    /// Radians per second.
    static let topSpin: CGFloat = 3.2
    /// A bug a top just hit is immune to tops this long, or one pass would
    /// hit it every frame.
    static let topHitGap: Double = 0.4
    static func topCount(level: Int) -> Int {
        level
    }

    static let swatterDamage: Double = 2
    static func swatterReach(level: Int) -> CGFloat {
        70 + 15 * CGFloat(level)
    }

    static func swatterInterval(level: Int) -> Double {
        max(0.8, 2.2 - 0.3 * Double(level))
    }

    static func speed(sneakers: Int) -> CGFloat {
        playerSpeed * (1 + 0.15 * CGFloat(sneakers))
    }

    /// Up to three different upgrades for a level-up. Maxed weapons and
    /// sneakers drop out of the pool; the bun is always on offer, so there
    /// is never nothing to pick.
    static func offers(levels: [Weapon: Int], sneakers: Int,
                       using rng: inout some RandomNumberGenerator) -> [Upgrade] {
        var pool = Weapon.allCases.filter { levels[$0, default: 0] < maxLevel }.map(Upgrade.weapon)
        if sneakers < maxSneakers { pool.append(.sneakers) }
        pool.append(.bun)
        return Array(pool.shuffled(using: &rng).prefix(3))
    }

    /// Floating thumbstick: the touch-down point is its center. Same dead
    /// zone and full throw as RelativeSteering, in two dimensions.
    struct Stick {
        private(set) var anchor: CGPoint
        /// Any push past the dead zone is full speed (Settings' digital control).
        let isDigital: Bool

        init(anchor: CGPoint, isDigital: Bool = false) {
            self.anchor = anchor
            self.isDigital = isDigital
        }

        /// Movement for the finger at `touch`, length 0...1.
        mutating func update(touch: CGPoint) -> CGVector {
            let dx = touch.x - anchor.x
            let dy = touch.y - anchor.y
            let distance = (dx * dx + dy * dy).squareRoot()
            guard distance > RelativeSteering.deadZone else { return .zero }
            let full = RelativeSteering.fullThrow
            var strength = isDigital ? 1 : min(1, (distance - RelativeSteering.deadZone)
                                                  / (full - RelativeSteering.deadZone))
            if distance > full {
                // Drag the center along, so reversing never needs the thumb to
                // travel all the way back first.
                anchor = CGPoint(x: touch.x - dx / distance * full, y: touch.y - dy / distance * full)
                strength = 1
            }
            return CGVector(dx: dx / distance * strength, dy: dy / distance * strength)
        }
    }
}
