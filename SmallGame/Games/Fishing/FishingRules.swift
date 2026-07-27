import Foundation

/// Pure gameplay rules for "Gone Fishing": the species economy table.
enum FishingRules {
    static let sessionDuration: TimeInterval = 90
    static let comboBonus = 5

    /// Combo spans hauls now, not just one reel-in: land another fish within
    /// this window and the chain keeps growing, otherwise it starts over.
    static let comboWindow: TimeInterval = 5
    /// The combo readout is a flash of feedback, not persistent chrome — it
    /// fades so it never sits under the pause button.
    static let comboDisplayDuration: TimeInterval = 0.5

    // Like the original arcade game, good play extends the clock: every
    // full 100 points banked grants bonus seconds.
    static let timeBonusThreshold = 100
    static let timeBonusSeconds: TimeInterval = 10

    static func timeBonus(from oldScore: Int, to newScore: Int) -> TimeInterval {
        guard newScore > oldScore else { return 0 }
        let crossed = newScore / timeBonusThreshold - oldScore / timeBonusThreshold
        return Double(crossed) * timeBonusSeconds
    }

    // Frenzy moments: every so often a school of fish floods the water.
    static let frenzyInterval: TimeInterval = 25
    static let frenzyDuration: TimeInterval = 6
    static let frenzyBurstCount = 8

    struct FishSpecies: Equatable {
        let nameKey: String
        /// 0 = water surface, 1 = bottom.
        let depthRange: ClosedRange<Double>
        let points: Int
        let swimSpeed: Double
        let spawnWeight: Int
        /// Which creature body sprite to use (index into the scene's body table).
        let body: Int
        /// Tint hue (0...1) applied over the body sprite; nil = natural color.
        let hue: Double?
        var isJunk: Bool { points < 0 }
    }

    /// Deep creatures are worth more (deeper = longer, riskier round trip);
    /// junk punishes careless hooks. Every species pays differently, and
    /// point value grows strictly with the depth band.
    /// Body indexes: 0 fish, 1 long fish, 2 round fish, 3 shark,
    /// 4 swordfish, 5 ray, 6 turtle, 7 octopus, 8 jellyfish.
    static let species: [FishSpecies] = [
        FishSpecies(nameKey: "fish.anchovy", depthRange: 0.02...0.22, points: 5,
                    swimSpeed: 95, spawnWeight: 12, body: 1, hue: nil),
        FishSpecies(nameKey: "fish.sardine", depthRange: 0.05...0.25, points: 8,
                    swimSpeed: 90, spawnWeight: 12, body: 1, hue: 0.55),
        FishSpecies(nameKey: "fish.herring", depthRange: 0.08...0.28, points: 12,
                    swimSpeed: 85, spawnWeight: 11, body: 0, hue: 0.5),
        FishSpecies(nameKey: "fish.clownfish", depthRange: 0.11...0.31, points: 15,
                    swimSpeed: 80, spawnWeight: 10, body: 0, hue: 0.07),
        FishSpecies(nameKey: "fish.mullet", depthRange: 0.14...0.34, points: 18,
                    swimSpeed: 75, spawnWeight: 10, body: 0, hue: 0.35),
        FishSpecies(nameKey: "fish.mackerel", depthRange: 0.17...0.37, points: 22,
                    swimSpeed: 70, spawnWeight: 9, body: 1, hue: 0.6),
        FishSpecies(nameKey: "fish.jellyfish", depthRange: 0.2...0.4, points: 25,
                    swimSpeed: 20, spawnWeight: 9, body: 8, hue: nil),
        FishSpecies(nameKey: "fish.snapper", depthRange: 0.23...0.43, points: 28,
                    swimSpeed: 66, spawnWeight: 8, body: 0, hue: 0.95),
        FishSpecies(nameKey: "fish.flounder", depthRange: 0.26...0.46, points: 32,
                    swimSpeed: 60, spawnWeight: 8, body: 5, hue: 0.1),
        FishSpecies(nameKey: "fish.bass", depthRange: 0.29...0.49, points: 35,
                    swimSpeed: 58, spawnWeight: 7, body: 0, hue: 0.3),
        FishSpecies(nameKey: "fish.carp", depthRange: 0.32...0.52, points: 38,
                    swimSpeed: 55, spawnWeight: 7, body: 2, hue: 0.13),
        FishSpecies(nameKey: "fish.angelfish", depthRange: 0.35...0.55, points: 42,
                    swimSpeed: 52, spawnWeight: 6, body: 2, hue: 0.75),
        FishSpecies(nameKey: "fish.cod", depthRange: 0.38...0.58, points: 45,
                    swimSpeed: 50, spawnWeight: 6, body: 1, hue: 0.6),
        FishSpecies(nameKey: "fish.salmon", depthRange: 0.41...0.61, points: 50,
                    swimSpeed: 48, spawnWeight: 6, body: 0, hue: 0.02),
        FishSpecies(nameKey: "fish.tuna", depthRange: 0.44...0.64, points: 55,
                    swimSpeed: 46, spawnWeight: 5, body: 0, hue: 0.65),
        FishSpecies(nameKey: "fish.turtle", depthRange: 0.47...0.67, points: 60,
                    swimSpeed: 28, spawnWeight: 5, body: 6, hue: nil),
        FishSpecies(nameKey: "fish.puffer", depthRange: 0.5...0.7, points: 65,
                    swimSpeed: 42, spawnWeight: 5, body: 2, hue: 0.16),
        FishSpecies(nameKey: "fish.swordfish", depthRange: 0.53...0.73, points: 70,
                    swimSpeed: 40, spawnWeight: 4, body: 4, hue: 0.55),
        FishSpecies(nameKey: "fish.ray", depthRange: 0.56...0.76, points: 75,
                    swimSpeed: 38, spawnWeight: 4, body: 5, hue: 0.5),
        FishSpecies(nameKey: "fish.octopus", depthRange: 0.59...0.79, points: 80,
                    swimSpeed: 30, spawnWeight: 4, body: 7, hue: nil),
        FishSpecies(nameKey: "fish.shark", depthRange: 0.62...0.82, points: 90,
                    swimSpeed: 50, spawnWeight: 4, body: 3, hue: nil),
        FishSpecies(nameKey: "fish.golden", depthRange: 0.65...0.85, points: 120,
                    swimSpeed: 110, spawnWeight: 3, body: 0, hue: 0.14),
        FishSpecies(nameKey: "junk.can", depthRange: 0.15...0.9, points: -10,
                    swimSpeed: 30, spawnWeight: 5, body: 0, hue: nil),
        FishSpecies(nameKey: "junk.boot", depthRange: 0.2...1.0, points: -15,
                    swimSpeed: 25, spawnWeight: 6, body: 0, hue: nil)
    ]

    static func randomSpecies(rng: inout SeededRandom) -> FishSpecies {
        let total = species.reduce(0) { $0 + $1.spawnWeight }
        var roll = Int(rng.unit() * Double(total))
        for candidate in species {
            if roll < candidate.spawnWeight { return candidate }
            roll -= candidate.spawnWeight
        }
        return species[0]
    }
}
