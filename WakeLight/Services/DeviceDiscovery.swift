import Foundation
import Network

/// Service for discovering wake-up light devices on the local network
actor DeviceDiscovery {
    static let shared = DeviceDiscovery()

    private let session: URLSession
    private let timeout: TimeInterval = 2.0

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: config, delegate: InsecureURLSessionDelegate(), delegateQueue: nil)
    }

    /// Discover wake-up light device on the network by scanning subnet
    func discoverDevice() async -> WakeLightDevice? {
        guard let subnet = getLocalSubnet() else {
            print("Could not determine local subnet")
            return nil
        }

        print("Scanning subnet: \(subnet).x")

        return await withTaskGroup(of: WakeLightDevice?.self) { group in
            // Scan all IPs in parallel
            for i in 1...254 {
                group.addTask {
                    let ip = "\(subnet).\(i)"
                    return await self.probeDevice(ip: ip)
                }
            }

            // Return first successful result
            for await result in group {
                if let device = result {
                    group.cancelAll()
                    return device
                }
            }
            return nil
        }
    }

    /// Probe a specific IP to check if it's a wake-up light device
    func probeDevice(ip: String) async -> WakeLightDevice? {
        let url = URL(string: "https://\(ip)/di/v1/products/1/device")!

        do {
            let (data, _) = try await session.data(from: url)
            let device = try JSONDecoder().decode(DeviceInfo.self, from: data)

            if device.isSomneo {
                print("Found wake-up light at \(ip): \(device.type)")
                return WakeLightDevice(
                    ipAddress: ip,
                    name: device.displayName,
                    modelNumber: device.type,
                    firmwareVersion: device.modelid ?? ""
                )
            }
        } catch {
            // Expected for most IPs - they're not wake-up light devices
        }

        return nil
    }

    /// Verify a specific IP is a wake-up light device
    func verifyDevice(ip: String) async -> WakeLightDevice? {
        await probeDevice(ip: ip)
    }

    /// Triggers the local network permission dialog by making a network request.
    /// Call this early in the app lifecycle to prompt the user for permission.
    func requestNetworkAccess() async {
        // Make a simple request to a local IP to trigger the permission dialog
        // This will fail, but that's fine - we just need to trigger the permission
        guard let subnet = getLocalSubnet() else { return }
        let url = URL(string: "https://\(subnet).1/")!
        _ = try? await session.data(from: url)
    }

    /// Get the local network subnet (e.g., "192.168.1")
    private func getLocalSubnet() -> String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Look for IPv4 interfaces
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Skip loopback interface
                if name == "lo0" { continue }

                // Prefer en0 (WiFi) or en1
                if name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        0,
                        NI_NUMERICHOST
                    )
                    let ip = String(cString: hostname)

                    // Extract subnet (first 3 octets)
                    let components = ip.split(separator: ".")
                    if components.count == 4 {
                        address = components.prefix(3).joined(separator: ".")
                        break
                    }
                }
            }
        }

        return address
    }
}

// MARK: - Discovery State

enum DiscoveryState: Equatable {
    case idle
    case discovering
    case found(WakeLightDevice)
    case notFound
    case error(String)

    var isDiscovering: Bool {
        if case .discovering = self { return true }
        return false
    }

    var device: WakeLightDevice? {
        if case .found(let device) = self { return device }
        return nil
    }
}
