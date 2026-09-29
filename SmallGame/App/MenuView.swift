import SwiftUI

/// Hub screen: pick a game from the card grid, see your best score,
/// toggle sound. Starts the chiptune BGM.
struct MenuView: View {
    private let scores = ScoreStore()
    @State private var isShowingSettings = false
    @State private var path: [GameID] = []

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.09, green: 0.12, blue: 0.22),
                                        Color(red: 0.17, green: 0.24, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 28) {
                        header
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(GameID.allCases) { game in
                                NavigationLink(value: game) {
                                    GameCard(game: game, best: scores.highScore(for: game))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: GameID.self) { game in
                GameHostView(game: game, makeScene: Self.sceneFactory(for: game))
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .onAppear {
                SettingsStore().migrateLegacyMuteIfNeeded()
                // Soft and slow here; each game switches to its own tighter
                // track on entry.
                AudioManager.shared.playMusic("bgm_menu", volume: 0.22)
                // Debug/automation hook: `simctl launch ... -showSettings YES`
                // opens the sheet for screenshot verification.
                if UserDefaults.standard.bool(forKey: "showSettings") {
                    isShowingSettings = true
                }
                // Debug/automation hook: `simctl launch ... -autoplay shaft`
                // jumps straight into a game for screenshot verification.
                if path.isEmpty,
                   let raw = UserDefaults.standard.string(forKey: "autoplay"),
                   let game = GameID(rawValue: raw) {
                    path.append(game)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Spacer()
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("settings.title")
        }
        .padding(.top, 12)
    }

    static func sceneFactory(for game: GameID) -> (CGSize) -> MiniGameScene {
        { size in
            switch game {
            case .tower: TowerScene(size: size)
            case .shaft: ShaftScene(size: size)
            case .fishing: FishingScene(size: size)
            case .snowball: SnowballScene(size: size)
            case .defense: DefenseScene(size: size)
            case .swarm: SwarmScene(size: size)
            }
        }
    }
}

/// One tappable game tile: sprite, name, and personal best.
private struct GameCard: View {
    let game: GameID
    let best: Int

    var body: some View {
        VStack(spacing: 12) {
            // UIImage(named:) resolves loose bundle PNGs (the SpriteKit
            // textures); SwiftUI's Image(_:) only searches asset catalogs.
            Image(uiImage: UIImage(named: game.menuSprite) ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(height: 56)
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
            Text(game.displayNameKey)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.white)
            Text("menu.best \(best)")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
        // The game's own backdrop previews the scene. Top-aligned: backdrops
        // keep their centers empty for gameplay, so the moon / cave mouth /
        // water surface / tree line all sit at the top. The accent wash plus
        // the text shadow keep white text legible on the pale snow art.
        .background(alignment: .top) {
            Image(uiImage: UIImage(named: game.backdrop) ?? UIImage())
                .resizable()
                .scaledToFill()
                .overlay(LinearGradient(colors: game.accentColors.map { $0.opacity(0.7) },
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

extension GameID {
    /// Bundled sprite shown on the menu card.
    var menuSprite: String {
        switch self {
        case .tower: "player_jump"
        case .shaft: "tile_spikes"
        case .fishing: "octopus"
        case .snowball: "enemy_stand"
        case .defense: "def_slingshot"
        case .swarm: "item_swatter"
        }
    }

    /// Scene backdrop reused as the card art (fishing shows its water half).
    var backdrop: String {
        switch self {
        case .tower: "bg_tower.jpg"
        case .shaft: "bg_shaft.jpg"
        case .fishing: "bg_fishing_water.jpg"
        case .snowball: "bg_snowball.jpg"
        case .defense: "bg_defense.jpg"
        case .swarm: "bg_swarm.jpg"
        }
    }

    /// Card gradient echoing each game's scene palette.
    var accentColors: [Color] {
        switch self {
        case .tower: [Color(red: 0.32, green: 0.28, blue: 0.62), Color(red: 0.2, green: 0.16, blue: 0.42)]
        case .shaft: [Color(red: 0.3, green: 0.52, blue: 0.32), Color(red: 0.16, green: 0.36, blue: 0.2)]
        case .fishing: [Color(red: 0.2, green: 0.48, blue: 0.72), Color(red: 0.1, green: 0.28, blue: 0.5)]
        case .snowball: [Color(red: 0.45, green: 0.58, blue: 0.74), Color(red: 0.28, green: 0.4, blue: 0.58)]
        case .defense: [Color(red: 0.42, green: 0.6, blue: 0.28), Color(red: 0.24, green: 0.4, blue: 0.16)]
        case .swarm: [Color(red: 0.3, green: 0.36, blue: 0.5), Color(red: 0.14, green: 0.2, blue: 0.3)]
        }
    }
}

#Preview {
    MenuView()
}
