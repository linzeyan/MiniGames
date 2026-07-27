import Testing
@testable import SmallGame

struct TowerRulesTests {
    /// Charge must clamp at both ends — an over-held press cannot launch the
    /// player past the designed ceiling, or generated gaps stop being safe.
    @Test func jumpVelocityClamps() {
        #expect(TowerRules.jumpVelocity(holdDuration: -1) == TowerRules.minJumpVelocity)
        #expect(TowerRules.jumpVelocity(holdDuration: 0) == TowerRules.minJumpVelocity)
        #expect(TowerRules.jumpVelocity(holdDuration: 10) == TowerRules.maxJumpVelocity)
        let mid = TowerRules.jumpVelocity(holdDuration: TowerRules.fullChargeDuration / 2)
        #expect(mid > TowerRules.minJumpVelocity && mid < TowerRules.maxJumpVelocity)
    }

    @Test func horizontalReachIsZeroForUnreachableHeight() {
        let vy = TowerRules.minJumpVelocity
        let tooHigh = TowerRules.maxJumpHeight(velocity: vy) + 1
        #expect(TowerRules.horizontalReach(vy: vy, dy: tooHigh) == 0)
    }

    /// Spec acceptance ("tower.md"): any seed must generate 1000 floors with
    /// no dead ends — every platform reachable at the design charge level.
    @Test func thousandFloorsAreAlwaysReachable() {
        let width = 390.0
        let platformWidth = 92.0
        let designVelocity = TowerRules.PlatformGenerator.designVelocity
        let maxHeight = TowerRules.maxJumpHeight(velocity: designVelocity)

        for seed in [UInt64(1), 42, 987_654_321] {
            var generator = TowerRules.PlatformGenerator(seed: seed)
            var previousX = width / 2
            for floor in 1...1000 {
                let next = generator.next(floor: floor, previousX: previousX,
                                          width: width, platformWidth: platformWidth)
                #expect(next.dy < maxHeight, "floor \(floor) gap too tall")
                let reach = TowerRules.horizontalReach(vy: designVelocity, dy: next.dy)
                    + platformWidth / 2
                #expect(abs(next.x - previousX) <= reach + 0.001, "floor \(floor) too far")
                #expect(next.x >= platformWidth / 2 && next.x <= width - platformWidth / 2)
                previousX = next.x
            }
        }
    }

    @Test func autoScrollRampsAndCaps() {
        #expect(TowerRules.autoScrollSpeed(floor: 0) == 28)
        #expect(TowerRules.autoScrollSpeed(floor: 50) > TowerRules.autoScrollSpeed(floor: 10))
        #expect(TowerRules.autoScrollSpeed(floor: 10_000) == 90)
    }
}
