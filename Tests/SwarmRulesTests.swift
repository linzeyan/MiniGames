import CoreGraphics
import Testing
@testable import SmallGame

struct SwarmRulesTests {
    private typealias Rules = SwarmRules

    /// A maxed weapon on offer would be a wasted level-up.
    @Test func offersSkipMaxedWeaponsAndNeverRepeat() {
        var rng = SeededRandom(seed: 7)
        let levels: [Rules.Weapon: Int] = [.marbles: Rules.maxLevel, .tops: 2]
        for _ in 0..<50 {
            let offers = Rules.offers(levels: levels, sneakers: 0, using: &rng)
            #expect(offers.count == 3)
            #expect(Set(offers).count == 3)
            #expect(!offers.contains(.weapon(.marbles)))
        }
    }

    /// With everything maxed there is still something to take.
    @Test func aFullyMaxedBuildIsStillOfferedTheBun() {
        var rng = SeededRandom(seed: 1)
        let maxed = Dictionary(uniqueKeysWithValues: Rules.Weapon.allCases.map { ($0, Rules.maxLevel) })
        let offers = Rules.offers(levels: maxed, sneakers: Rules.maxSneakers, using: &rng)
        #expect(offers == [.bun])
    }

    /// A resting thumb must not move the kid.
    @Test func stickIgnoresJitterInsideTheDeadZone() {
        var stick = Rules.Stick(anchor: CGPoint(x: 100, y: 100))
        #expect(stick.update(touch: CGPoint(x: 104, y: 103)) == .zero)
    }

    /// Direction follows the thumb in two dimensions, capped at full speed.
    @Test func stickPointsWhereTheThumbGoes() {
        var stick = Rules.Stick(anchor: CGPoint(x: 100, y: 100))
        let move = stick.update(touch: CGPoint(x: 100 - 300, y: 100))
        #expect(abs(move.dx + 1) < 0.001 && abs(move.dy) < 0.001)
        let half = stick.update(touch: CGPoint(x: stick.anchor.x, y: stick.anchor.y + 27))
        #expect(half.dy > 0 && half.dy < 1)
    }

    /// Past full throw the center follows the thumb, so reversing responds at
    /// once instead of after the thumb travels back past the start point.
    @Test func stickCenterFollowsAFarThumb() {
        var stick = Rules.Stick(anchor: CGPoint(x: 100, y: 100))
        _ = stick.update(touch: CGPoint(x: 400, y: 100))
        #expect(abs(stick.anchor.x - (400 - RelativeSteering.fullThrow)) < 0.001)
        let back = stick.update(touch: CGPoint(x: 400 - RelativeSteering.fullThrow - 30, y: 100))
        #expect(back.dx < 0)
    }

    @Test func digitalStickIsAlwaysFullSpeed() {
        var stick = Rules.Stick(anchor: .zero, isDigital: true)
        let move = stick.update(touch: CGPoint(x: 0, y: -10))
        #expect(abs(move.dy + 1) < 0.001)
    }

    /// Each weapon level must be a real upgrade, never a sidegrade.
    @Test func weaponLevelsOnlyGetStronger() {
        for level in 2...Rules.maxLevel {
            #expect(Rules.marbleInterval(level: level) < Rules.marbleInterval(level: level - 1))
            #expect(Rules.marbleCount(level: level) >= Rules.marbleCount(level: level - 1))
            #expect(Rules.topCount(level: level) > Rules.topCount(level: level - 1))
            #expect(Rules.swatterReach(level: level) > Rules.swatterReach(level: level - 1))
            #expect(Rules.swatterInterval(level: level) < Rules.swatterInterval(level: level - 1))
        }
        #expect(Rules.speed(sneakers: 1) > Rules.speed(sneakers: 0))
    }

    /// The first half minute is ants only; later every kind shows up.
    @Test func bugMixOpensWithAnts() {
        for roll in stride(from: 0.0, to: 1.0, by: 0.05) {
            #expect(Rules.bug(roll: roll, elapsed: 29) == .ant)
        }
        #expect(Rules.bug(roll: 0, elapsed: 600) == .beetle)
        #expect(Rules.bug(roll: 0.3, elapsed: 600) == .mosquito)
        #expect(Rules.bug(roll: 0.99, elapsed: 600) == .ant)
    }

    /// Bugs must enter from off screen on every side: one popping in next
    /// to the kid would be an unfair hit.
    @Test func bugsEnterFromJustOffScreenAllAround() {
        let size = CGSize(width: 400, height: 800)
        var sides = Set<String>()
        for roll in stride(from: 0.0, to: 1.0, by: 0.01) {
            let point = Rules.edgePoint(roll: roll, size: size, margin: 30)
            #expect(point.x >= -30 && point.x <= 430 && point.y >= -30 && point.y <= 830)
            #expect(point.x < 0 || point.x > 400 || point.y < 0 || point.y > 800)
            if point.x == -30 { sides.insert("left") }
            if point.x == 430 { sides.insert("right") }
            if point.y == -30 { sides.insert("bottom") }
            if point.y == 830 { sides.insert("top") }
        }
        #expect(sides == ["left", "right", "bottom", "top"])
    }

    /// Pressure and the level curve only rise; spawning keeps a floor.
    @Test func pressureAndLevelCurveRise() {
        for second in stride(from: 1.0, through: 600, by: 1) {
            #expect(Rules.spawnInterval(elapsed: second) <= Rules.spawnInterval(elapsed: second - 1))
            #expect(Rules.spawnInterval(elapsed: second) >= 0.2)
        }
        for level in 2...30 {
            #expect(Rules.xpToNext(level: level) > Rules.xpToNext(level: level - 1))
        }
    }
}
