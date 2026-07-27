import Foundation
import Testing
@testable import SmallGame

struct SettingsStoreTests {
    /// Isolated suite per test, same as ScoreStoreTests, so settings never
    /// leak between runs or into the developer's simulator defaults.
    private func makeDefaults(_ suite: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// A fresh install must arrive with sound on and analog steering: these
    /// ship enabled, so an unset key cannot mean "off".
    @Test func shippingDefaults() {
        let store = SettingsStore(defaults: makeDefaults(#function))
        #expect(store.isMusicEnabled)
        #expect(store.isSoundEffectsEnabled)
        #expect(store.isHapticsEnabled)
        #expect(store.isCloudSyncEnabled)
        #expect(store.usesDigitalControl == false)
    }

    @Test func togglesPersist() {
        let store = SettingsStore(defaults: makeDefaults(#function))
        store.isMusicEnabled = false
        store.usesDigitalControl = true
        #expect(store.isMusicEnabled == false)
        #expect(store.usesDigitalControl)
    }

    /// A player who muted the old build must stay muted after the upgrade —
    /// the single switch becomes both new ones.
    @Test func legacyMuteBecomesBothSwitchesOff() {
        let defaults = makeDefaults(#function)
        defaults.set(true, forKey: "settings.muted")
        let store = SettingsStore(defaults: defaults)
        store.migrateLegacyMuteIfNeeded()
        #expect(store.isMusicEnabled == false)
        #expect(store.isSoundEffectsEnabled == false)
    }

    /// Migration runs once: turning music back on must survive the next
    /// launch, not be re-muted by the stale legacy key.
    @Test func migrationDoesNotRepeat() {
        let defaults = makeDefaults(#function)
        defaults.set(true, forKey: "settings.muted")
        let store = SettingsStore(defaults: defaults)
        store.migrateLegacyMuteIfNeeded()
        store.isMusicEnabled = true
        store.migrateLegacyMuteIfNeeded()
        #expect(store.isMusicEnabled)
    }

    /// An unmuted old install keeps the shipping defaults.
    @Test func migrationLeavesUnmutedInstallAlone() {
        let store = SettingsStore(defaults: makeDefaults(#function))
        store.migrateLegacyMuteIfNeeded()
        #expect(store.isMusicEnabled)
        #expect(store.isSoundEffectsEnabled)
    }

    /// The picker is only half the feature: iOS reads `AppleLanguages` at
    /// launch, so choosing a language must write that key too or the next
    /// launch comes back in the system language.
    @Test func choosingALanguageOverridesAppleLanguages() {
        let defaults = makeDefaults(#function)
        let store = SettingsStore(defaults: defaults)
        #expect(store.language == .system)

        store.language = .english
        #expect(store.language == .english)
        #expect(defaults.stringArray(forKey: "AppleLanguages") == ["en"])
    }

    /// Going back to "follow system" must drop our own override rather than
    /// pin the app to whatever was picked last. Checked against the app's
    /// persistent domain, not `object(forKey:)` — the latter falls through to
    /// the global domain, where iOS always keeps an `AppleLanguages`.
    @Test func followingTheSystemClearsTheOverride() {
        let suite = #function
        let store = SettingsStore(defaults: makeDefaults(suite))
        store.language = .traditionalChinese
        #expect(UserDefaults.standard.persistentDomain(forName: suite)?["AppleLanguages"] != nil)

        store.language = .system
        #expect(store.language == .system)
        #expect(UserDefaults.standard.persistentDomain(forName: suite)?["AppleLanguages"] == nil)
    }

    /// Settings can bring every tutorial card back at once.
    @Test func resetTutorialsClearsEveryGame() {
        let store = SettingsStore(defaults: makeDefaults(#function))
        for game in GameID.allCases {
            store.markTutorialSeen(for: game)
        }
        store.resetTutorials()
        for game in GameID.allCases {
            #expect(store.hasSeenTutorial(for: game) == false)
        }
    }
}
