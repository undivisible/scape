import XCTest
import Network
import MirageKit
@testable import ScapeClient
@testable import ScapeHost

@MainActor
final class ScapeTests: XCTestCase {
    func testTrustedDeviceStorePersistsTrust() {
        let defaults = makeDefaults(prefix: "trusted")
        let store = TrustedDeviceStore(defaults: defaults, key: "trusted.devices")
        let deviceID = UUID()

        XCTAssertFalse(store.isTrusted(deviceID: deviceID))
        store.trust(deviceID: deviceID)
        XCTAssertTrue(store.isTrusted(deviceID: deviceID))

        store.revoke(deviceID: deviceID)
        XCTAssertFalse(store.isTrusted(deviceID: deviceID))
    }

    func testTrustedDeviceStoreRevokesOnlyTargetDevice() {
        let defaults = makeDefaults(prefix: "trusted-revoke")
        let store = TrustedDeviceStore(defaults: defaults, key: "trusted.devices")
        let trustedDeviceID = UUID()
        let revokedDeviceID = UUID()

        store.trust(deviceID: trustedDeviceID)
        store.trust(deviceID: revokedDeviceID)

        XCTAssertTrue(store.isTrusted(deviceID: trustedDeviceID))
        XCTAssertTrue(store.isTrusted(deviceID: revokedDeviceID))

        store.revoke(deviceID: revokedDeviceID)

        XCTAssertTrue(store.isTrusted(deviceID: trustedDeviceID))
        XCTAssertFalse(store.isTrusted(deviceID: revokedDeviceID))
    }

    func testRecentWindowStorePrioritizesMostRecentWindow() {
        let defaults = makeDefaults(prefix: "recent")
        let store = RecentWindowStore(defaults: defaults, key: "recent.windows")
        let hostKey = "host-a"

        let app = MirageApplication(id: 42, bundleIdentifier: "com.example.app", name: "Example")
        let windowA = MirageWindow(id: 10, title: "Alpha", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)
        let windowB = MirageWindow(id: 20, title: "Beta", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)

        store.remember(windowID: windowB.id, for: hostKey)

        let ordered = store.orderedWindows([windowA, windowB], for: hostKey)
        XCTAssertEqual(ordered.map { $0.id }, [windowB.id, windowA.id])
    }

    func testRecentWindowStoreKeepsHistoryPerHost() {
        let defaults = makeDefaults(prefix: "recent-per-host")
        let store = RecentWindowStore(defaults: defaults, key: "recent.windows")
        let hostA = "host-a"
        let hostB = "host-b"

        let app = MirageApplication(id: 42, bundleIdentifier: "com.example.app", name: "Example")
        let windowA = MirageWindow(id: 10, title: "Alpha", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)
        let windowB = MirageWindow(id: 20, title: "Beta", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)

        store.remember(windowID: windowA.id, for: hostA)
        store.remember(windowID: windowB.id, for: hostB)

        XCTAssertEqual(store.recentWindowID(for: hostA), windowA.id)
        XCTAssertEqual(store.recentWindowID(for: hostB), windowB.id)
        XCTAssertEqual(store.orderedWindows([windowA, windowB], for: hostA).map { $0.id }, [windowA.id, windowB.id])
        XCTAssertEqual(store.orderedWindows([windowA, windowB], for: hostB).map { $0.id }, [windowB.id, windowA.id])
    }

    func testClientSessionStorePersistsLastHostHistoryKey() {
        let defaults = makeDefaults(prefix: "session-host")
        let store = ClientSessionStore(defaults: defaults, lastHostKeyKey: "session.host")
        let hostKey = "host-history-key"

        store.lastHostHistoryKey = hostKey

        let reloadedStore = ClientSessionStore(defaults: defaults, lastHostKeyKey: "session.host")
        XCTAssertEqual(reloadedStore.lastHostHistoryKey, hostKey)
    }

    func testHostControllerAutoAcceptsTrustedDevice() async {
        let defaults = makeDefaults(prefix: "host-auto")
        let trustStore = TrustedDeviceStore(defaults: defaults, key: "trusted.devices")
        let deviceID = UUID()
        trustStore.trust(deviceID: deviceID)

        let controller = HostController(
            hostService: MockHostService(),
            trustedDeviceStore: trustStore,
            autoStart: false
        )

        let accepted = BoolBox()
        controller.hostService(
            MirageHostService(),
            shouldAcceptConnectionFrom: MirageDeviceInfo(id: deviceID, name: "Trusted Mac", deviceType: .mac, endpoint: "trusted-endpoint")
        ) { result in
            accepted.value = result
        }

        XCTAssertEqual(accepted.value, true)
        XCTAssertTrue(controller.pendingConnectionApprovals.isEmpty)
    }

    func testHostControllerApprovalTrustsDeviceAndClearsPendingApproval() {
        let defaults = makeDefaults(prefix: "host-approval")
        let trustStore = TrustedDeviceStore(defaults: defaults, key: "trusted.devices")
        let controller = HostController(
            hostService: MockHostService(),
            trustedDeviceStore: trustStore,
            autoStart: false
        )

        let deviceID = UUID()
        let request = MirageDeviceInfo(name: "New Mac", deviceType: .mac, endpoint: "new-endpoint")
        let accepted = BoolBox()

        controller.hostService(
            MirageHostService(),
            shouldAcceptConnectionFrom: MirageDeviceInfo(id: deviceID, name: request.name, deviceType: request.deviceType, endpoint: request.endpoint)
        ) { result in
            accepted.value = result
        }

        XCTAssertEqual(controller.pendingConnectionApprovals.count, 1)

        guard let pending = controller.pendingConnectionApprovals.first else {
            XCTFail("Expected pending approval")
            return
        }

        controller.approveConnection(pending)

        XCTAssertEqual(accepted.value, true)
        XCTAssertTrue(trustStore.isTrusted(deviceID: deviceID))
        XCTAssertTrue(controller.pendingConnectionApprovals.isEmpty)
    }

    func testClientControllerReordersRecentWindowFirst() async throws {
        let defaults = makeDefaults(prefix: "client-history")
        let historyStore = RecentWindowStore(defaults: defaults, key: "recent.windows")
        let mockDiscovery = MockDiscovery()
        let mockService = MockClientService()
        let controller = ClientController(
            clientService: mockService,
            discovery: mockDiscovery,
            recentWindowStore: historyStore,
            autoStartDiscovery: false
        )

        let host = makeHost(name: "Scape Mac", port: 1111)
        let app = MirageApplication(id: 7, bundleIdentifier: "com.example.browser", name: "Browser")
        let windowA = MirageWindow(id: 1, title: "Alpha", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)
        let windowB = MirageWindow(id: 2, title: "Beta", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)

        mockService.availableWindows = [windowA, windowB]
        try await controller.connect(to: host)
        controller.startStream(for: windowB)
        await Task.yield()

        XCTAssertEqual(controller.availableWindows.map(\.id), [windowB.id, windowA.id])
    }

    func testClientControllerRestoresLastWindowForSameHostAfterReconnect() async throws {
        let defaults = makeDefaults(prefix: "client-session-resume")
        let historyStore = RecentWindowStore(defaults: defaults, key: "recent.windows")
        let mockDiscovery = MockDiscovery()
        let mockService = MockClientService()
        let controller = ClientController(
            clientService: mockService,
            discovery: mockDiscovery,
            recentWindowStore: historyStore,
            autoStartDiscovery: false
        )

        let host = makeHost(name: "Scape Mac", port: 3333)
        let app = MirageApplication(id: 7, bundleIdentifier: "com.example.browser", name: "Browser")
        let windowA = MirageWindow(id: 1, title: "Alpha", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)
        let windowB = MirageWindow(id: 2, title: "Beta", application: app, frame: .zero, isOnScreen: true, windowLayer: 0)

        mockService.availableWindows = [windowA, windowB]
        try await controller.connect(to: host)
        controller.clientService(MirageClientService(), didUpdateWindowList: [windowA, windowB])
        controller.startStream(for: windowB)
        await Task.yield()
        XCTAssertEqual(controller.availableWindows.map(\.id), [windowB.id, windowA.id])

        await controller.disconnect()
        mockService.availableWindows = [windowA, windowB]

        try await controller.connect(to: host)
        controller.clientService(MirageClientService(), didUpdateWindowList: [windowA, windowB])

        XCTAssertEqual(controller.availableWindows.map(\.id), [windowB.id, windowA.id])
    }

    func testClientControllerAutoResumesRememberedHostWhenDiscovered() async throws {
        let defaults = makeDefaults(prefix: "client-auto-resume")
        let historyStore = RecentWindowStore(defaults: defaults, key: "recent.windows")
        let sessionStore = ClientSessionStore(defaults: defaults, lastHostKeyKey: "session.host")
        let mockDiscovery = MockDiscovery()
        let mockService = MockClientService()
        let controller = ClientController(
            clientService: mockService,
            discovery: mockDiscovery,
            recentWindowStore: historyStore,
            sessionStore: sessionStore,
            autoStartDiscovery: true
        )

        let host = makeHost(name: "Scape Mac", port: 3334)
        sessionStore.lastHostHistoryKey = host.endpoint.debugDescription
        mockDiscovery.discoveredHosts = [host]

        await waitUntil {
            controller.connectedHost?.endpoint.debugDescription == host.endpoint.debugDescription
        }

        XCTAssertEqual(mockService.connectCalls.count, 1)
        XCTAssertEqual(mockDiscovery.startCount, 1)
        XCTAssertEqual(sessionStore.lastHostHistoryKey, host.endpoint.debugDescription)
    }

    func testClientControllerDisconnectRestartsDiscovery() async throws {
        let mockDiscovery = MockDiscovery()
        let mockService = MockClientService()
        let controller = ClientController(
            clientService: mockService,
            discovery: mockDiscovery,
            recentWindowStore: RecentWindowStore(defaults: makeDefaults(prefix: "client-disconnect"), key: "recent.windows"),
            autoStartDiscovery: false
        )

        let host = makeHost(name: "Scape Mac", port: 2222)
        try await controller.connect(to: host)
        XCTAssertNotNil(controller.connectedHost)

        await controller.disconnect()

        XCTAssertNil(controller.connectedHost)
        XCTAssertEqual(mockDiscovery.startCount, 1)
    }

    private func waitUntil(_ condition: @escaping () -> Bool, maxIterations: Int = 50) async {
        for _ in 0..<maxIterations {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for condition")
    }

    private func makeDefaults(prefix: String) -> UserDefaults {
        let suiteName = "com.scape.tests.\(prefix).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func makeHost(name: String, port: UInt16) -> MirageHost {
        MirageHost(
            id: UUID(),
            name: name,
            deviceType: .mac,
            endpoint: .hostPort(host: NWEndpoint.Host("127.0.0.1"), port: NWEndpoint.Port(rawValue: port)!),
            capabilities: MirageHostCapabilities()
        )
    }
}

@MainActor
final class MockDiscovery: DiscoveryManaging {
    var discoveredHosts: [MirageHost] = [] {
        didSet {
            onChange?()
        }
    }
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var onChange: (@MainActor () -> Void)?

    func startDiscovery() {
        startCount += 1
    }

    func stopDiscovery() {
        stopCount += 1
    }

    func observeDiscoveredHosts(_ onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }
}

@MainActor
final class MockClientService: ClientServiceManaging {
    weak var delegate: MirageClientDelegate?
    var connectionState: MirageClientService.ConnectionState = .disconnected
    var availableWindows: [MirageWindow] = []
    var activeStreams: [ClientStreamSession] = []

    private(set) var connectCalls: [MirageHost] = []
    private(set) var disconnectCount = 0
    private(set) var requestWindowListCount = 0
    private(set) var stopViewingSessions: [ClientStreamSession] = []

    func connect(to host: MirageHost) async throws {
        connectCalls.append(host)
        connectionState = .connected(host: host.name)
    }

    func disconnect() async {
        disconnectCount += 1
        connectionState = .disconnected
        activeStreams.removeAll()
    }

    func requestWindowList() async throws {
        requestWindowListCount += 1
    }

    func startViewing(
        window: MirageWindow,
        quality: MirageQualityPreset,
        expectedPixelSize: CGSize?,
        scaleFactor: CGFloat?,
        displayResolution: CGSize?,
        maxBitrate: Int?,
        keyFrameInterval: Int?,
        keyframeQuality: Float?
    ) async throws -> ClientStreamSession {
        let session = ClientStreamSession(id: StreamID(truncatingIfNeeded: window.id), window: window, quality: quality)
        activeStreams.append(session)
        return session
    }

    func stopViewing(_ session: ClientStreamSession, minimizeWindow: Bool) async {
        stopViewingSessions.append(session)
        activeStreams.removeAll { $0.id == session.id }
    }
}

@MainActor
final class MockHostService: HostServiceManaging {
    weak var delegate: MirageHostDelegate?
    private(set) var startCount = 0

    func start() async throws {
        startCount += 1
    }
}

final class BoolBox: @unchecked Sendable {
    var value: Bool?
}
