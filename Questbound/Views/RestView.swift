import SwiftUI

struct RestView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var confirmationText: String?

    let slotID: Int

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Rest in Greywick")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    if let hero {
                        restCard {
                            detailRow("HP", "\(hero.currentHealth) / \(hero.maxHealth)")
                            if hero.maxFocus > 0 {
                                detailRow("Focus", "\(hero.currentFocus) / \(hero.maxFocus)")
                            }
                            if hero.maxStamina > 0 {
                                detailRow("Stamina", "\(hero.currentStamina) / \(hero.maxStamina)")
                            }
                        }

                        restCard {
                            Text("A Long Rest restores all HP, Focus or Stamina, and clears conditions.")
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            let wasFullyRested = saveStore.longRest(slotID: slotID)
                            confirmationText = wasFullyRested
                                ? "You are already fully rested."
                                : "You rest in Greywick. HP and your combat resource are fully restored."
                        } label: {
                            Label("Long Rest", systemImage: "bed.double")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(QuestboundTheme.accent)

                        if let confirmationText {
                            Text(confirmationText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.top, 4)
                        }
                    } else {
                        Text("No hero saved in this slot.")
                            .foregroundStyle(.white)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Rest")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func restCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
