import SwiftUI

/// The Apple TV artwork (`tv.png`), scaled so the transparent edges stay sharp.
struct AppleTVMark: View {
    var body: some View {
        Image("tv")
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .accessibilityLabel("Apple TV")
    }
}
