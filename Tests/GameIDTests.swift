import Testing
@testable import SmallGame

struct GameIDTests {
    /// Raw values are persisted as UserDefaults keys; changing them would
    /// silently drop players' saved high scores.
    @Test func rawValuesAreStable() {
        #expect(GameID.tower.rawValue == "tower")
        #expect(GameID.shaft.rawValue == "shaft")
        #expect(GameID.fishing.rawValue == "fishing")
        #expect(GameID.snowball.rawValue == "snowball")
        #expect(GameID.allCases.count == 4)
    }
}
