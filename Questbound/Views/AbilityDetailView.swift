import SwiftUI

struct AbilityDetailView: View {
    let ability: Ability

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(ability.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    detailCard {
                        detailRow("Action", ability.actionType.rawValue.capitalized)
                        if let cost = ability.cost {
                            detailRow("Cost", cost)
                        }
                        if let useLimit = ability.useLimit {
                            detailRow("Use Limit", useLimit)
                        }
                        let cooldown = AbilityRules.cooldownTurns(for: ability.id)
                        if cooldown > 0 {
                            detailRow("Cooldown", "\(cooldown) turn\(cooldown == 1 ? "" : "s")")
                        }
                        detailRow("Unlock Level", "\(ability.requiredLevel)")
                        if !ability.tags.isEmpty {
                            detailRow("Tags", ability.tags.joined(separator: ", "))
                        }
                    }

                    detailCard {
                        Text(ability.summary.isEmpty ? "Full ability data will be added in a later milestone." : AbilityRules.detailText(for: ability))
                            .foregroundStyle(.secondary)
                        Text(ability.actionType == .passive ? "Passive abilities are active at combat start and are recorded in the battle log." : "Combat abilities appear in battle when unlocked. Future versions can add ability loadouts and swapping.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Ability")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
