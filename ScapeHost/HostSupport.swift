import Foundation
import MirageKit

@MainActor
protocol HostServiceManaging: AnyObject {
    var delegate: MirageHostDelegate? { get set }
    func start() async throws
}

extension MirageHostService: HostServiceManaging {}

final class TrustedDeviceStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "com.scape.trustedDevices") {
        self.defaults = defaults
        self.key = key
    }

    func isTrusted(deviceID: UUID) -> Bool {
        loadTrustedDeviceIDs().contains(deviceID)
    }

    func trust(deviceID: UUID) {
        var trusted = loadTrustedDeviceIDs()
        guard !trusted.contains(deviceID) else { return }
        trusted.append(deviceID)
        defaults.set(trusted.map(\.uuidString), forKey: key)
    }

    func revoke(deviceID: UUID) {
        let trusted = loadTrustedDeviceIDs().filter { $0 != deviceID }
        defaults.set(trusted.map(\.uuidString), forKey: key)
    }

    func trustedDeviceIDs() -> [UUID] {
        loadTrustedDeviceIDs()
    }

    private func loadTrustedDeviceIDs() -> [UUID] {
        (defaults.stringArray(forKey: key) ?? []).compactMap(UUID.init(uuidString:))
    }
}
