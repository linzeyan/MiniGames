import Foundation

/// Stable identifiers for the four mini games.
/// Raw values are persisted as UserDefaults keys (and later Game Center
/// leaderboard IDs), so they must never change.
enum GameID: String, CaseIterable, Identifiable {
    case tower
    case shaft
    case fishing
    case snowball

    var id: String { rawValue }

    /// Localized display name, resolved from Localizable.xcstrings.
    var displayNameKey: LocalizedStringResource {
        switch self {
        case .tower: LocalizedStringResource("game.tower.name")
        case .shaft: LocalizedStringResource("game.shaft.name")
        case .fishing: LocalizedStringResource("game.fishing.name")
        case .snowball: LocalizedStringResource("game.snowball.name")
        }
    }

    /// Looping BGM for this game — tighter and faster than the menu track,
    /// so entering a game is audibly a change of gear.
    var musicTrack: String {
        switch self {
        case .tower: "bgm_tower"
        case .shaft: "bgm_shaft"
        case .fishing: "bgm_fishing"
        case .snowball: "bgm_snowball"
        }
    }

    /// First-play how-to text shown by GameHostView.
    var instructionsKey: LocalizedStringResource {
        switch self {
        case .tower: LocalizedStringResource("instructions.tower")
        case .shaft: LocalizedStringResource("instructions.shaft")
        case .fishing: LocalizedStringResource("instructions.fishing")
        case .snowball: LocalizedStringResource("instructions.snowball")
        }
    }
}
