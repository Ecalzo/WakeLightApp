import Foundation

/// Alarm schedule from /wualm/aalms endpoint
struct AlarmSchedule: Codable, Identifiable, Equatable {
    let position: Int  // Alarm slot position (1-16)
    let almhr: Int     // Alarm hour (0-23)
    let almmn: Int     // Alarm minute (0-59)
    let daynm: Int     // Day bitmask (bit 0 = Monday, bit 6 = Sunday, 254 = daily, 0 = once)
    let almvs: Int?    // Alarm version/type

    var id: Int { position }

    var hour: Int { almhr }
    var minute: Int { almmn }

    var timeString: String {
        String(format: "%02d:%02d", almhr, almmn)
    }

    var time12Hour: String {
        let hour12 = almhr == 0 ? 12 : (almhr > 12 ? almhr - 12 : almhr)
        let ampm = almhr < 12 ? "AM" : "PM"
        return String(format: "%d:%02d %@", hour12, almmn, ampm)
    }

    /// Days of week as array of weekday indices (1=Monday, 7=Sunday)
    var activeDays: [Int] {
        var days: [Int] = []
        for i in 0..<7 {
            if (daynm >> i) & 1 == 1 {
                days.append(i + 1)
            }
        }
        return days
    }

    var daysDescription: String {
        if daynm == 0 {
            return "Once"
        } else if daynm == 254 || daynm == 127 {
            return "Daily"
        } else if daynm == 62 {
            return "Weekdays"
        } else if daynm == 192 || daynm == 65 {
            return "Weekends"
        } else {
            let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
            return activeDays.map { dayLetters[$0 - 1] }.joined(separator: " ")
        }
    }

    static func dayMask(for days: [Int]) -> Int {
        var mask = 0
        for day in days {
            mask |= (1 << (day - 1))
        }
        return mask
    }
}

/// Alarm state/environment from /wualm/aenvs endpoint
struct AlarmState: Codable, Identifiable, Equatable {
    let position: Int  // Matches AlarmSchedule position
    let prfen: Bool    // Alarm enabled
    let prfvs: Int?    // Profile version
    let pwrsv: Int?    // Power save setting
    let pswhr: Int?    // Snooze hour
    let pswmn: Int?    // Snooze minute
    let ctype: Int?    // Color type
    let curve: Int?    // Light curve
    let dtefm: Int?    // Date format
    let spts: Int?     // Settings

    var id: Int { position }
    var isEnabled: Bool { prfen }
}

/// Combined alarm info for display
struct Alarm: Identifiable, Equatable {
    let schedule: AlarmSchedule
    var state: AlarmState?

    var id: Int { schedule.id }
    var position: Int { schedule.position }
    var hour: Int { schedule.hour }
    var minute: Int { schedule.minute }
    var timeString: String { schedule.timeString }
    var time12Hour: String { schedule.time12Hour }
    var daysDescription: String { schedule.daysDescription }
    var isEnabled: Bool { state?.isEnabled ?? false }
    var activeDays: [Int] { schedule.activeDays }
    var dayMask: Int { schedule.daynm }

    /// Returns a copy of this alarm with the enabled state changed
    func withEnabled(_ enabled: Bool) -> Alarm {
        var newAlarm = self
        if let currentState = state {
            newAlarm.state = AlarmState(
                position: currentState.position,
                prfen: enabled,
                prfvs: currentState.prfvs,
                pwrsv: currentState.pwrsv,
                pswhr: currentState.pswhr,
                pswmn: currentState.pswmn,
                ctype: currentState.ctype,
                curve: currentState.curve,
                dtefm: currentState.dtefm,
                spts: currentState.spts
            )
        }
        return newAlarm
    }
}

/// Response wrapper for alarm schedules (legacy format)
struct AlarmsResponse: Codable {
    let aalms: [AlarmSchedule]?
}

/// Response wrapper for alarm states (legacy format)
struct AlarmStatesResponse: Codable {
    let aenvs: [AlarmState]?
}

/// Response format where each field is an array of values (actual API format)
struct AlarmsArrayResponse: Codable {
    let daynm: [Int]
    let almhr: [Int]
    let almmn: [Int]
}

/// Response format for alarm states with arrays (actual API format)
struct AlarmStatesArrayResponse: Codable {
    let prfen: [Bool]
    let prfvs: [Bool]?
}

/// Request to update alarm enabled state
struct AlarmEnableRequest: Codable {
    let prfen: Bool
}

/// Request to configure wake-up alarm
struct AlarmConfigRequest: Codable {
    var prfnr: Int     // Profile/alarm number (1-16)
    var prfen: Bool    // Enabled
    var almhr: Int     // Hour
    var almmn: Int     // Minute
    var daynm: Int?     // Day mask
    var curve: Int?    // Light curve type
    var dtefm: Int?    // Date format
    var snzvs: Int?    // Snooze
    var spts: Int?     // Sunset
}
