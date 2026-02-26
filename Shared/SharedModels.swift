import Foundation
import SwiftUI

/// Light state from /wulgt endpoint - Shared between app and widgets
struct LightState: Codable, Equatable {
    let onoff: Bool
    let ltlvl: Int
    let tempy: Bool?
    let ngtlt: Bool?

    var isOn: Bool { onoff }
    var brightness: Int { ltlvl }
}

/// Sensor data from /wusrd endpoint - Shared between app and widgets
struct SensorData: Codable, Equatable {
    let mstmp: Double
    let msrhu: Double
    let mslux: Double
    let mssnd: Int

    var temperature: Double { mstmp }
    var humidity: Int { Int(msrhu) }
    var lightLevel: Int { Int(mslux) }
    var soundLevel: Int { mssnd }

    var temperatureFahrenheit: Double {
        (mstmp * 9.0 / 5.0) + 32.0
    }

    var temperatureString: String {
        String(format: "%.1f°C", mstmp)
    }

    var temperatureFahrenheitString: String {
        String(format: "%.1f°F", temperatureFahrenheit)
    }

    var humidityDescription: String {
        if msrhu < 30 {
            return "Low"
        } else if msrhu < 50 {
            return "Optimal"
        } else if msrhu < 70 {
            return "Comfortable"
        } else {
            return "High"
        }
    }

    var lightDescription: String {
        if mslux < 1 {
            return "Dark"
        } else if mslux < 50 {
            return "Dim"
        } else if mslux < 200 {
            return "Moderate"
        } else if mslux < 500 {
            return "Bright"
        } else {
            return "Very Bright"
        }
    }

    var soundDescription: String {
        if mssnd < 30 {
            return "Quiet"
        } else if mssnd < 50 {
            return "Moderate"
        } else if mssnd < 70 {
            return "Loud"
        } else {
            return "Very Loud"
        }
    }
}

/// Alarm schedule - Shared between app and widgets
struct AlarmSchedule: Codable, Identifiable, Equatable {
    let position: Int
    let almhr: Int
    let almmn: Int
    let daynm: Int
    let almvs: Int?

    var id: Int { position }

    var time12Hour: String {
        let hour12 = almhr == 0 ? 12 : (almhr > 12 ? almhr - 12 : almhr)
        let ampm = almhr < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour12, almmn, ampm)
    }

    var daysDescription: String {
        if daynm == 0 { return "Once" }
        else if daynm == 254 || daynm == 127 { return "Daily" }
        else if daynm == 62 { return "Weekdays" }
        else if daynm == 192 || daynm == 65 { return "Weekends" }
        else { return "Custom" }
    }
}

/// Alarm state - Shared between app and widgets
struct AlarmState: Codable, Identifiable, Equatable {
    let position: Int
    let prfen: Bool
    let prfvs: Int?
    let pwrsv: Int?
    let pswhr: Int?
    let pswmn: Int?
    let ctype: Int?
    let curve: Int?
    let dtefm: Int?
    let spts: Int?

    var id: Int { position }
    var isEnabled: Bool { prfen }
}

/// Combined alarm info
struct Alarm: Identifiable, Equatable {
    let schedule: AlarmSchedule
    let state: AlarmState?

    var id: Int { schedule.id }
    var hour: Int { schedule.almhr }
    var minute: Int { schedule.almmn }
    var time12Hour: String { schedule.time12Hour }
    var daysDescription: String { schedule.daysDescription }
    var isEnabled: Bool { state?.isEnabled ?? false }
}

/// Simplified sunset state for Watch app - Shared between app and widgets
struct SimpleSunsetState: Codable, Equatable {
    let onoff: Bool
    let durat: Int?

    var isOn: Bool { onoff }
    var duration: Int { durat ?? 20 }

    static let off = SimpleSunsetState(onoff: false, durat: 20)
}

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
        case .sunnyDay: return Color(red: 1.0, green: 0.85, blue: 0.4)
        case .islandRed: return Color(red: 1.0, green: 0.6, blue: 0.3)
        case .nordicWhite: return Color(red: 0.9, green: 0.88, blue: 0.75)
        case .caribbeanRed: return Color(red: 1.0, green: 0.35, blue: 0.2)
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
