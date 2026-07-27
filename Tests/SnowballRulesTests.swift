import Testing
@testable import SmallGame

struct SnowballRulesTests {
    /// Point-and-throw must actually land on the finger: that is the whole
    /// promise of the control scheme, and it is what the old slingshot pull
    /// could not deliver without a screen-long drag.
    @Test func playerThrowLandsOnTheAimPoint() {
        let from = (x: 200.0, y: 110.0)
        let target = (x: 90.0, y: 520.0)
        let velocity = SnowballRules.playerLaunchVelocity(fromX: from.x, fromY: from.y,
                                                          toX: target.x, toY: target.y)
        let distance = ((target.x - from.x) * (target.x - from.x)
                        + (target.y - from.y) * (target.y - from.y)).squareRoot()
        let landing = SnowballRules.position(startX: from.x, startY: from.y,
                                             vx: velocity.dx, vy: velocity.dy,
                                             t: SnowballRules.playerFlightTime(distance: distance))
        #expect(abs(landing.x - target.x) < 0.001)
        #expect(abs(landing.y - target.y) < 0.001)
    }

    /// A target so far away that the arc would need an unreadable speed gets
    /// clamped instead — the shot falls short rather than turning into a
    /// bullet across the screen.
    @Test func extremeThrowIsCappedAtMaxSpeed() {
        let velocity = SnowballRules.playerLaunchVelocity(fromX: 0, fromY: 0,
                                                          toX: 4000, toY: 4000)
        let speed = (velocity.dx * velocity.dx + velocity.dy * velocity.dy).squareRoot()
        #expect(abs(speed - SnowballRules.maxThrowSpeed) < 0.001)
    }

    /// Flight time must stay inside the readable window whatever the distance,
    /// so close shots are not instant and long shots do not float.
    @Test func flightTimeStaysInReadableWindow() {
        #expect(SnowballRules.playerFlightTime(distance: 0) == 0.45)
        #expect(SnowballRules.playerFlightTime(distance: 10_000) == 1.1)
        let mid = SnowballRules.playerFlightTime(distance: 400)
        #expect(mid > 0.45 && mid < 1.1)
    }

    /// Ballistics sanity: a projectile thrown straight up at g·t returns to
    /// its start height after 2t (closed-form check of the integrator input).
    @Test func ballisticPositionMatchesClosedForm() {
        let vy = SnowballRules.gravity // reaches apex at exactly t = 1
        let apex = SnowballRules.position(startX: 0, startY: 0, vx: 0, vy: vy, t: 1)
        #expect(abs(apex.y - SnowballRules.gravity / 2) < 0.001)
        let back = SnowballRules.position(startX: 0, startY: 0, vx: 0, vy: vy, t: 2)
        #expect(abs(back.y) < 0.001)
    }

    /// Enemy aim must actually land on the target when no error is applied —
    /// accuracy comes only from the explicit error radius.
    @Test func aimVelocityHitsTarget() {
        let aim = SnowballRules.aimVelocity(fromX: 100, fromY: 600, toX: 250, toY: 110, flightTime: 1.15)
        let landing = SnowballRules.position(startX: 100, startY: 600,
                                             vx: aim.dx, vy: aim.dy, t: 1.15)
        #expect(abs(landing.x - 250) < 0.001)
        #expect(abs(landing.y - 110) < 0.001)
    }

    /// Difficulty must ramp monotonically, so no level is ever easier than
    /// the one before it.
    @Test func levelConfigRampsMonotonically() {
        let first = SnowballRules.LevelConfig(level: 1)
        #expect(first.enemyCount == 2)
        for level in 2...80 {
            let previous = SnowballRules.LevelConfig(level: level - 1)
            let current = SnowballRules.LevelConfig(level: level)
            #expect(current.enemyCount >= previous.enemyCount)
            #expect(current.movingCount >= previous.movingCount)
            #expect(current.moveSpeed >= previous.moveSpeed)
            #expect(current.throwInterval <= previous.throwInterval)
            #expect(current.errorRadius <= previous.errorRadius)
        }
        #expect(SnowballRules.LevelConfig(level: 99).enemyCount == 5)
    }

    /// The squad starts still, then one enemy patrols, then more, until every
    /// one of them is dodging — a standing target forever would go stale.
    @Test func enemiesStartMovingOneAtATime() {
        #expect(SnowballRules.LevelConfig(level: 1).movingCount == 0)
        #expect(SnowballRules.LevelConfig(level: 3).movingCount == 1)
        #expect(SnowballRules.LevelConfig(level: 5).movingCount == 2)
        let late = SnowballRules.LevelConfig(level: 12)
        #expect(late.movingCount == late.enemyCount)
    }

    /// Crossing a big stage has to tighten the AI further: the per-level ramp
    /// bottoms out around level 8, and without this the game plateaus.
    @Test func crossingAStageTightensTheFloor() {
        let lastOfFirstStage = SnowballRules.LevelConfig(level: SnowballRules.levelsPerStage)
        let firstOfSecondStage = SnowballRules.LevelConfig(level: SnowballRules.levelsPerStage + 1)
        #expect(lastOfFirstStage.stage == 0)
        #expect(firstOfSecondStage.stage == 1)
        #expect(firstOfSecondStage.throwInterval < lastOfFirstStage.throwInterval)
        #expect(firstOfSecondStage.errorRadius < lastOfFirstStage.errorRadius)
    }

    /// Harder must never become unplayable: the floors bottom out well above
    /// zero however far the player gets.
    @Test func difficultyFloorsStayPlayable() {
        let absurd = SnowballRules.LevelConfig(level: 500)
        #expect(absurd.throwInterval >= 0.5)
        #expect(absurd.errorRadius >= 4)
        #expect(absurd.moveSpeed <= 120)
    }
}
