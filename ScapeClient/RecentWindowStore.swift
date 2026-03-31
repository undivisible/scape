import Foundation
import MirageKit

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
