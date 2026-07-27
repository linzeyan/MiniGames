import Foundation

/// Pure gameplay rules for "Up We Go": charge-jump physics, difficulty
/// ramp, and a platform generator that guarantees reachability.
enum TowerRules {
    static let gravity: Double = 1500
    static let minJumpVelocity: Double = 520
    static let maxJumpVelocity: Double = 980
    static let fullChargeDuration: Double = 0.8
    static let moveSpeed: Double = 210

    static func jumpVelocity(holdDuration: Double) -> Double {
        let t = min(1, max(0, holdDuration / fullChargeDuration))
        return minJumpVelocity + (maxJumpVelocity - minJumpVelocity) * t
    }

    static func maxJumpHeight(velocity: Double) -> Double {
        velocity * velocity / (2 * gravity)
    }

    /// Horizontal distance coverable while rising `dy` with launch speed `vy`
    /// (first root of the ballistic equation; 0 when `dy` is unreachable).
    static func horizontalReach(vy: Double, dy: Double) -> Double {
        let disc = vy * vy - 2 * gravity * dy
        guard disc > 0 else { return 0 }
        let time = (vy - disc.squareRoot()) / gravity
        return moveSpeed * time
    }

    /// Downward auto-scroll pressure, ramping with height but capped.
    static func autoScrollSpeed(floor: Int) -> Double {
        min(90, 28 + Double(floor) * 0.8)
    }

    struct PlatformGenerator {
        /// Generated placements assume ~85% of a full charge with a 0.8
        /// safety factor, so a decent (not frame-perfect) jump always works.
        static let designVelocity = TowerRules.jumpVelocity(holdDuration: 0.85 * TowerRules.fullChargeDuration)
        static let safetyFactor = 0.8

        private var rng: SeededRandom

        init(seed: UInt64) {
            rng = SeededRandom(seed: seed)
        }

        /// Next platform placement relative to the previous one.
        /// `x` is absolute and clamped inside the playfield.
        mutating func next(floor: Int, previousX: Double, width: Double,
                           platformWidth: Double) -> (x: Double, dy: Double, kind: PlatformKind) {
            let maxHeight = TowerRules.maxJumpHeight(velocity: Self.designVelocity)
            // Gaps widen with height, but never beyond a safe jump.
            let dyMin = 70.0
            let dyMax = min(maxHeight * Self.safetyFactor, 110 + Double(floor) * 0.9)
            let dy = dyMin + rng.unit() * (max(dyMax, dyMin + 1) - dyMin)

            let reach = TowerRules.horizontalReach(vy: Self.designVelocity, dy: dy) * Self.safetyFactor
                + platformWidth / 2
            let margin = platformWidth / 2 + 8
            let dx = (rng.unit() * 2 - 1) * reach
            let x = min(max(previousX + dx, margin), width - margin)

            let kind: PlatformKind
            let roll = rng.unit()
            if floor >= 25, roll < 0.2 {
                kind = .conveyor // repurposed as "moving" in the tower scene
            } else if floor >= 15, roll >= 0.2, roll < 0.4 {
                kind = .fragile
            } else {
                kind = .normal
            }
            return (x, dy, kind)
        }
    }
}
