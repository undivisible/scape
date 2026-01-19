import SwiftUI

extension View {
    @ViewBuilder
    func visionGlassBackground() -> some View {
        #if os(visionOS)
        self.glassBackgroundEffect()
        #else
        self
        #endif
    }
    
    @ViewBuilder
    func visionHoverEffect() -> some View {
        #if os(visionOS)
        self.hoverEffect()
        #elseif os(iOS) || os(tvOS)
        self.hoverEffect()
        #else
        self
        #endif
    }
}
