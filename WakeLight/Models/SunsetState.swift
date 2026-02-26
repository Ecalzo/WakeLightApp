import Foundation
import SwiftUI

/// Available sunset color schemes
enum SunsetColorScheme: Int, CaseIterable, Identifiable {
    case sunnyDay = 0
    case islandRed = 1
    case nordicWhite = 2
    case caribbeanRed = 3

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .sunnyDay: return "Sunny day"
        case .islandRed: return "Island red"
        case .nordicWhite: return "Nordic white"
        case .caribbeanRed: return "Caribbean red"
        }
    }

    /// Color for the preview circle
    var previewColor: Color {
        switch self {
        case .sunnyDay: return Color(red: 1.0, green: 0.85, blue: 0.4)      // Golden yellow
        case .islandRed: return Color(red: 1.0, green: 0.6, blue: 0.3)      // Orange
        case .nordicWhite: return Color(red: 0.9, green: 0.88, blue: 0.75)  // Cream/white
        case .caribbeanRed: return Color(red: 1.0, green: 0.35, blue: 0.2)  // Deep red/orange
        }
    }

    static func from(ctype: Int?) -> SunsetColorScheme {
        guard let ct = ctype, let scheme = SunsetColorScheme(rawValue: ct) else {
            return .sunnyDay
        }
        return scheme
    }
}

/// Available sunset ambient sounds
/// Note: Sunset/dusk mode only supports 2 sounds (Soft Rain, Ocean Waves).
/// These are different from wake-up sounds which have 8 options.
/// See API_REFERENCE.md for details.
enum SunsetSound: String, CaseIterable, Identifiable {
    case off = "Off"
    case softRain = "Soft Rain"
    case oceanWaves = "Ocean Waves"

    var id: String { rawValue }

    /// The sound channel number for API calls (dusk sounds use channels 1-2)
    var channel: String? {
        switch self {
        case .off: return nil
        case .softRain: return "1"
        case .oceanWaves: return "2"
        }
    }

    /// Create from API channel string
    static func from(channel: String?) -> SunsetSound {
        guard let ch = channel else { return .off }
        switch ch {
        case "1": return .softRain
        case "2": return .oceanWaves
        default: return .off
        }
    }
}

/// Sunset/RelaxBreathe state from /wudsk endpoint
struct SunsetState: Codable, Equatable {
    let onoff: Bool      // Is sunset active
    let curve: Int?      // Light curve type
    let durat: Int?      // Duration in minutes
    let ctype: Int?      // Color type
    let sndtp: Int?      // Sound type (0=off, 1=wake-up sounds, 2=FM radio)
    let snddv: String?   // Sound device ("wus" = wake-up sounds, "fmr" = FM radio)
    let sndch: String?   // Sound channel ("1" through "7" for wake-up sounds)
    let sndlv: Int?      // Sound level/volume (1-25)
    let sndss: Int?      // Sound settings

    var isOn: Bool { onoff }
    var duration: Int { durat ?? 20 }

    /// Current sound selection
    /// Note: Check snddv for "dus" (dusk sounds) rather than sndtp
    var sound: SunsetSound {
        guard snddv == "dus" else { return .off }
        return SunsetSound.from(channel: sndch)
    }

    /// Current volume (1-25)
    var volume: Int { sndlv ?? 12 }

    /// Whether any sound is enabled
    var isSoundEnabled: Bool { snddv == "dus" || snddv == "fmr" }

    /// Current color scheme
    var colorScheme: SunsetColorScheme {
        SunsetColorScheme.from(ctype: ctype)
    }

    static let off = SunsetState(
        onoff: false,
        curve: nil,
        durat: 20,
        ctype: nil,
        sndtp: nil,
        snddv: nil,
        sndch: nil,
        sndlv: nil,
        sndss: nil
    )
}
