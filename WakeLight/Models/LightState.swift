import Foundation

/// Light state from /wulgt endpoint
struct LightState: Codable, Equatable {
    /// Light on/off state
    let onoff: Bool
    /// Light level (1-25)
    let ltlvl: Int
    /// Temperature mode (warm white vs cool)
    let tempy: Bool?
    /// Night light on/off
    let ngtlt: Bool?

    var isOn: Bool { onoff }
    var brightness: Int { ltlvl }
    var isWarmWhite: Bool { tempy ?? false }
    var isNightLightOn: Bool { ngtlt ?? false }

    /// Brightness as percentage (0-100)
    var brightnessPercent: Double {
        Double(ltlvl - 1) / 24.0 * 100.0
    }

    static let off = LightState(onoff: false, ltlvl: 1, tempy: false, ngtlt: false)
}

/// Request payload for setting light state
struct LightRequest: Codable {
    var onoff: Bool?
    var ltlvl: Int?
    var tempy: Bool?
    var ngtlt: Bool?

    /// Initialize light request. Note: `tempy` must be explicitly set to `false` when controlling
    /// the light to prevent the device from interpreting it as a sunrise preview.
    init(on: Bool? = nil, brightness: Int? = nil, nightLight: Bool? = nil) {
        self.onoff = on
        self.ltlvl = brightness
        self.tempy = false  // Always false to prevent sunrise preview
        self.ngtlt = nightLight
    }
}
