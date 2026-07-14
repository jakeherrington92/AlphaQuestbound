import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Binding var openCharacterVault: Bool
    @State private var showCreatePrompt = false
    @State private var openCreateHero = false

    init(openCharacterVault: Binding<Bool> = .constant(false)) {
        _openCharacterVault = openCharacterVault
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestboundTheme.background.ignoresSafeArea()
                // Future art hook: replace this panel with background_main_menu.png.
                LinearGradient(
                    colors: [
                        Color(red: 0.09, green: 0.12, blue: 0.16),
                        Color(red: 0.23, green: 0.18, blue: 0.12),
                        Color(red: 0.12, green: 0.18, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 22) {
                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questbound")
                            .font(.system(size: 44, weight: .black, design: .serif))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.55), radius: 8, y: 4)
                        Text("A d20 adventure in the Iron Vale")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.78))
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.black.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(QuestboundTheme.border, lineWidth: 1)
                    }

                    TutorialTipView(tip: .mainMenu)

                    VStack(spacing: 12) {
                        if let recentSlot = saveStore.mostRecentlyPlayedSlot {
                            NavigationLink {
                                GreywickHubView(slotID: recentSlot.id)
                                    .onAppear {
                                        saveStore.markPlayed(slotID: recentSlot.id)
                                    }
                            } label: {
                                menuLabel("Continue", icon: "play.fill")
                            }
                        } else {
                            Button {
                                showCreatePrompt = true
                            } label: {
                                menuLabel("Continue", icon: "play.fill")
                            }
                        }

                        if let emptySlotID = saveStore.firstEmptySlotID {
                            NavigationLink {
                                HeroCreationView(slotID: emptySlotID)
                            } label: {
                                menuLabel("New Hero", icon: "person.crop.circle.badge.plus")
                            }
                        } else {
                            NavigationLink {
                                CharacterVaultView()
                            } label: {
                                menuLabel("New Hero", icon: "person.crop.circle.badge.plus")
                            }
                        }

                        NavigationLink {
                            CharacterVaultView()
                        } label: {
                            menuLabel("Character Vault", icon: "archivebox")
                        }

                        NavigationLink {
                            DiceRollerView()
                        } label: {
                            menuLabel("Dice Roller", icon: "die.face.5")
                        }

                        NavigationLink {
                            SettingsView()
                        } label: {
                            menuLabel("Settings", icon: "gearshape")
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Save v\(saveStore.saveVersion) • Game \(saveStore.gameVersion)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(24)
            }
            .alert("Create a Hero", isPresented: $showCreatePrompt) {
                if saveStore.firstEmptySlotID != nil {
                    Button("Create Hero") {
                        openCreateHero = true
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("No saved hero exists yet.")
            }
            .navigationDestination(isPresented: $openCreateHero) {
                if let emptySlotID = saveStore.firstEmptySlotID {
                    HeroCreationView(slotID: emptySlotID)
                } else {
                    CharacterVaultView()
                }
            }
            .navigationDestination(isPresented: $openCharacterVault) {
                CharacterVaultView()
            }
        }
    }

    private func menuLabel(_ title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(.primary)
        .padding(16)
        .background(
            LinearGradient(
                colors: [QuestboundTheme.card, Color.white.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }
}
