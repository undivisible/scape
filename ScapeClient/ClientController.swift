import Foundation
import MirageKit
import Combine

@MainActor
final class ClientController: ObservableObject {
    let clientService: any ClientServiceManaging
    private let discovery: any DiscoveryManaging
    private let recentWindowStore: RecentWindowStore
    private var discoveryTimer: Timer?
    private var currentHostHistoryKey: String?
    
    @Published var availableHosts: [MirageHost] = []
    @Published var connectedHost: MirageHost?
    @Published var availableWindows: [MirageWindow] = []
    @Published var activeStreams: [ClientStreamSession] = []
    @Published var connectionState: MirageClientService.ConnectionState = .disconnected
    @Published var lastErrorMessage: String?
    @Published var statusMessage: String = "Scanning for hosts..."

    init(
        clientService: any ClientServiceManaging = MirageClientService(),
        discovery: any DiscoveryManaging = MirageDiscovery(),
        recentWindowStore: RecentWindowStore = RecentWindowStore(),
        autoStartDiscovery: Bool = true
    ) {
        self.clientService = clientService
        self.discovery = discovery
        self.recentWindowStore = recentWindowStore
        clientService.delegate = self
        syncClientState()
        if autoStartDiscovery {
            setupDiscovery()
        }
    }
    
    private func setupDiscovery() {
        // Poll for host updates since MirageDiscovery is @Observable
        discoveryTimer?.invalidate()
        discoveryTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDiscoveryHosts()
            }
        }
        refreshDiscoveryHosts()
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
            currentHostHistoryKey = hostHistoryKey(for: host)
            syncClientState()
            statusMessage = "Connected to \(host.name). Loading windows..."
            try await clientService.requestWindowList()
        } catch {
            connectedHost = nil
            currentHostHistoryKey = nil
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
        currentHostHistoryKey = nil
        lastErrorMessage = nil
        syncClientState()
        statusMessage = "Scanning for hosts..."
        discovery.startDiscovery()
    }
    
    func startStream(for window: MirageWindow) {
        Task { @MainActor in
            do {
                _ = try await clientService.startViewing(
                    window: window,
                    quality: .high,
                    expectedPixelSize: nil,
                    scaleFactor: nil,
                    displayResolution: nil,
                    maxBitrate: nil,
                    keyFrameInterval: nil,
                    keyframeQuality: nil
                )
                if let currentHostHistoryKey {
                    recentWindowStore.remember(windowID: window.id, for: currentHostHistoryKey)
                    availableWindows = recentWindowStore.orderedWindows(availableWindows, for: currentHostHistoryKey)
                }
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
        Task { @MainActor in
            await clientService.stopViewing(session, minimizeWindow: false)
            syncClientState()
            if let connectedHost {
                statusMessage = activeStreams.isEmpty ? "Connected to \(connectedHost.name)" : "Streaming \(activeStreams.count) window(s)"
            }
        }
    }

    private func syncClientState() {
        connectionState = clientService.connectionState
        if let currentHostHistoryKey {
            availableWindows = recentWindowStore.orderedWindows(clientService.availableWindows, for: currentHostHistoryKey)
        } else {
            availableWindows = clientService.availableWindows
        }
        activeStreams = clientService.activeStreams
    }

    private func refreshDiscoveryHosts() {
        availableHosts = discovery.discoveredHosts.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func hostHistoryKey(for host: MirageHost) -> String {
        host.endpoint.debugDescription
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
