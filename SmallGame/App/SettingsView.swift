import SwiftUI

/// Settings sheet: audio, feedback, control style, iCloud sync, and the
/// housekeeping actions (replay tutorials, clear records).
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let settings = SettingsStore()

    @State private var isMusicEnabled = SettingsStore().isMusicEnabled
    @State private var isSoundEffectsEnabled = SettingsStore().isSoundEffectsEnabled
    @State private var isHapticsEnabled = SettingsStore().isHapticsEnabled
    @State private var isCloudSyncEnabled = SettingsStore().isCloudSyncEnabled
    @State private var usesDigitalControl = SettingsStore().usesDigitalControl
    @State private var language = SettingsStore().language
    @State private var isConfirmingScoreReset = false
    @State private var didResetTutorials = false
    @State private var isShowingRestartNotice = false

    /// The language this process actually launched with. The picker is the only
    /// way to change it and it lives here, so first evaluation always happens
    /// before any change — a later pick that differs from this needs a restart.
    private static let launchLanguage = SettingsStore().language

    var body: some View {
        NavigationStack {
            Form {
                audioSection
                controlSection
                syncSection
                generalSection
            }
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var audioSection: some View {
        Section("settings.section.audio") {
            Toggle("settings.music", isOn: $isMusicEnabled)
                .onChange(of: isMusicEnabled) { AudioManager.shared.isMusicEnabled = isMusicEnabled }
            Toggle("settings.sfx", isOn: $isSoundEffectsEnabled)
                .onChange(of: isSoundEffectsEnabled) {
                    AudioManager.shared.isSoundEffectsEnabled = isSoundEffectsEnabled
                }
            Toggle("settings.haptics", isOn: $isHapticsEnabled)
                .onChange(of: isHapticsEnabled) { settings.isHapticsEnabled = isHapticsEnabled }
        }
    }

    private var controlSection: some View {
        Section {
            Toggle("settings.digital_control", isOn: $usesDigitalControl)
                .onChange(of: usesDigitalControl) { settings.usesDigitalControl = usesDigitalControl }
        } header: {
            Text("settings.section.gameplay")
        } footer: {
            Text("settings.digital_control.note")
        }
    }

    private var syncSection: some View {
        Section {
            Toggle("settings.icloud", isOn: $isCloudSyncEnabled)
                .onChange(of: isCloudSyncEnabled) { settings.isCloudSyncEnabled = isCloudSyncEnabled }
        } header: {
            Text("settings.section.sync")
        } footer: {
            Text("settings.icloud.note")
        }
    }

    private var generalSection: some View {
        Section {
            Picker("settings.language", selection: $language) {
                ForEach(SettingsStore.AppLanguage.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .onChange(of: language) {
                settings.language = language
                // Picking the launch language back is a no-op, not a pending change.
                isShowingRestartNotice = language != Self.launchLanguage
            }
            Button(didResetTutorials ? "settings.tutorials_reset" : "settings.reset_tutorials") {
                settings.resetTutorials()
                didResetTutorials = true
            }
            .disabled(didResetTutorials)
            Button("settings.reset_scores", role: .destructive) {
                isConfirmingScoreReset = true
            }
            LabeledContent("settings.version", value: Self.versionText)
        } header: {
            Text("settings.section.general")
        } footer: {
            Text("settings.language.note")
        }
        .confirmationDialog("settings.reset_scores.confirm",
                            isPresented: $isConfirmingScoreReset, titleVisibility: .visible) {
            Button("settings.reset_scores", role: .destructive) { ScoreStore().resetAll() }
            Button("common.cancel", role: .cancel) {}
        }
        // iOS has no sanctioned way to relaunch itself — `exit(0)` violates the
        // HIG and gets apps rejected — so the honest option is to tell the
        // player the change is queued and let them restart.
        .alert("settings.language.restart_title", isPresented: $isShowingRestartNotice) {
            Button("common.ok") {}
        } message: {
            Text("settings.language.restart_message")
        }
    }

    private static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
}
