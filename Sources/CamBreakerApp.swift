import SwiftUI

@main
struct CamBreakerApp: App {
    var body: some Scene {
        WindowGroup {
            MenuView()
                // The whole game is designed on black: lock dark mode so
                // text, pickers and toggles never wash out in light mode.
                .preferredColorScheme(.dark)
        }
    }
}
