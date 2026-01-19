import SwiftUI
import MirageKit

@main
struct ScapeClientApp: App {
    @StateObject private var controller = ClientController()
    
    var body: some Scene {
        WindowGroup {
            HostPickerView(controller: controller)
        }
        .windowStyle(.plain) // Glassy look
        
        #if os(visionOS)
        ImmersiveSpace(id: "scape_space") {
            ScapeSpace(controller: controller)
        }
        #endif
    }
}
