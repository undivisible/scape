import SwiftUI
import MirageKit

struct HostDashboardView: View {
    @ObservedObject var controller: HostController
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "visionpro")
                    .font(.system(size: 44))
                    .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.bounce, value: controller.connectedClients.count)
                
                Text("Scape Host")
                    .font(.title2.weight(.bold))
                
                Text(controller.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            Divider()
                .background(.secondary.opacity(0.3))
            
            // Client List
            ScrollView {
                if controller.connectedClients.isEmpty {
                    ContentUnavailableView {
                        Label("No Clients Connected", systemImage: "network.slash")
                    } description: {
                        Text("Open Scape on your Vision Pro to connect.")
                    }
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.connectedClients, id: \.id) { client in
                            HStack {
                                Image(systemName: "visionpro")
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text(client.name)
                                        .font(.headline)
                                    Text("Connected")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding()
                }
            }
            
            Spacer()
            
            // Footer Controls
            HStack {
                Button(role: .destructive) {
                    exit(0)
                } label: {
                    Label("Quit Scape", systemImage: "power")
                }
                .buttonStyle(.plain)
                .padding(8)
                .background(.regularMaterial)
                .clipShape(Capsule())
                
                Spacer()
                
                Button {
                    Task { try? await controller.start() }
                } label: {
                    Label("Restart Service", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(8)
                .background(.regularMaterial)
                .clipShape(Capsule()) 
            }
            .padding()
        }
        .frame(width: 320, height: 450)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    HostDashboardView(controller: HostController())
}
