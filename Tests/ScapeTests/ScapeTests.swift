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
    var discoveredHosts: [MirageHost] = []
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func startDiscovery() {
        startCount += 1
    }

    func stopDiscovery() {
        stopCount += 1
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
