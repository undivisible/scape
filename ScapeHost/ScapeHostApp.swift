import SwiftUI
import MirageKit

@main
struct ScapeHostApp: App {
    @StateObject private var controller = HostController()
    
    var body: some Scene {
        Window("Scape Host", id: "main") {
            VStack {
                Text("Scape Host Running")
                    .font(.largeTitle)
                Text("Status: \(controller.status)")
                    .foregroundStyle(.secondary)
                
                Button("Restart Service") {
                    Task { try? await controller.start() }
                }
                .padding()
            }
            .padding()
            .task {
                do {
                    try await controller.start()
                } catch {
                    print("Failed to start host: \(error)")
                }
            }
        }
    }
}
