import Foundation

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
