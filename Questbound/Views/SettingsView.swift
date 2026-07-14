import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.changeCharacterAction) private var changeCharacter

    let slotID: Int?

    @State private var showDeleteSaveConfirm = false
    @State private var showResetTipsConfirm = false
    @State private var showChangeCharacterConfirm = false

    init(slotID: Int? = nil) {
        self.slotID = slotID
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Settings")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    if slotID != nil {
                        settingsCard("Character") {
                            Button {
                                showChangeCharacterConfirm = true
                            } label: {
                                Label("Change Character", systemImage: "person.2")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(QuestboundTheme.accent)

                            Text("Save your progress and return to character selection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    settingsCard("Audio") {
                        Toggle("Sound", isOn: boolBinding(\.soundEnabled))
                        Toggle("Music", isOn: boolBinding(\.musicEnabled))
                        Text("Audio assets are placeholders for now; these preferences are saved for later milestones.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    settingsCard("Accessibility") {
                        Picker("Text Size", selection: textSizeBinding) {
                            ForEach(QuestboundTextSize.allCases) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Reduced Animations", isOn: boolBinding(\.reduceMotion))
                        Toggle("Haptics", isOn: boolBinding(\.hapticsEnabled))
                    }

                    settingsCard("Confirmations") {
                        Toggle("Confirm Rare and Epic Sales", isOn: boolBinding(\.confirmRareEpicSales))
                        Toggle("Show Normal Sell Confirmation", isOn: normalSellConfirmationBinding)
                        Text("Hero deletion, adventure abandon, exit without saving, restocks, Fortune Rolls and Subpath choices still ask for confirmation.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    settingsCard("Tutorial Tips") {
                        detailRow("Dismissed", "\(saveStore.settings.dismissedTutorialTips.count)")
                        Button {
                            showResetTipsConfirm = true
                        } label: {
                            Label("Reset Tutorial Tips", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(QuestboundTheme.accent)
                    }

                    settingsCard("Developer") {
                        Toggle("Show Developer Tools", isOn: boolBinding(\.developerModeEnabled))
                        Text("Developer tools are hidden from Greywick unless this is enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    settingsCard("Credits and Legal") {
                        Text("Questbound is an original custom d20 fantasy RPG prototype. Final credits, licenses and legal text will be added with final assets.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    settingsCard("Save Data") {
                        Button(role: .destructive) {
                            showDeleteSaveConfirm = true
                        } label: {
                            Label("Delete All Local Save Data", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Tutorial Tips?", isPresented: $showResetTipsConfirm) {
            Button("Reset") {
                saveStore.resetTutorialTips()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dismissed help tips will appear again across the app.")
        }
        .alert("Delete All Save Data?", isPresented: $showDeleteSaveConfirm) {
            Button("Delete", role: .destructive) {
                saveStore.deleteAllSaveData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes all four hero slots, shop state and settings from this device.")
        }
        .alert("Change Character?", isPresented: $showChangeCharacterConfirm) {
            Button("Save and Change Character") {
                saveBeforeChangingCharacter()
                changeCharacter()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your current progress will be saved before returning to character selection.")
        }
    }

    private func boolBinding(_ keyPath: WritableKeyPath<Settings, Bool>) -> Binding<Bool> {
        Binding {
            saveStore.settings[keyPath: keyPath]
        } set: { newValue in
            var settings = saveStore.settings
            settings[keyPath: keyPath] = newValue
            saveStore.updateSettings(settings)
        }
    }

    private var textSizeBinding: Binding<QuestboundTextSize> {
        Binding {
            saveStore.settings.textSize
        } set: { newValue in
            var settings = saveStore.settings
            settings.textSize = newValue
            saveStore.updateSettings(settings)
        }
    }

    private var normalSellConfirmationBinding: Binding<Bool> {
        Binding {
            !saveStore.settings.skipNormalSellConfirmation
        } set: { newValue in
            var settings = saveStore.settings
            settings.skipNormalSellConfirmation = !newValue
            saveStore.updateSettings(settings)
        }
    }

    private func saveBeforeChangingCharacter() {
        guard let slotID,
              let hero = saveStore.slots.first(where: { $0.id == slotID })?.hero else { return }
        if hero.currentAdventureState.adventureID != nil {
            saveStore.saveAdventureProgress(slotID: slotID)
        } else {
            saveStore.markPlayed(slotID: slotID)
        }
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}
