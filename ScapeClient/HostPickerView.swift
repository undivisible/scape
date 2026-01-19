import SwiftUI
import MirageKit

struct HostPickerView: View {
    @ObservedObject var controller: ClientController
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Header
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
                .padding(.top, 40)
                
                // Content
                if controller.availableHosts.isEmpty {
                    ContentUnavailableView {
                        Label("Scanning for Macs...", systemImage: "waveform.circle")
                            .symbolEffect(.variableColor.iterative)
                    } description: {
                        Text("Ensure Scape Host is running on your Mac and on the same Wi-Fi.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
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
                        .padding(.horizontal, 40)
                        .padding(.bottom, 40)
                    }
                }
            }
            .frame(width: 600, height: 500)
            .background(.regularMaterial)
            .cornerRadius(40)
        }
    }
    
    private func connect(to host: MirageHost) {
        Task {
            do {
                try await controller.connect(to: host)
                await openImmersiveSpace(id: "scape_space")
                dismissWindow()
            } catch {
                print("Failed to connect: \(error)")
            }
        }
    }
}

#Preview {
    HostPickerView(controller: ClientController())
}
