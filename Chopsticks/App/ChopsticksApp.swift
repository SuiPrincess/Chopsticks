import SwiftUI

@main
struct ChopsticksApp: App {
    var body: some Scene {
        WindowGroup {
            MenuView()
                .preferredColorScheme(.dark)
        }
    }
}
