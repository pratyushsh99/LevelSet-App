import SwiftUI

@main
struct LevelSetApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
