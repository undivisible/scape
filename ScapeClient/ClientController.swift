import Foundation
import MirageKit
import Combine

@MainActor
final class ClientController: ObservableObject {
    let clientService = MirageClientService()
    private let discovery = MirageDiscovery()
    private var discoveryTimer: Timer?
    
    @Published var availableHosts: [MirageHost] = []
    @Published var connectedHost: MirageHost?
    @Published var availableWindows: [MirageWindow] = []
    @Published var activeStreams: [ClientStreamSession] = []
    @Published var connectionState: MirageClientService.ConnectionState = .disconnected
    @Published var lastErrorMessage: String?
    @Published var statusMessage: String = "Scanning for hosts..."

    init() {
        clientService.delegate = self
        syncClientState()
        setupDiscovery()
    }
    
    private func setupDiscovery() {
        // Poll for host updates since MirageDiscovery is @Observable
        discoveryTimer?.invalidate()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.availableHosts = self?.discovery.discoveredHosts ?? []
            }
        }
        discovery.startDiscovery()
    }
    
    func connect(to host: MirageHost) async throws {
        lastErrorMessage = nil
        statusMessage = "Connecting to \(host.name)..."
        discovery.stopDiscovery()
        connectionState = .connecting
        do {
            try await clientService.connect(to: host)
            connectedHost = host
            syncClientState()
            statusMessage = "Connected to \(host.name). Loading windows..."
            try await clientService.requestWindowList()
        } catch {
            connectedHost = nil
            await clientService.disconnect()
            syncClientState()
            connectionState = .error(error.localizedDescription)
            lastErrorMessage = error.localizedDescription
            statusMessage = "Failed to connect to \(host.name)"
            discovery.startDiscovery()
            throw error
        }
    }

    func disconnect() async {
        await clientService.disconnect()
        connectedHost = nil
        lastErrorMessage = nil
        syncClientState()
        statusMessage = "Scanning for hosts..."
        discovery.startDiscovery()
    }
    
    func startStream(for window: MirageWindow) {
        Task {
            do {
                _ = try await clientService.startViewing(
                    window: window,
                    quality: .high
                )
                syncClientState()
                statusMessage = "Streaming \(window.displayName)"
            } catch {
                lastErrorMessage = error.localizedDescription
                connectionState = .error(error.localizedDescription)
                statusMessage = "Failed to start stream"
                print("Failed to start stream: \(error)")
            }
        }
    }
    
    func stopStream(_ session: ClientStreamSession) {
        Task {
            await clientService.stopViewing(session)
            syncClientState()
            if let connectedHost {
                statusMessage = activeStreams.isEmpty ? "Connected to \(connectedHost.name)" : "Streaming \(activeStreams.count) window(s)"
            }
        }
    }

    private func syncClientState() {
        connectionState = clientService.connectionState
        availableWindows = clientService.availableWindows
        activeStreams = clientService.activeStreams
    }
}

extension ClientController: MirageClientDelegate {
    func clientService(_ service: MirageClientService, didUpdateWindowList windows: [MirageWindow]) {
        availableWindows = windows
        syncClientState()
        if let connectedHost {
            statusMessage = windows.isEmpty ? "Connected to \(connectedHost.name). Waiting for windows..." : "\(windows.count) window(s) available"
        }
    }

    func clientService(_ service: MirageClientService, didDisconnectFromHost reason: String) {
        connectedHost = nil
        lastErrorMessage = reason == "userRequested" ? nil : reason
        syncClientState()
        statusMessage = reason == "userRequested" ? "Scanning for hosts..." : "Disconnected: \(reason)"
        discovery.startDiscovery()
    }

    func clientService(_ service: MirageClientService, didEncounterError error: Error) {
        lastErrorMessage = error.localizedDescription
        syncClientState()
        statusMessage = "Connection error"
    }

    func clientService(_ service: MirageClientService, unlockDidComplete success: Bool, error: String?, canRetry: Bool, retriesRemaining: Int?, retryAfterSeconds: Int?) {
        if !success {
            lastErrorMessage = error
        }
        syncClientState()
    }
}
