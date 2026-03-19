import Foundation
import CoreGraphics
import Observation
import MirageKit

@MainActor
protocol ClientServiceManaging: AnyObject {
    var delegate: MirageClientDelegate? { get set }
    var connectionState: MirageClientService.ConnectionState { get }
    var availableWindows: [MirageWindow] { get }
    var activeStreams: [ClientStreamSession] { get }

    func connect(to host: MirageHost) async throws
    func disconnect() async
    func requestWindowList() async throws
    func startViewing(
        window: MirageWindow,
        quality: MirageQualityPreset,
        expectedPixelSize: CGSize?,
        scaleFactor: CGFloat?,
        displayResolution: CGSize?,
        maxBitrate: Int?,
        keyFrameInterval: Int?,
        keyframeQuality: Float?
    ) async throws -> ClientStreamSession
    func stopViewing(_ session: ClientStreamSession, minimizeWindow: Bool) async
}

@MainActor
protocol DiscoveryManaging: AnyObject {
    var discoveredHosts: [MirageHost] { get }
    func startDiscovery()
    func stopDiscovery()
    func observeDiscoveredHosts(_ onChange: @escaping @MainActor () -> Void)
}

extension MirageClientService: ClientServiceManaging {}

extension MirageDiscovery: DiscoveryManaging {
    func observeDiscoveredHosts(_ onChange: @escaping @MainActor () -> Void) {
        withObservationTracking {
            _ = discoveredHosts
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                onChange()
                self?.observeDiscoveredHosts(onChange)
            }
        }
    }
}

final class ClientSessionStore {
    private let defaults: UserDefaults
    private let lastHostKeyKey: String

    init(defaults: UserDefaults = .standard, lastHostKeyKey: String = "com.scape.lastHostHistoryKey") {
        self.defaults = defaults
        self.lastHostKeyKey = lastHostKeyKey
    }

    var lastHostHistoryKey: String? {
        get { defaults.string(forKey: lastHostKeyKey) }
        set {
            defaults.set(newValue, forKey: lastHostKeyKey)
        }
    }
}

struct RecentWindowStore {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "com.scape.recentWindows") {
        self.defaults = defaults
        self.key = key
    }

    func remember(windowID: WindowID, for hostKey: String) {
        var mapping = loadMapping()
        mapping[hostKey] = windowID
        defaults.set(mapping.mapValues { $0.description }, forKey: key)
    }

    func recentWindowID(for hostKey: String) -> WindowID? {
        loadMapping()[hostKey]
    }

    func orderedWindows(_ windows: [MirageWindow], for hostKey: String) -> [MirageWindow] {
        guard let recentID = recentWindowID(for: hostKey) else {
            return windows.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        }

        return windows.sorted { lhs, rhs in
            if lhs.id == recentID {
                return true
            }
            if rhs.id == recentID {
                return false
            }
            return lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func loadMapping() -> [String: WindowID] {
        guard let raw = defaults.dictionary(forKey: key) else { return [:] }
        var mapping: [String: WindowID] = [:]
        for (hostKey, value) in raw {
            if let string = value as? String, let id = UInt32(string) {
                mapping[hostKey] = id
            } else if let number = value as? NSNumber {
                mapping[hostKey] = WindowID(number.uint32Value)
            }
        }
        return mapping
    }
}
