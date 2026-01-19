import Foundation
import MirageKit
import ScreenCaptureKit

@MainActor
final class HostController: ObservableObject, MirageHostDelegate {
    private let hostService = MirageHostService()
    
    @Published var status: String = "Initializing..."
    
    init() {
        hostService.delegate = self
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
    }
    
    func hostService(_ service: MirageHostService, clientDidDisconnect client: MirageConnectedClient) {
        print("Client disconnected: \(client.name)")
        status = "Listening for clients..."
    }
}
