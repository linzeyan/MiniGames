import CoreGraphics
import Testing
@testable import SmallGame

// Steering values are read into locals before asserting: `update` is
// mutating, and calling it inside `#expect` hides whether the anchor state
// actually carried over to the next call.
struct RelativeSteeringTests {
    /// The whole point of relative steering: a finger resting where it landed
    /// must not move the player. Absolute steering failed this, which is why
    /// the screen centre felt like the origin on device.
    @Test func restingFingerDoesNotMove() {
        var steering = RelativeSteering(anchorX: 100)
        let still = steering.update(touchX: 100)
        let nudgedRight = steering.update(touchX: 104)
        let nudgedLeft = steering.update(touchX: 96)
        #expect(still == 0)
        #expect(nudgedRight == 0)
        #expect(nudgedLeft == 0)
    }

    /// The snowball fight throws on release when the finger never steered, so
    /// a player standing still can shoot one-handed. Jitter inside the dead
    /// zone must not count as steering, or that tap would be swallowed.
    @Test func aRestingFingerNeverCountsAsSteering() {
        var steering = RelativeSteering(anchorX: 200)
        _ = steering.update(touchX: 203)
        _ = steering.update(touchX: 197)
        #expect(steering.hasSteered == false)
    }

    /// Once it has walked, it stays "steered" even after sliding back home —
    /// otherwise letting go at the origin would fire an unwanted snowball.
    @Test func steeringIsRememberedAfterTheFingerReturns() {
        var steering = RelativeSteering(anchorX: 200)
        _ = steering.update(touchX: 240)
        #expect(steering.hasSteered)
        _ = steering.update(touchX: steering.anchorX)
        #expect(steering.hasSteered)
    }

    /// Direction follows the slide, not the half of the screen tapped.
    @Test func directionFollowsTheSlide() {
        var steering = RelativeSteering(anchorX: 300)
        let right = steering.update(touchX: 340)
        let left = steering.update(touchX: 260)
        #expect(right > 0)
        #expect(left < 0)
    }

    /// Analog: displacement maps proportionally so small corrections are
    /// possible, reaching full speed exactly at full throw.
    @Test func analogScalesWithDisplacement() {
        var steering = RelativeSteering(anchorX: 100)
        let midpoint = RelativeSteering.deadZone
            + (RelativeSteering.fullThrow - RelativeSteering.deadZone) / 2
        let half = steering.update(touchX: 100 + midpoint)
        let full = steering.update(touchX: 100 + RelativeSteering.fullThrow)
        #expect(abs(half - 0.5) < 0.0001)
        #expect(full == 1)
    }

    /// Digital is the opt-in arcade feel: past the dead zone it is always
    /// full speed, never partial.
    @Test func digitalIsAllOrNothing() {
        var steering = RelativeSteering(anchorX: 100, isDigital: true)
        let inside = steering.update(touchX: 103)
        let right = steering.update(touchX: 110)
        let left = steering.update(touchX: 90)
        #expect(inside == 0)
        #expect(right == 1)
        #expect(left == -1)
    }

    /// Once the finger overshoots, the anchor follows it. Without this a
    /// finger parked at the screen edge would need a full-throw slide back
    /// before the player could reverse.
    @Test func anchorFollowsSoReverseIsImmediate() {
        var steering = RelativeSteering(anchorX: 100)
        let overshoot = steering.update(touchX: 400)
        let draggedAnchor = steering.anchorX
        let reverse = steering.update(touchX: draggedAnchor - RelativeSteering.deadZone - 1)
        #expect(overshoot == 1)
        let expectedAnchor: CGFloat = 400 - RelativeSteering.fullThrow
        #expect(draggedAnchor == expectedAnchor)
        #expect(reverse < 0)
    }
}
