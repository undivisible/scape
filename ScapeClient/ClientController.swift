import Foundation
import MirageKit
import Combine

@MainActor
final class ClientController: ObservableObject {
    let clientService = MirageClientService()
    private let discovery = MirageDiscovery()
    
    @Published var availableHosts: [MirageHost] = []
    @Published var connectedHost: MirageHost?
    
    var availableWindows: [MirageWindow] {
        clientService.availableWindows
    }
    
    var activeStreams: [ClientStreamSession] {
        clientService.activeStreams
    }
    
    init() {
        setupDiscovery()
    }
    
    private func setupDiscovery() {
        // Poll for host updates since MirageDiscovery is @Observable
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.availableHosts = self?.discovery.discoveredHosts ?? []
            }
        }
        discovery.startDiscovery()
    }
    
    func connect(to host: MirageHost) async throws {
        discovery.stopDiscovery()
        try await clientService.connect(to: host)
        connectedHost = host
        try await clientService.requestWindowList()
    }
    
    func startStream(for window: MirageWindow) {
        Task {
            do {
                _ = try await clientService.startViewing(
                    window: window,
                    quality: .high
                )
            } catch {
                print("Failed to start stream: \(error)")
            }
        }
    }
    
    func stopStream(_ session: ClientStreamSession) {
        Task {
            await clientService.stopViewing(session)
        }
    }
}
