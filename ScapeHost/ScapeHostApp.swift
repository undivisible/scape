import SwiftUI
import MirageKit

@main
struct ScapeHostApp: App {
    @StateObject private var controller = HostController()
    
    var body: some Scene {
        MenuBarExtra("Scape Host", systemImage: "visionpro") {
            HostDashboardView(controller: controller)
        }
        .menuBarExtraStyle(.window) // Allows for a rich SwiftUI view
    }
}
