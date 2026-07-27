import Foundation

/// Pure gameplay rules for "Snowball Fight": slingshot ballistics and the
/// per-level difficulty table.
enum SnowballRules {
    static let gravity: Double = 900
    static let maxThrowSpeed: Double = 1150
    static let playerMaxHP = 5

    /// Flight time the player's throw aims for. Longer shots hang longer, so
    /// the arc stays readable instead of flattening into a rifle shot.
    static func playerFlightTime(distance: Double) -> Double {
        min(1.1, max(0.45, distance / 500))
    }

    /// Point-and-throw: the ball lands where the finger is. Replaces the
    /// slingshot pull, which needed a ~340pt drag for full power and threw
    /// away from the finger — both unusable one-handed on a phone.
    static func playerLaunchVelocity(fromX: Double, fromY: Double,
                                     toX: Double, toY: Double) -> (dx: Double, dy: Double) {
        let dx = toX - fromX
        let dy = toY - fromY
        let distance = (dx * dx + dy * dy).squareRoot()
        let aim = aimVelocity(fromX: fromX, fromY: fromY, toX: toX, toY: toY,
                              flightTime: playerFlightTime(distance: distance))
        let speed = (aim.dx * aim.dx + aim.dy * aim.dy).squareRoot()
        guard speed > maxThrowSpeed else { return aim }
        let scale = maxThrowSpeed / speed
        return (aim.dx * scale, aim.dy * scale)
    }

    /// Ballistic position after `t` seconds (used for the aim guide dots and
    /// tested against closed-form expectations).
    static func position(startX: Double, startY: Double,
                         vx: Double, vy: Double, t: Double) -> (x: Double, y: Double) {
        (startX + vx * t, startY + vy * t - gravity * t * t / 2)
    }

    /// Velocity that lands a projectile on `target` after `flightTime` —
    /// how enemies aim before their accuracy error is applied.
    static func aimVelocity(fromX: Double, fromY: Double,
                            toX: Double, toY: Double, flightTime: Double) -> (dx: Double, dy: Double) {
        let vx = (toX - fromX) / flightTime
        let vy = (toY - fromY + gravity * flightTime * flightTime / 2) / flightTime
        return (vx, vy)
    }

    /// Levels per big stage. The per-level ramp bottoms out within the first
    /// dozen levels; crossing a stage lowers the floor again, so the squad
    /// keeps getting faster and more accurate instead of plateauing.
    static let levelsPerStage = 25

    /// Difficulty per level: more enemies (capped), more of them on the move,
    /// faster throws, tighter aim.
    struct LevelConfig {
        let enemyCount: Int
        /// How many of the squad patrol instead of standing still.
        let movingCount: Int
        let moveSpeed: Double
        let throwInterval: Double
        let errorRadius: Double
        let stage: Int

        init(level: Int) {
            let level = max(1, level)
            let stage = (level - 1) / SnowballRules.levelsPerStage
            self.stage = stage
            enemyCount = min(2 + (level - 1), 5)
            // One enemy starts moving at level 3, one more every second level,
            // until the whole squad is dodging.
            movingCount = min(enemyCount, (level - 1) / 2)
            moveSpeed = min(120, 45 + 6 * Double(level - 1) + 15 * Double(stage))
            throwInterval = max(Self.intervalFloor(stage: stage), 3.0 - 0.25 * Double(level - 1))
            errorRadius = max(Self.errorFloor(stage: stage), 90 - 12 * Double(level - 1))
        }

        /// Floors stay above zero: harder must never become unplayable.
        private static func intervalFloor(stage: Int) -> Double {
            max(0.5, 1.2 - 0.2 * Double(stage))
        }

        private static func errorFloor(stage: Int) -> Double {
            max(4, 12 - 3 * Double(stage))
        }
    }
}
