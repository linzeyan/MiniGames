import Foundation
import Testing
@testable import SmallGame

struct ScoreStoreTests {
    /// In-memory stand-in for iCloud so tests never touch a real container.
    private final class FakeCloud: KeyValueSyncStore {
        var values: [String: Int64] = [:]
        private(set) var synchronizeCount = 0

        func longLong(forKey key: String) -> Int64 { values[key] ?? 0 }
        func set(_ value: Int64, forKey key: String) { values[key] = value }
        @discardableResult func synchronize() -> Bool {
            synchronizeCount += 1
            return true
        }
    }

    /// Each test gets an isolated UserDefaults suite so runs never leak
    /// state into each other or into the developer's simulator defaults.
    private func makeStore(_ suite: String, cloud: KeyValueSyncStore? = nil) -> ScoreStore {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return ScoreStore(defaults: defaults, cloud: cloud)
    }

    @Test func startsAtZero() {
        let store = makeStore(#function)
        #expect(store.highScore(for: .shaft) == 0)
    }

    @Test func submitRecordsNewBest() {
        let store = makeStore(#function)
        #expect(store.submit(10, for: .shaft) == true)
        #expect(store.highScore(for: .shaft) == 10)
    }

    /// A lower or equal score must never overwrite the best — losing a
    /// player's record would defeat the point of a high-score board.
    @Test func lowerScoreDoesNotOverwrite() {
        let store = makeStore(#function)
        store.submit(10, for: .shaft)
        #expect(store.submit(5, for: .shaft) == false)
        #expect(store.submit(10, for: .shaft) == false)
        #expect(store.highScore(for: .shaft) == 10)
    }

    /// Scores are keyed per game; a record in one game must not bleed into
    /// another game's board.
    @Test func gamesAreIndependent() {
        let store = makeStore(#function)
        store.submit(10, for: .shaft)
        #expect(store.highScore(for: .tower) == 0)
    }

    /// A record set on another device must win: syncing that quietly reset a
    /// player's best would be worse than not syncing at all.
    @Test func cloudRecordWinsOverLocal() {
        let cloud = FakeCloud()
        cloud.values["highscore.tower"] = 99
        let store = makeStore(#function, cloud: cloud)
        store.submit(20, for: .tower)
        #expect(store.highScore(for: .tower) == 99)
        #expect(store.submit(50, for: .tower) == false)
    }

    /// Beating the synced record pushes it back up to iCloud.
    @Test func newRecordIsPushedToCloud() {
        let cloud = FakeCloud()
        let store = makeStore(#function, cloud: cloud)
        store.submit(30, for: .fishing)
        #expect(cloud.values["highscore.fishing"] == 30)
        #expect(cloud.synchronizeCount == 1)
    }

    /// Clearing must wipe the cloud copy too, or the next read restores what
    /// the player just deleted.
    @Test func resetClearsBothSides() {
        let cloud = FakeCloud()
        let store = makeStore(#function, cloud: cloud)
        store.submit(30, for: .fishing)
        store.resetAll()
        #expect(store.highScore(for: .fishing) == 0)
        #expect(cloud.values["highscore.fishing"] == 0)
    }
}
