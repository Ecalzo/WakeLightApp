import Foundation

/// Represents a wake-up light device discovered on the network
struct WakeLightDevice: Codable, Identifiable, Equatable {
    var id: String { ipAddress }
    let ipAddress: String
    let name: String
    let modelNumber: String
    let firmwareVersion: String

    init(ipAddress: String, name: String = "Wake-Up Light", modelNumber: String = "HF367x", firmwareVersion: String = "") {
        self.ipAddress = ipAddress
        self.name = name
        self.modelNumber = modelNumber
        self.firmwareVersion = firmwareVersion
    }
}

/// Response from /device endpoint
struct DeviceInfo: Codable {
    let type: String
    let modelid: String?
    let serial: String?
    let name: String?
    let cppid: String?

    var displayName: String {
        name ?? "Wake-Up Light"
    }

    var isSomneo: Bool {
        type.contains("HF367") || type.contains("Somneo")
    }
}
