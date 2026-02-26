import Foundation

/// Sensor data from /wusrd endpoint
struct SensorData: Codable, Equatable {
    /// Temperature in Celsius (e.g., 21.5)
    let mstmp: Double
    /// Relative humidity percentage (e.g., 20.7)
    let msrhu: Double
    /// Light level in lux (e.g., 2722.4)
    let mslux: Double
    /// Sound level in dB
    let mssnd: Int

    var temperature: Double { mstmp }
    var humidity: Int { Int(msrhu) }
    var lightLevel: Int { Int(mslux) }
    var soundLevel: Int { mssnd }

    /// Temperature in Fahrenheit
    var temperatureFahrenheit: Double {
        (mstmp * 9.0 / 5.0) + 32.0
    }

    /// Formatted temperature string (Celsius)
    var temperatureString: String {
        String(format: "%.1f°C", mstmp)
    }

    /// Formatted temperature string (Fahrenheit)
    var temperatureFahrenheitString: String {
        String(format: "%.1f°F", temperatureFahrenheit)
    }

    /// Humidity description
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

    /// Light level description
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

    /// Sound level description
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

    static let empty = SensorData(mstmp: 0.0, msrhu: 0.0, mslux: 0.0, mssnd: 0)
}
