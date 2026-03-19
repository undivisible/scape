import Foundation
import MirageKit

@MainActor
final class HostController: ObservableObject, MirageHostDelegate {
    struct PendingConnectionApproval: Identifiable {
        let id: UUID
        let deviceInfo: MirageDeviceInfo
        let requestedAt: Date
    }

    private let hostService: any HostServiceManaging
    private let trustedDeviceStore: TrustedDeviceStore

    @Published var status: String = "Initializing..."
    @Published var connectedClients: [MirageConnectedClient] = []
    @Published var pendingConnectionApprovals: [PendingConnectionApproval] = []
    @Published var trustedDeviceIDs: [UUID] = []

    private var serviceStatus: String = "Initializing..."
    private var pendingConnectionHandlers: [UUID: @Sendable (Bool) -> Void] = [:]

    init(
        hostService: any HostServiceManaging = MirageHostService(),
        trustedDeviceStore: TrustedDeviceStore = TrustedDeviceStore(),
        autoStart: Bool = true
    ) {
        self.hostService = hostService
        self.trustedDeviceStore = trustedDeviceStore
        hostService.delegate = self
        refreshTrustedDeviceIDs()
        refreshStatus()

        if autoStart {
            Task {
                try? await self.start()
            }
        }
    }

    func start() async throws {
        serviceStatus = "Starting..."
        refreshStatus()

        do {
            try await hostService.start()
            serviceStatus = "Listening for clients..."
            refreshStatus()
        } catch {
            serviceStatus = "Failed to start"
            refreshStatus()
            throw error
        }
    }

    func approveConnection(_ request: PendingConnectionApproval) {
        guard let completion = pendingConnectionHandlers.removeValue(forKey: request.id) else {
            return
        }

        trustedDeviceStore.trust(deviceID: request.deviceInfo.id)
        refreshTrustedDeviceIDs()
        pendingConnectionApprovals.removeAll { $0.id == request.id }
        completion(true)
        refreshStatus()
    }

    func revokeTrustedDevice(_ deviceID: UUID) {
        trustedDeviceStore.revoke(deviceID: deviceID)
        refreshTrustedDeviceIDs()
    }

    func rejectConnection(_ request: PendingConnectionApproval) {
        guard let completion = pendingConnectionHandlers.removeValue(forKey: request.id) else {
            return
        }

        pendingConnectionApprovals.removeAll { $0.id == request.id }
        completion(false)
        refreshStatus()
    }

    // MARK: - MirageHostDelegate

    func hostService(
        _ service: MirageHostService,
        shouldAcceptConnectionFrom deviceInfo: MirageDeviceInfo,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
        if trustedDeviceStore.isTrusted(deviceID: deviceInfo.id) {
            completion(true)
            return
        }

        let request = PendingConnectionApproval(
            id: deviceInfo.id,
            deviceInfo: deviceInfo,
            requestedAt: Date()
        )

        pendingConnectionHandlers[request.id] = completion
        pendingConnectionApprovals.removeAll { $0.id == request.id }
        pendingConnectionApprovals.append(request)
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, didConnectClient client: MirageConnectedClient) {
        pendingConnectionHandlers.removeValue(forKey: client.id)
        pendingConnectionApprovals.removeAll { $0.id == client.id }
        connectedClients.removeAll { $0.id == client.id }
        connectedClients.append(client)
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, didDisconnectClient client: MirageConnectedClient) {
        if let completion = pendingConnectionHandlers.removeValue(forKey: client.id) {
            pendingConnectionApprovals.removeAll { $0.id == client.id }
            completion(false)
        }
        connectedClients.removeAll { $0.id == client.id }
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, didEncounterError error: Error) {
        serviceStatus = "Error: \(error.localizedDescription)"
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, sessionStateChanged state: HostSessionState) {
        switch state {
        case .active:
            serviceStatus = "Listening for clients..."
        case .screenLocked:
            serviceStatus = "Mac is locked"
        case .loginScreen:
            serviceStatus = "Login screen active"
        case .sleeping:
            serviceStatus = "Mac is sleeping"
        @unknown default:
            serviceStatus = "Session state changed"
        }
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, shouldAllowUnlockFrom client: MirageConnectedClient) -> Bool {
        true
    }

    // MARK: - Status

    private func refreshTrustedDeviceIDs() {
        trustedDeviceIDs = trustedDeviceStore.trustedDeviceIDs()
    }

    private func refreshStatus() {
        if !pendingConnectionApprovals.isEmpty {
            status = pendingConnectionApprovals.count == 1 ? "1 approval pending" : "\(pendingConnectionApprovals.count) approvals pending"
            return
        }

        if connectedClients.isEmpty {
            status = serviceStatus
            return
        }

        if connectedClients.count == 1 {
            status = "Connected to \(connectedClients[0].name)"
        } else {
            status = "Connected to \(connectedClients.count) clients"
        }
    }
}
