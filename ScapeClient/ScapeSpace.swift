import SwiftUI
import RealityKit
import MirageKit

struct ScapeSpace: View {
    @ObservedObject var controller: ClientController
    
    var body: some View {
        ZStack {
            // Simple placeholder for streams (avoids problematic MirageStreamContentView)
            VStack {
                Text("Connected to \(controller.connectedHost?.name ?? "Unknown")")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                Text("\(controller.activeStreams.count) active streams")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Window picker HUD
            VStack {
                Spacer()
                
                if !controller.availableWindows.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(controller.availableWindows, id: \.id) { window in
                                Button {
                                    controller.startStream(for: window)
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "macwindow")
                                            .font(.system(size: 32))
                                            .symbolRenderingMode(.hierarchical)
                                        
                                        Text(window.title ?? "Window")
                                            .font(.caption)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 120)
                                    }
                                    .padding(16)
                                    .frame(width: 140, height: 120)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 24)
                    }
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    .padding(.bottom, 40)
                } else {
                    VStack {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading windows...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
