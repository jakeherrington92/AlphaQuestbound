import SwiftUI

struct EnemyDetailView: View {
    let enemy: Enemy
    let currentHealth: Int
    var activeConditions: [Condition] = []

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    detailCard("Overview") {
                        Text(enemy.summary)
                            .foregroundStyle(.secondary)
                        detailRow("Family", enemy.family)
                        detailRow("Tier", enemy.tier.rawValue.capitalized)
                        detailRow("HP", "\(currentHealth) / \(enemy.maxHealth)")
                        detailRow("Defence", "\(enemy.defence)")
                        detailRow("Initiative", signed(enemy.initiativeBonus))
                        detailRow("Attack Bonus", signed(enemy.attackBonus))
                        detailRow("Damage", "\(enemy.damageExpression) \(enemy.damageType.rawValue)")
                    }

                    detailCard("Traits") {
                        detailRow("Resistances", keyedValues(enemy.resistances))
                        detailRow("Weaknesses", keyedValues(enemy.weaknesses))
                        detailRow("Immunities", enemy.immunities.isEmpty ? "None" : enemy.immunities.map(\.displayName).joined(separator: ", "))
                    }

                    detailCard("Active Conditions") {
                        if activeConditions.isEmpty {
                            Text("No active conditions.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(activeConditions) { condition in
                                NavigationLink {
                                    ConditionInfoView(condition: condition, targetName: enemy.name)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(condition.type.displayName)
                                            .fontWeight(.semibold)
                                        Text(condition.type.effectDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                if condition.id != activeConditions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    detailCard("Abilities") {
                        if enemy.abilities.isEmpty {
                            Text("No special abilities.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(enemy.abilities) { ability in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(ability.name)
                                        .fontWeight(.semibold)
                                    Text(ability.summary)
                                        .foregroundStyle(.secondary)
                                    Text(ability.actionType.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if ability.id != enemy.abilities.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }

                    detailCard("Rewards Preview") {
                        detailRow("XP", "\(enemy.xp)")
                        detailRow("Gold", "\(enemy.goldRange.lowerBound)-\(enemy.goldRange.upperBound)")
                        Text("Rewards are preview-only until the loot and XP milestone.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(enemy.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func keyedValues(_ values: [DamageType: Int]) -> String {
        guard !values.isEmpty else { return "None" }
        return values
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue.capitalized) \($0.value)" }
            .joined(separator: ", ")
    }

    private func detailCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
