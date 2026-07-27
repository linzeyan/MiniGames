import Testing
@testable import SmallGame

struct ShaftRulesTests {
    /// Landing effects are the core health economy, synced to the original
    /// NS-SHAFT 1.2: 12 max HP, normal-family heals +1, spikes cost 4,
    /// springs are neutral, and HP stays within 0...max.
    @Test func landingHealthEffects() {
        #expect(ShaftRules.maxHP == 12)
        #expect(ShaftRules.hpAfterLanding(5, on: .normal) == 6)
        #expect(ShaftRules.hpAfterLanding(ShaftRules.maxHP, on: .normal) == ShaftRules.maxHP)
        #expect(ShaftRules.hpAfterLanding(5, on: .spike) == 1)
        #expect(ShaftRules.hpAfterLanding(1, on: .spike) == 0)
        #expect(ShaftRules.hpAfterLanding(5, on: .spring) == 5)
        #expect(ShaftRules.hpAfterLanding(5, on: .conveyor) == 6)
        #expect(ShaftRules.hpAfterLanding(5, on: .fragile) == 6)
    }

    /// Speed must ramp with depth but stay capped, or the game becomes
    /// physically unplayable instead of hard.
    @Test func scrollSpeedRampsAndCaps() {
        #expect(ShaftRules.scrollMultiplier(depth: 0) == 1.0)
        #expect(ShaftRules.scrollMultiplier(depth: 20) == 1.05)
        #expect(ShaftRules.scrollMultiplier(depth: 40) > ShaftRules.scrollMultiplier(depth: 20))
        #expect(ShaftRules.scrollMultiplier(depth: 100_000) == 2.5)
    }

    /// Same seed must replay the same platform sequence (determinism is what
    /// makes tuning and bug reports reproducible).
    @Test func generatorIsDeterministic() {
        var lhs = ShaftRules.PlatformGenerator(seed: 42)
        var rhs = ShaftRules.PlatformGenerator(seed: 42)
        for depth in 0..<200 {
            let first = lhs.next(depth: depth)
            let second = rhs.next(depth: depth)
            #expect(first.kind == second.kind)
            #expect(first.xRatio == second.xRatio)
        }
    }

    /// Platforms must stay fully on-screen and early floors must never spawn
    /// late-game hazards the player has no HP buffer for.
    @Test func generatorRespectsDepthGating() {
        var generator = ShaftRules.PlatformGenerator(seed: 7)
        for depth in 0..<10 {
            let result = generator.next(depth: depth)
            #expect(result.kind != .conveyor)
            #expect(result.kind != .fragile)
            #expect(result.xRatio >= 0.15 && result.xRatio <= 0.85)
        }
    }
}
