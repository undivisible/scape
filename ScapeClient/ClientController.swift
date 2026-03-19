import Foundation
import Combine
import MirageKit

@MainActor
final class ClientController: ObservableObject {
    let clientService: any ClientServiceManaging
    private let discovery: any DiscoveryManaging
    private let recentWindowStore: RecentWindowStore
    private let sessionStore: ClientSessionStore
    private var currentHostHistoryKey: String?
    private var pendingResumeWindowID: WindowID?
    private var didAttemptAutoResume = false
    
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
        sessionStore: ClientSessionStore = ClientSessionStore(),
        autoStartDiscovery: Bool = true
    ) {
        self.clientService = clientService
        self.discovery = discovery
        self.recentWindowStore = recentWindowStore
        self.sessionStore = sessionStore
        clientService.delegate = self
        syncClientState()
        if autoStartDiscovery {
            setupDiscovery()
        }
    }
    
    private func setupDiscovery() {
        refreshDiscoveryHosts()
        discovery.observeDiscoveredHosts { [weak self] in
            self?.refreshDiscoveryHosts()
            self?.attemptAutoResumeIfNeeded()
        }
        discovery.startDiscovery()
        attemptAutoResumeIfNeeded()
    }
    
    func connect(to host: MirageHost) async throws {
        lastErrorMessage = nil
        statusMessage = "Connecting to \(host.name)..."
        discovery.stopDiscovery()
        connectionState = .connecting
        do {
            try await clientService.connect(to: host)
            connectedHost = host
            let hostHistoryKey = hostHistoryKey(for: host)
            currentHostHistoryKey = hostHistoryKey
            sessionStore.lastHostHistoryKey = currentHostHistoryKey
            pendingResumeWindowID = recentWindowStore.recentWindowID(for: hostHistoryKey)
            didAttemptAutoResume = true
            syncClientState()
            statusMessage = "Connected to \(host.name). Loading windows..."
            try await clientService.requestWindowList()
        } catch {
            connectedHost = nil
            currentHostHistoryKey = nil
            pendingResumeWindowID = nil
            didAttemptAutoResume = true
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
        pendingResumeWindowID = nil
        didAttemptAutoResume = true
        lastErrorMessage = nil
        syncClientState()
        statusMessage = "Scanning for hosts..."
        discovery.startDiscovery()
    }
    
    func startStream(for window: MirageWindow) {
        pendingResumeWindowID = nil
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
        attemptAutoResumeIfNeeded()
    }

    private func attemptAutoResumeIfNeeded() {
        guard !didAttemptAutoResume else {
            return
        }
        guard case .disconnected = connectionState, connectedHost == nil, currentHostHistoryKey == nil else {
            return
        }
        guard let rememberedHostKey = sessionStore.lastHostHistoryKey else {
            return
        }
        guard let host = availableHosts.first(where: { hostHistoryKey(for: $0) == rememberedHostKey }) else {
            return
        }

        didAttemptAutoResume = true
        statusMessage = "Resuming connection to \(host.name)..."
        pendingResumeWindowID = recentWindowStore.recentWindowID(for: rememberedHostKey)
        Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.connect(to: host)
            } catch {
                // connect(_:) already updates error state and restarts discovery
            }
        }
    }

    private func attemptPendingResumeIfPossible() {
        guard case .connected = connectionState,
              connectedHost != nil,
              activeStreams.isEmpty,
              let pendingResumeWindowID,
              let window = availableWindows.first(where: { $0.id == pendingResumeWindowID }) else {
            return
        }

        self.pendingResumeWindowID = nil
        startStream(for: window)
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
        attemptPendingResumeIfPossible()
    }

    func clientService(_ service: MirageClientService, didDisconnectFromHost reason: String) {
        connectedHost = nil
        currentHostHistoryKey = nil
        pendingResumeWindowID = nil
        didAttemptAutoResume = true
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
