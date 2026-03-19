import SwiftUI
import MirageKit

struct HostPickerView: View {
    @ObservedObject var controller: ClientController
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    statusCard
                    
                    if case .connecting = controller.connectionState {
                        connectingCard
                    }
                    
                    if controller.connectedHost != nil {
                        connectedDashboard
                    } else {
                        hostDiscoveryList
                    }
                }
                .frame(width: 600)
                .padding(.horizontal, 32)
                .padding(.vertical, 32)
            }
            .frame(width: 600, height: 500)
            .background(.regularMaterial)
            .cornerRadius(40)
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "visionpro")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .symbolEffect(.pulse.byLayer)
            
            Text("Scape")
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
            
            Text("Select a Mac to extend your reality")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(controller.statusMessage, systemImage: statusIconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            if let error = controller.lastErrorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .visionGlassBackground()
    }

    private var connectingCard: some View {
        HStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)

            VStack(alignment: .leading, spacing: 4) {
                Text("Connecting")
                    .font(.headline)
                Text("Negotiating session and fetching the window list.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .visionGlassBackground()
    }

    private var connectedDashboard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(controller.connectedHost?.name ?? "Connected")
                        .font(.title2.weight(.semibold))
                    Text(controller.statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        await controller.disconnect()
                    }
                } label: {
                    Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .clipShape(Capsule())
            }

            Divider()
                .background(.secondary.opacity(0.3))

            VStack(alignment: .leading, spacing: 12) {
                Text("Active Streams")
                    .font(.headline)

                if controller.activeStreams.isEmpty {
                    ContentUnavailableView {
                        Label("No active streams", systemImage: "rectangle.on.rectangle")
                    } description: {
                        Text("Start a window stream from the available windows list.")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.activeStreams, id: \.id) { session in
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.window.displayName)
                                        .font(.headline)
                                    Text(session.quality.displayName)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Button("Stop") {
                                    controller.stopStream(session)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Available Windows")
                    .font(.headline)

                if controller.availableWindows.isEmpty {
                    ContentUnavailableView {
                        Label("Waiting for windows", systemImage: "macwindow")
                    } description: {
                        Text("Ask the host for a window list or wait for discovery to finish.")
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.availableWindows, id: \.id) { window in
                            Button {
                                controller.startStream(for: window)
                            } label: {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(window.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        Text(window.application?.name ?? "Unknown app")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "play.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.primary)
                                }
                                .padding(14)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .visionHoverEffect()
                        }
                    }
                }
            }
        }
        .padding(18)
        .visionGlassBackground()
    }

    private var hostDiscoveryList: some View {
        Group {
            if controller.availableHosts.isEmpty {
                ContentUnavailableView {
                    Label("Scanning for Macs...", systemImage: "waveform.circle")
                        .symbolEffect(.variableColor.iterative)
                } description: {
                    Text("Ensure Scape Host is running on your Mac and on the same Wi-Fi.")
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Available Macs")
                        .font(.headline)

                    LazyVStack(spacing: 16) {
                        ForEach(controller.availableHosts) { host in
                            Button {
                                connect(to: host)
                            } label: {
                                HStack(spacing: 20) {
                                    ZStack {
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                            .frame(width: 60, height: 60)
                                        Image(systemName: host.deviceType.systemImage)
                                            .font(.title2)
                                            .foregroundStyle(.primary)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(host.name)
                                            .font(.headline)
                                        Text(host.deviceType.displayName)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.secondary.opacity(0.5))
                                }
                                .padding(20)
                                .visionGlassBackground()
                            }
                            .buttonStyle(.plain)
                            .visionHoverEffect()
                        }
                    }
                }
            }
        }
    }

    private var statusIconName: String {
        switch controller.connectionState {
        case .connected:
            return "link.circle.fill"
        case .connecting, .reconnecting:
            return "network"
        case .error:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "network.slash"
        }
    }

    private func connect(to host: MirageHost) {
        Task {
            do {
                try await controller.connect(to: host)
                #if os(visionOS)
                await openImmersiveSpace(id: "scape_space")
                dismissWindow()
                #endif
            } catch {
                print("Failed to connect: \(error)")
            }
        }
    }
}

#Preview {
    HostPickerView(controller: ClientController())
}
