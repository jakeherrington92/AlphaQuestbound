import SwiftUI

struct AdventureBoardView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAbandonConfirm = false

    let slotID: Int

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TutorialTipView(tip: .adventureBoard)

                    if let hero, hero.currentAdventureState.isActive {
                        activeAdventureCard(hero)
                    }

                    ForEach(AdventureEngine.plannedAdventures) { adventure in
                        adventureCard(adventure)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Adventure Board")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Abandon Adventure?", isPresented: $showAbandonConfirm) {
            Button("Abandon", role: .destructive) {
                saveStore.abandonAdventure(slotID: slotID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will return to Greywick. XP and loot earned are kept, but completion rewards are not granted.")
        }
    }

    private func activeAdventureCard(_ hero: Hero) -> some View {
        let adventure = hero.currentAdventureState.adventureID.flatMap(AdventureEngine.adventure(id:))
        return boardCard("Current Adventure") {
            detailRow("Adventure", adventure?.title ?? "Unknown")
            detailRow("Room", AdventureEngine.currentRoom(for: hero)?.title ?? "Unknown")
            if let savedAt = hero.currentAdventureState.lastSavedAt {
                detailRow("Last Saved", savedAt.formatted(date: .abbreviated, time: .shortened))
            }

            HStack(spacing: 10) {
                NavigationLink {
                    AdventureRoomView(slotID: slotID, onExitToGreywick: {
                        dismiss()
                    })
                } label: {
                    Text("Continue Adventure")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(role: .destructive) {
                    showAbandonConfirm = true
                } label: {
                    Text("Abandon")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func adventureCard(_ adventure: AdventureDefinition) -> some View {
        let completed = hero?.currentAdventureState.completedAdventureIDs.contains(adventure.id) ?? false
        let unlocked = hero.map { AdventureEngine.isUnlocked(adventure, hero: $0) } ?? false
        let startable = !adventure.rooms.isEmpty && unlocked

        return boardCard(adventure.title) {
            detailRow("Recommended Level", adventure.id == "the-sunken-crypt" ? "2-3" : (adventure.id == "the-ember-cave" ? "3-4" : "\(adventure.recommendedLevel)"))
            if !adventure.rooms.isEmpty {
                detailRow("Length", adventure.id == "the-sunken-crypt" ? "10 rooms per route" : (adventure.id == "the-ember-cave" ? "12 rooms" : "\(adventure.rooms.count) rooms"))
            }
            detailRow("Difficulty", adventure.difficulty)
            detailRow("Theme", adventure.theme)
            Text(adventure.hook)
                .foregroundStyle(.secondary)
            detailRow("Reward Preview", adventure.rewardPreview)
            detailRow("Completion", completed ? "Completed" : "Not completed")
            detailRow("Unlock", unlocked ? "Unlocked" : adventure.unlockSummary)

            if startable {
                NavigationLink {
                    AdventureRoomView(slotID: slotID, startAdventureID: adventure.id, onExitToGreywick: {
                        dismiss()
                    })
                } label: {
                    Text(hero?.currentAdventureState.isActive == true ? "Start New Run" : "Start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(hero?.currentAdventureState.isActive == true)
            } else {
                Text(unlocked ? "Coming in a later milestone." : "Locked")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(unlocked ? Color.secondary : Color.red)
            }
        }
    }

    private func boardCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }
}
