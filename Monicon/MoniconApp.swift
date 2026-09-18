import SwiftUI

@main
struct MoniconApp: App {
    @StateObject private var capture = CaptureSessionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(capture)
                .preferredColorScheme(.dark)
        }
    }
}

