import SwiftUI

@main
struct MoniconApp: App {
    @StateObject private var capture: CaptureSessionManager

    init() {
        MoniconDiagnostics.install()
        _capture = StateObject(wrappedValue: CaptureSessionManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(capture)
                .preferredColorScheme(.dark)
        }
    }
}

