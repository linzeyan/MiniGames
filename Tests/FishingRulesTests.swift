import Testing
@testable import SmallGame

struct FishingRulesTests {
    /// The species table is the game's economy: depth bands must be valid,
    /// non-junk must pay, junk must cost.
    @Test func speciesTableIsWellFormed() {
        #expect(!FishingRules.species.isEmpty)
        for species in FishingRules.species {
            #expect(species.depthRange.lowerBound >= 0)
            #expect(species.depthRange.upperBound <= 1)
            #expect(species.spawnWeight > 0)
            #expect(species.swimSpeed > 0)
            #expect(species.isJunk == (species.points < 0))
        }
        #expect(FishingRules.species.contains { $0.isJunk })
        #expect(FishingRules.species.contains { !$0.isJunk })
    }

    /// Product requirement: more than 20 fish species, and every species —
    /// junk included — pays a different amount, so no two catches feel alike.
    @Test func varietyIsWideAndEveryPayoutIsUnique() {
        let fishCount = FishingRules.species.filter { !$0.isJunk }.count
        #expect(fishCount > 20)
        let payouts = FishingRules.species.map(\.points)
        #expect(Set(payouts).count == payouts.count)
    }

    /// Good play extends the clock (as in the original): bonus seconds are
    /// granted exactly when the score crosses each 100-point threshold, and
    /// never when the score drops.
    @Test func timeBonusTriggersOnThresholdCrossings() {
        #expect(FishingRules.timeBonus(from: 90, to: 110) == FishingRules.timeBonusSeconds)
        #expect(FishingRules.timeBonus(from: 0, to: 350) == 3 * FishingRules.timeBonusSeconds)
        #expect(FishingRules.timeBonus(from: 100, to: 150) == 0)
        #expect(FishingRules.timeBonus(from: 110, to: 95) == 0)
    }

    /// Deeper fish must be worth more — that is the risk/reward the whole
    /// depth mechanic sells (deeper = longer, riskier round trip).
    @Test func deeperFishPayMore() {
        let real = FishingRules.species.filter { !$0.isJunk }
            .sorted { $0.depthRange.lowerBound < $1.depthRange.lowerBound }
        for pair in zip(real, real.dropFirst()) {
            #expect(pair.0.points <= pair.1.points)
        }
    }

    /// Weighted spawning must be deterministic per seed and cover every
    /// species over a long run (no dead table rows).
    @Test func randomSpeciesCoversTableDeterministically() {
        var rngA = SeededRandom(seed: 99)
        var rngB = SeededRandom(seed: 99)
        var seen = Set<String>()
        for _ in 0..<500 {
            let first = FishingRules.randomSpecies(rng: &rngA)
            let second = FishingRules.randomSpecies(rng: &rngB)
            #expect(first == second)
            seen.insert(first.nameKey)
        }
        #expect(seen.count == FishingRules.species.count)
    }
}
