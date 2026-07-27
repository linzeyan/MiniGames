import Foundation

/// Platform behaviours shared by shaft (and reused by tower for the
/// fragile/normal subset).
enum PlatformKind: CaseIterable {
    case normal
    case spike
    case spring
    case conveyor
    case fragile
}

/// Pure gameplay rules for "Down We Go" — no SpriteKit types so the whole
/// difficulty/health model is unit-testable.
enum ShaftRules {
    // Synced with the original NS-SHAFT 1.2 life model: 12 max, spikes -4.
    static let maxHP = 12
    static let ceilingDamage = 4
    static let spikeDamage = 4

    static func hpAfterLanding(_ hp: Int, on kind: PlatformKind) -> Int {
        switch kind {
        case .normal, .conveyor, .fragile:
            return min(maxHP, hp + 1)
        case .spike:
            return max(0, hp - spikeDamage)
        case .spring:
            return hp
        }
    }

    /// +5% every 20 floors, capped at 2.5x — keeps the late game hard while
    /// staying humanly playable.
    static func scrollMultiplier(depth: Int) -> Double {
        min(2.5, 1.0 + Double(depth / 20) * 0.05)
    }

    /// Platform mix per depth. Early floors are forgiving; hazards ramp in.
    static func weights(depth: Int) -> [PlatformKind: Int] {
        var weights: [PlatformKind: Int] = [.normal: 55, .spike: 10, .spring: 10, .conveyor: 0, .fragile: 0]
        if depth >= 10 {
            weights[.conveyor] = 10
            weights[.fragile] = 10
        }
        if depth >= 30 {
            weights[.spike] = 18
        }
        if depth >= 60 {
            weights[.fragile] = 15
            weights[.normal] = 45
        }
        return weights
    }

    struct PlatformGenerator {
        private var rng: SeededRandom

        init(seed: UInt64) {
            rng = SeededRandom(seed: seed)
        }

        /// Next platform's kind and horizontal center as a 0...1 width ratio.
        /// The ratio band keeps platforms fully on-screen.
        mutating func next(depth: Int) -> (kind: PlatformKind, xRatio: Double) {
            let weights = ShaftRules.weights(depth: depth)
            let total = weights.values.reduce(0, +)
            var roll = Int(rng.unit() * Double(total))
            var kind: PlatformKind = .normal
            for candidate in PlatformKind.allCases {
                let weight = weights[candidate] ?? 0
                if roll < weight {
                    kind = candidate
                    break
                }
                roll -= weight
            }
            let xRatio = 0.15 + rng.unit() * 0.7
            return (kind, xRatio)
        }
    }
}
