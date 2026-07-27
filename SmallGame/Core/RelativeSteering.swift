import CoreGraphics

/// Finger-relative left/right steering shared by the walking games.
///
/// The touch-down point becomes the origin: the player only moves once the
/// finger slides away from where it landed. Absolute-position steering (walk
/// toward wherever the finger is) made the screen centre the de-facto origin,
/// which reads as "tap the left half to go left" on device — the opposite of
/// what a thumb expects.
struct RelativeSteering {
    /// Finger jitter below this never counts as input, so resting a thumb
    /// on the glass keeps the player still.
    static let deadZone: CGFloat = 6
    /// Displacement that maps to full speed.
    static let fullThrow: CGFloat = 48

    private(set) var anchorX: CGFloat
    /// True once the finger has left the dead zone. Lets a caller tell a tap
    /// from a drag without tracking distance itself — the snowball fight uses
    /// it to throw on a tap that never became a walk.
    private(set) var hasSteered = false
    /// Arcade keyboard feel: any push past the dead zone is full speed.
    /// Opt-in, because analog control is easier to fine-tune on glass.
    let isDigital: Bool

    init(anchorX: CGFloat, isDigital: Bool = false) {
        self.anchorX = anchorX
        self.isDigital = isDigital
    }

    /// Steering value in -1...1 for the current finger position.
    mutating func update(touchX: CGFloat) -> CGFloat {
        let offset = touchX - anchorX
        let distance = abs(offset)
        guard distance > Self.deadZone else { return 0 }
        hasSteered = true
        let direction: CGFloat = offset > 0 ? 1 : -1
        // Drag the anchor along once the finger runs past full throw, so a
        // finger parked at the screen edge can still reverse immediately.
        if distance > Self.fullThrow {
            anchorX = touchX - direction * Self.fullThrow
            return direction
        }
        guard !isDigital else { return direction }
        return direction * (distance - Self.deadZone) / (Self.fullThrow - Self.deadZone)
    }
}
