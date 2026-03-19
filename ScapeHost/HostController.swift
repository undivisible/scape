import Foundation
import MirageKit
import ScreenCaptureKit

@MainActor
final class HostController: ObservableObject, MirageHostDelegate {
    struct PendingConnectionApproval: Identifiable {
        let id: UUID
        let deviceInfo: MirageDeviceInfo
        let requestedAt: Date
    }

    struct PendingStreamApproval: Identifiable {
        let id: UUID
        let client: MirageConnectedClient
        let window: MirageWindow
        let requestedAt: Date
    }

    private let hostService = MirageHostService()

    @Published var status: String = "Initializing..."
    @Published var connectedClients: [MirageConnectedClient] = []
    @Published var pendingConnectionApprovals: [PendingConnectionApproval] = []
    @Published var pendingStreamApprovals: [PendingStreamApproval] = []

    private var serviceStatus: String = "Initializing..."
    private var pendingConnectionHandlers: [UUID: @Sendable (Bool) -> Void] = [:]
    private var pendingStreamDecisions: [UUID: Bool] = [:]

    init() {
        hostService.delegate = self
        refreshStatus()

        Task {
            try? await self.start()
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

        pendingConnectionApprovals.removeAll { $0.id == request.id }
        completion(true)
        refreshStatus()
    }

    func rejectConnection(_ request: PendingConnectionApproval) {
        guard let completion = pendingConnectionHandlers.removeValue(forKey: request.id) else {
            return
        }

        pendingConnectionApprovals.removeAll { $0.id == request.id }
        completion(false)
        refreshStatus()
    }

    func approveStream(_ request: PendingStreamApproval) {
        pendingStreamDecisions[request.id] = true
        pendingStreamApprovals.removeAll { $0.id == request.id }
        refreshStatus()
    }

    func rejectStream(_ request: PendingStreamApproval) {
        pendingStreamDecisions[request.id] = false
        pendingStreamApprovals.removeAll { $0.id == request.id }
        refreshStatus()
    }

    // MARK: - MirageHostDelegate

    func hostService(
        _ service: MirageHostService,
        shouldAcceptConnectionFrom deviceInfo: MirageDeviceInfo,
        completion: @escaping @Sendable (Bool) -> Void
    ) {
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

        for request in pendingStreamApprovals where request.client.id == client.id {
            pendingStreamDecisions[request.id] = false
        }
        pendingStreamApprovals.removeAll { $0.client.id == client.id }
        connectedClients.removeAll { $0.id == client.id }
        refreshStatus()
    }

    func hostService(_ service: MirageHostService, shouldAllowClient client: MirageConnectedClient, toStreamWindow window: MirageWindow) -> Bool {
        let request = PendingStreamApproval(
            id: UUID(),
            client: client,
            window: window,
            requestedAt: Date()
        )

        pendingStreamApprovals.append(request)
        refreshStatus()

        defer {
            pendingStreamDecisions.removeValue(forKey: request.id)
            pendingStreamApprovals.removeAll { $0.id == request.id }
            refreshStatus()
        }

        while true {
            if let decision = pendingStreamDecisions[request.id] {
                return decision
            }

            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }
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

    private func refreshStatus() {
        let pendingCount = pendingConnectionApprovals.count + pendingStreamApprovals.count
        if pendingCount > 0 {
            status = pendingCount == 1 ? "1 approval pending" : "\(pendingCount) approvals pending"
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
