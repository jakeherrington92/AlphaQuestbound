import SwiftUI

@main
struct QuestboundApp: App {
    init() {
#if DEBUG
        print("[Questbound] App launched")
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
