import SwiftUI
import MirageKit

struct HostPickerView: View {
    @ObservedObject var controller: ClientController
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Scape")
                    .font(.system(size: 56, weight: .thin, design: .rounded))
                
                Text("Stream your Mac")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            
            if controller.availableHosts.isEmpty {
                ContentUnavailableView {
                    Label("Searching for Macs", systemImage: "macbook.gen2")
                } description: {
                    Text("Make sure Scape Host is running on your Mac")
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(controller.availableHosts) { host in
                            Button {
                                connect(to: host)
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: host.deviceType.systemImage)
                                        .font(.system(size: 32))
                                        .symbolRenderingMode(.hierarchical)
                                        .frame(width: 48)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(host.name)
                                            .font(.headline)
                                        Text(host.deviceType.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(20)
                                .frame(maxWidth: .infinity)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(40)
        .frame(width: 600, height: 500)
    }
    
    private func connect(to host: MirageHost) {
        Task {
            do {
                try await controller.connect(to: host)
                await openImmersiveSpace(id: "scape_space")
            } catch {
                print("Failed to connect: \(error)")
            }
        }
    }
}
