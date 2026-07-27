import AVFoundation
import Foundation

/// Plays the looping chiptune BGM and short sound effects from the app
/// bundle, and owns the mute setting.
final class AudioManager {
    static let shared = AudioManager()

    private var players: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?
    private var currentMusic: (name: String, volume: Float)?
    private let settings: SettingsStore

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        // Ambient: respects the silent switch and mixes with other audio.
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    /// Music and effects are separate switches: players often want the
    /// gameplay cues without a soundtrack over their own music.
    var isMusicEnabled: Bool {
        get { settings.isMusicEnabled }
        set {
            settings.isMusicEnabled = newValue
            if newValue {
                if let currentMusic { playMusic(currentMusic.name, volume: currentMusic.volume) }
            } else {
                musicPlayer?.pause()
            }
        }
    }

    var isSoundEffectsEnabled: Bool {
        get { settings.isSoundEffectsEnabled }
        set { settings.isSoundEffectsEnabled = newValue }
    }

    /// Starts (or resumes) a looping music track. Calling again with the
    /// track that is already playing is a no-op, so screens can all declare
    /// the BGM they want without restarting it.
    func playMusic(_ name: String, volume: Float = 0.3) {
        currentMusic = (name, volume)
        guard isMusicEnabled else { return }
        if let musicPlayer, musicPlayer.url?.lastPathComponent == "\(name).wav" {
            musicPlayer.volume = volume
            if !musicPlayer.isPlaying { musicPlayer.play() }
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            print("AudioManager: missing music '\(name).wav'")
            return
        }
        musicPlayer?.stop()
        player.numberOfLoops = -1
        player.volume = volume
        player.play()
        musicPlayer = player
    }

    /// Plays a bundled effect, caching the player per file. Missing files are
    /// logged instead of crashing so placeholder builds stay runnable.
    func play(_ name: String, ext: String = "wav") {
        guard isSoundEffectsEnabled else { return }
        if let cached = players[name] {
            cached.currentTime = 0
            cached.play()
            return
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            print("AudioManager: missing sound '\(name).\(ext)'")
            return
        }
        players[name] = player
        player.play()
    }
}
