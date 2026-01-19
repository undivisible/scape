import SwiftUI
import RealityKit
import MirageKit

struct ScapeSpace: View {
    @ObservedObject var controller: ClientController
    
    var body: some View {
        ZStack {
            // Main content area would go here
            // For now, just status
            
            VStack {
                Text("Connected to")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(controller.connectedHost?.name ?? "Unknown")
                    .font(.extraLargeTitle)
                    .foregroundStyle(.primary)
                
                Text("\(controller.activeStreams.count) active streams")
                    .font(.caption)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .opacity(0.6)
            
            // HUD
            VStack {
                Spacer()
                
                if !controller.availableWindows.isEmpty {
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
                                        
                                        Text(window.title ?? "Window")
                                            .font(.caption)
                                            .lineLimit(1)
                                            .frame(width: 100)
                                    }
                                    .padding(16)
                                    .visionGlassBackground()
                                }
                                .buttonStyle(.plain)
                                .visionHoverEffect()
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 30)
                    }
                } else {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Waiting for windows...")
                            .font(.headline)
                    }
                    .padding(30)
                    .visionGlassBackground()
                    .padding(.bottom, 50)
                }
            }
            .padding(.bottom, 20)
        }
    }
}
