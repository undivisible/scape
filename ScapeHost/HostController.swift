import Foundation
import MirageKit
import ScreenCaptureKit

@MainActor
final class HostController: ObservableObject, MirageHostDelegate {
    private let hostService = MirageHostService()
    
    @Published var status: String = "Initializing..."
    @Published var connectedClients: [MirageConnectedClient] = []
    
    init() {
        hostService.delegate = self
        Task {
            try? await self.start()
        }
    }
    
    func start() async throws {
        status = "Starting..."
        try await hostService.start()
        status = "Listening for clients..."
    }
    
    // MARK: - MirageHostDelegate
    
    func hostService(_ service: MirageHostService, shouldAllowClient client: MirageConnectedClient, toStreamWindow window: MirageWindow) -> Bool {
        // Auto-approve for now. In production, show a dialog.
        print("Client requested stream: \(client.name)")
        return true
    }
    
    func hostService(_ service: MirageHostService, didAcceptClient client: MirageConnectedClient) {
        print("Client connected: \(client.name)")
        status = "Connected to \(client.name)"
        connectedClients.append(client)
    }
    
    func hostService(_ service: MirageHostService, clientDidDisconnect client: MirageConnectedClient) {
        print("Client disconnected: \(client.name)")
        connectedClients.removeAll { $0.id == client.id }
        if connectedClients.isEmpty {
            status = "Listening for clients..."
        } else {
            status = "Connected to \(connectedClients.count) client(s)"
        }
    }
}
