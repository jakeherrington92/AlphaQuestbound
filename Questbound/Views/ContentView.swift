import SwiftUI

private struct ChangeCharacterActionKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var changeCharacterAction: () -> Void {
        get { self[ChangeCharacterActionKey.self] }
        set { self[ChangeCharacterActionKey.self] = newValue }
    }
}

struct ContentView: View {
    @StateObject private var saveStore = SaveStore()
    @State private var navigationSessionID = UUID()
    @State private var showCharacterVault = false

    var body: some View {
        MainMenuView(openCharacterVault: $showCharacterVault)
            .id(navigationSessionID)
            .environmentObject(saveStore)
            .environment(\.changeCharacterAction) {
                showCharacterVault = true
                navigationSessionID = UUID()
            }
    }
}
