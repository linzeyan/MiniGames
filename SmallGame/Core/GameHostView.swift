import SpriteKit
import SwiftUI

/// Hosts a game scene inside SwiftUI: renders the SKScene full-screen and
/// owns the pause / game-over overlays plus high-score persistence, so every
/// game gets identical chrome for free.
struct GameHostView: View {
    let game: GameID
    let makeScene: (CGSize) -> MiniGameScene

    @Environment(\.dismiss) private var dismiss
    @State private var scene: MiniGameScene?
    @State private var isPaused = false
    @State private var finalScore: Int?
    @State private var isNewRecord = false
    @State private var showInstructions: Bool

    private let scores = ScoreStore()
    private let settings = SettingsStore()

    init(game: GameID, makeScene: @escaping (CGSize) -> MiniGameScene) {
        self.game = game
        self.makeScene = makeScene
        // First play per game: explain the controls before anything moves.
        _showInstructions = State(initialValue: !SettingsStore().hasSeenTutorial(for: game))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                SpriteView(scene: hostedScene(size: proxy.size))
                    .ignoresSafeArea()
                    .onChange(of: showInstructions) { syncHold() }
                    .onChange(of: isPaused) { syncHold() }

                overlayControls

                if showInstructions {
                    instructionsOverlay
                }
                if isPaused {
                    pauseOverlay
                }
                if let score = finalScore {
                    gameOverOverlay(score: score)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .statusBarHidden(true)
        .onAppear { AudioManager.shared.playMusic(game.musicTrack) }
        // Back to the calm menu loop; the menu's own onAppear may not fire
        // before this view finishes leaving.
        .onDisappear { AudioManager.shared.playMusic("bgm_menu", volume: 0.22) }
    }

    private func hostedScene(size: CGSize) -> MiniGameScene {
        if let scene { return scene }
        let newScene = makeScene(size)
        newScene.scaleMode = .resizeFill
        newScene.onGameOver = { score in
            isNewRecord = scores.submit(score, for: game)
            finalScore = score
        }
        newScene.isHeld = showInstructions
        // Deferred: mutating @State during view update is invalid.
        Task { @MainActor in scene = newScene }
        return newScene
    }

    private func syncHold() {
        scene?.isHeld = showInstructions || isPaused
    }

    private var instructionsOverlay: some View {
        menuCard {
            Text(game.displayNameKey).font(.title2.bold())
            Text(game.instructionsKey)
                .font(.callout)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: 260)
            Button("common.start") {
                settings.markTutorialSeen(for: game)
                showInstructions = false
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(game.accentColors[1]) // dark label on the white pill
        }
    }

    private var overlayControls: some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    isPaused = true
                } label: {
                    // Fixed 56pt target with an explicit hit shape: the games
                    // react to every stray tap, so a near-miss here reads as
                    // "pause is broken".
                    Image(systemName: "pause.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 56, height: 56)
                        .contentShape(Rectangle())
                }
                .padding(.trailing, 4)
            }
            Spacer()
        }
    }

    private var pauseOverlay: some View {
        menuCard {
            Text("game.paused").font(.title2.bold())
            Button("game.resume") {
                isPaused = false
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(game.accentColors[1]) // dark label on the white pill
            Button("common.back_to_menu") { dismiss() }
        }
    }

    private func gameOverOverlay(score: Int) -> some View {
        menuCard {
            Text("game.over").font(.title2.bold())
            if isNewRecord {
                Text("game.new_record").foregroundStyle(.orange)
            }
            Text("game.score \(score)")
            Text("game.best \(scores.highScore(for: game))")
                .foregroundStyle(.secondary)
            Button("game.restart") {
                finalScore = nil
                isNewRecord = false
                scene?.restart()
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(game.accentColors[1]) // dark label on the white pill
            Button("common.back_to_menu") { dismiss() }
        }
    }

    private func menuCard(@ViewBuilder content: () -> some View) -> some View {
        ZStack {
            // Scrim: dims the frozen scene and swallows touches so taps on
            // the overlay never leak into the game underneath.
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 16) {
                content()
            }
            .padding(32)
            .foregroundStyle(.white)
            .tint(.white)
            .fontDesign(.rounded)
            // The game's own menu-card gradient: a system material sheet read
            // as an iOS alert sitting on top of the game, not part of it.
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient(colors: game.accentColors,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
        }
    }
}
