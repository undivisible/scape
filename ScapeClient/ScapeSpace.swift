import SwiftUI
import MirageKit

struct ScapeSpace: View {
    @ObservedObject var controller: ClientController
    #if os(visionOS)
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    #endif

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                activeStreamsSection
                availableWindowsSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
        }
        .background(.black.opacity(0.2))
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(connectionStatusLabel)
                .font(.title3)
                .foregroundStyle(.secondary)

            #if os(visionOS)
            Text(controller.connectedHost?.name ?? "Unknown")
                .font(.largeTitle)
                .foregroundStyle(.primary)
            #endif

            HStack(spacing: 10) {
                Text("\(controller.activeStreams.count) active streams")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())

                if let error = controller.lastErrorMessage, !error.isEmpty {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

                Button {
                    Task {
                        await controller.disconnect()
                        #if os(visionOS)
                        await dismissImmersiveSpace()
                        openWindow(id: "host_picker")
                        #endif
                    }
                } label: {
                    Label("Disconnect", systemImage: "arrow.backward.circle")
                }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .visionGlassBackground()
    }

    private var activeStreamsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Streams")
                .font(.headline)
                .foregroundStyle(.secondary)

            if controller.activeStreams.isEmpty {
                ContentUnavailableView {
                    Label("No active streams", systemImage: "rectangle.connected.to.line.below")
                } description: {
                    Text("Select a window below to start streaming.")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(controller.activeStreams) { session in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(session.window.displayName)
                                    .font(.headline)
                                    .lineLimit(2)

                                Text(session.quality.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Button {
                                    controller.stopStream(session)
                                } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .frame(width: 220, alignment: .leading)
                            .padding(16)
                            .visionGlassBackground()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(20)
        .visionGlassBackground()
    }

    private var availableWindowsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available Windows")
                .font(.headline)
                .foregroundStyle(.secondary)

            if controller.availableWindows.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Waiting for windows...")
                        .font(.headline)
                }
                .padding(30)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(controller.availableWindows, id: \.id) { window in
                            Button {
                                controller.startStream(for: window)
                            } label: {
                                VStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(.regularMaterial)
                                            .frame(width: 80, height: 80)

                                        Image(systemName: "macwindow")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                            .symbolEffect(.bounce.down, value: true)
                                    }

                                    Text(window.displayName)
                                        .font(.caption)
                                        .lineLimit(2)
                                        .frame(width: 100)
                                }
                                .padding(16)
                                .visionGlassBackground()
                            }
                            .buttonStyle(.plain)
                            .visionHoverEffect()
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
            }
        }
        .padding(20)
        .visionGlassBackground()
    }

    private var connectionStatusLabel: String {
        switch controller.connectionState {
        case .connected:
            return "Connected to"
        case .connecting:
            return "Connecting to"
        case .reconnecting:
            return "Reconnecting to"
        case .error:
            return "Connection error"
        case .disconnected:
            return "Disconnected from"
        }
    }
}
