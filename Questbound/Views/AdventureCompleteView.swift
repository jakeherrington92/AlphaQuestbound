import SwiftUI

struct AdventureCompleteView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int
    let adventure: AdventureDefinition
    let reward: AdventureCompletionReward

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                completeCard(adventure.title) {
                    if adventure.id == "the-sunken-crypt" {
                        Text("You have silenced the bell beneath the marsh. The Sunken Crypt sinks back into uneasy quiet, but the relics you found suggest older tombs still lie beneath Greywick.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else if adventure.id == "the-ember-cave" {
                        Text("You leave Ember Cave as the forge-light fades behind you. The Emberheart is broken, but the heat beneath Greywick has not gone cold. Somewhere deeper, older fires still wait.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    detailRow("XP Gained", "\(reward.xp)")
                    detailRow("Gold Gained", "\(reward.gold)")
                    detailRow("Completion", reward.isFirstCompletion ? "First completion" : "Replay")
                    if let hero {
                        detailRow("Hero Level", "\(hero.level)")
                        detailRow("Total XP", "\(hero.xp)")
                        detailRow("Total Gold", "\(hero.gold)")
                        detailRow("Current HP", "\(hero.currentHealth) / \(hero.maxHealth)")
                        if hero.maxFocus > 0 {
                            detailRow("Current Focus", "\(hero.currentFocus) / \(hero.maxFocus)")
                        }
                        if hero.maxStamina > 0 {
                            detailRow("Current Stamina", "\(hero.currentStamina) / \(hero.maxStamina)")
                        }
                    }
                    if reward.items.isEmpty {
                        detailRow("Items", "None")
                    } else {
                        ForEach(reward.items) { item in
                            detailRow(item.itemName, "x\(item.quantity)")
                        }
                    }
                    Text("You return to Greywick after a long rest. Shop stock refreshed, manual restocks reset, and a shop event roll was made.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    detailRow("Shop Event", saveStore.shopState.activeEvent?.name ?? "No active shop event")
                }

                NavigationLink {
                    GreywickHubView(slotID: slotID)
                        .navigationBarBackButtonHidden(true)
                } label: {
                    Text("Return to Greywick")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if let hero, LevelUpEngine.pendingNextLevel(for: hero) != nil {
                    NavigationLink {
                        LevelUpFlowView(slotID: slotID)
                    } label: {
                        Text("Level Up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Adventure Complete")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func completeCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
