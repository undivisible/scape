import MirageKit

@MainActor
protocol HostServiceManaging: AnyObject {
    var delegate: MirageHostDelegate? { get set }
    func start() async throws
}

extension MirageHostService: HostServiceManaging {}
