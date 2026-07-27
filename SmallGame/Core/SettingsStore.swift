import Foundation

/// Player-facing preferences, backed by UserDefaults.
///
/// Kept separate from `ScoreStore` because settings are UI state the player
/// edits directly, while scores are gameplay records.
struct SettingsStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isMusicEnabled: Bool {
        get { flag(Key.music, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.music) }
    }

    var isSoundEffectsEnabled: Bool {
        get { flag(Key.soundEffects, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.soundEffects) }
    }

    var isHapticsEnabled: Bool {
        get { flag(Key.haptics, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.haptics) }
    }

    /// Mirror best scores through iCloud so a new device inherits them.
    var isCloudSyncEnabled: Bool {
        get { flag(Key.cloudSync, default: true) }
        nonmutating set { defaults.set(newValue, forKey: Key.cloudSync) }
    }

    /// Digital (arcade) steering instead of the analog default: past the
    /// dead zone the player always runs at full speed.
    var usesDigitalControl: Bool {
        get { flag(Key.digitalControl, default: false) }
        nonmutating set { defaults.set(newValue, forKey: Key.digitalControl) }
    }

    /// In-app language override. iOS reads `AppleLanguages` from the app's own
    /// defaults at launch, so a change here needs a relaunch to take effect —
    /// the alternative (a custom bundle swap) is far more to maintain.
    var language: AppLanguage {
        get { AppLanguage(rawValue: defaults.string(forKey: Key.language) ?? "") ?? .system }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Key.language)
            switch newValue {
            case .system: defaults.removeObject(forKey: Key.appleLanguages)
            case .traditionalChinese, .english:
                defaults.set([newValue.rawValue], forKey: Key.appleLanguages)
            }
        }
    }

    enum AppLanguage: String, CaseIterable, Identifiable {
        case system
        case traditionalChinese = "zh-Hant"
        case english = "en"

        var id: String { rawValue }

        /// Language names read in their own language, the way iOS lists them;
        /// only "system" needs translating.
        var label: String {
            switch self {
            case .system: String(localized: "settings.language.system")
            case .traditionalChinese: "正體中文"
            case .english: "English"
            }
        }
    }

    // MARK: - Tutorials
    //
    // The how-to card shows once per game; Settings can bring them all back.

    func hasSeenTutorial(for game: GameID) -> Bool {
        defaults.bool(forKey: Key.tutorial(game))
    }

    func markTutorialSeen(for game: GameID) {
        defaults.set(true, forKey: Key.tutorial(game))
    }

    func resetTutorials() {
        for game in GameID.allCases {
            defaults.removeObject(forKey: Key.tutorial(game))
        }
    }

    /// Folds the old single `settings.muted` switch into the split
    /// music / effects pair. Runs once; after that the legacy key is dead.
    func migrateLegacyMuteIfNeeded() {
        guard !defaults.bool(forKey: Key.migratedFromMuted) else { return }
        defaults.set(true, forKey: Key.migratedFromMuted)
        guard defaults.bool(forKey: Key.legacyMuted) else { return }
        defaults.set(false, forKey: Key.music)
        defaults.set(false, forKey: Key.soundEffects)
    }

    /// Unset means "use the default" — `bool(forKey:)` alone cannot express
    /// a setting that ships enabled.
    private func flag(_ key: String, default defaultValue: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private enum Key {
        static let music = "settings.music.enabled"
        static let soundEffects = "settings.sfx.enabled"
        static let haptics = "settings.haptics.enabled"
        static let cloudSync = "settings.icloud.enabled"
        static let digitalControl = "settings.control.digital"
        static let language = "settings.language"
        static let appleLanguages = "AppleLanguages"
        static let migratedFromMuted = "settings.migratedFromMuted"
        static let legacyMuted = "settings.muted"

        static func tutorial(_ game: GameID) -> String {
            "tutorial.seen.\(game.rawValue)"
        }
    }
}
