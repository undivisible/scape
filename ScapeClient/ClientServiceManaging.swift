import Foundation
import CoreGraphics
import Observation
import MirageKit

@MainActor
protocol ClientServiceManaging: AnyObject {
    var delegate: MirageClientDelegate? { get set }
    var connectionState: MirageClientService.ConnectionState { get }
    var availableWindows: [MirageWindow] { get }
    var activeStreams: [ClientStreamSession] { get }

    func connect(to host: MirageHost) async throws
    func disconnect() async
    func requestWindowList() async throws
    func startViewing(
        window: MirageWindow,
        quality: MirageQualityPreset,
        expectedPixelSize: CGSize?,
        scaleFactor: CGFloat?,
        displayResolution: CGSize?,
        maxBitrate: Int?,
        keyFrameInterval: Int?,
        keyframeQuality: Float?
    ) async throws -> ClientStreamSession
    func stopViewing(_ session: ClientStreamSession, minimizeWindow: Bool) async
}

@MainActor
protocol DiscoveryManaging: AnyObject {
    var discoveredHosts: [MirageHost] { get }
    func startDiscovery()
    func stopDiscovery()
    func observeDiscoveredHosts(_ onChange: @escaping @MainActor () -> Void)
}

extension MirageClientService: ClientServiceManaging {}

extension MirageDiscovery: DiscoveryManaging {
    func observeDiscoveredHosts(_ onChange: @escaping @MainActor () -> Void) {
        withObservationTracking {
            _ = discoveredHosts
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                onChange()
                self?.observeDiscoveredHosts(onChange)
            }
        }
    }
}
