import Foundation

/// The slice of NSUbiquitousKeyValueStore that score syncing needs, so tests
/// can stand in a fake instead of touching a real iCloud container.
protocol KeyValueSyncStore {
    func longLong(forKey key: String) -> Int64
    func set(_ value: Int64, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: KeyValueSyncStore {}

/// Persists per-game best scores in UserDefaults, optionally mirrored to
/// iCloud so a second device inherits the player's records.
struct ScoreStore {
    private let defaults: UserDefaults
    private let cloud: KeyValueSyncStore?

    init(defaults: UserDefaults = .standard,
         cloud: KeyValueSyncStore? = ScoreStore.defaultCloud()) {
        self.defaults = defaults
        self.cloud = cloud
    }

    /// nil when the player turned sync off — then nothing leaves the device.
    static func defaultCloud(settings: SettingsStore = SettingsStore()) -> KeyValueSyncStore? {
        settings.isCloudSyncEnabled ? NSUbiquitousKeyValueStore.default : nil
    }

    /// The best of what this device knows and what iCloud carries: a device
    /// that was offline must not erase a record set elsewhere.
    func highScore(for game: GameID) -> Int {
        let local = defaults.integer(forKey: Self.key(for: game))
        guard let cloud else { return local }
        return max(local, Int(cloud.longLong(forKey: Self.key(for: game))))
    }

    /// Records the score if it beats the stored best.
    /// Returns true when a new record was set.
    @discardableResult
    func submit(_ score: Int, for game: GameID) -> Bool {
        guard score > highScore(for: game) else { return false }
        defaults.set(score, forKey: Self.key(for: game))
        if let cloud {
            cloud.set(Int64(score), forKey: Self.key(for: game))
            cloud.synchronize()
        }
        return true
    }

    /// Clears every board (Settings → reset). The cloud copy has to be
    /// cleared too, or the next read would restore what was just deleted.
    func resetAll() {
        for game in GameID.allCases {
            defaults.removeObject(forKey: Self.key(for: game))
            cloud?.set(0, forKey: Self.key(for: game))
        }
        cloud?.synchronize()
    }

    private static func key(for game: GameID) -> String {
        "highscore.\(game.rawValue)"
    }
}
