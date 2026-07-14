import SwiftUI

struct ConditionInfoView: View {
    let condition: Condition
    var targetName: String?

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                conditionCard {
                    detailRow("Condition", condition.type.displayName)
                    if let targetName {
                        detailRow("Target", targetName)
                    }
                    detailRow("Effect", condition.type.effectDescription)
                    detailRow("Duration", durationText)
                    detailRow("Stacks", "No, unless a specific ability says otherwise.")
                    detailRow("Example Sources", condition.type.exampleSources)
                }
                Spacer()
            }
            .padding(20)
        }
        .navigationTitle(condition.type.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var durationText: String {
        if condition.type == .exposed {
            return "Expires at the end of your next turn."
        }
        guard let remainingTurns = condition.remainingTurns else {
            return "Until removed"
        }
        return remainingTurns == 1 ? "1 turn" : "\(remainingTurns) turns"
    }

    private func conditionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

private extension ConditionType {
    var exampleSources: String {
        switch self {
        case .bleeding: return "Raider blades, traps and dirty cuts."
        case .burning: return "Fire spells, ember hazards and flame beasts."
        case .poisoned: return "Tunnel Skitters, venom, tainted traps."
        case .slowed: return "Mud, snares, frost and tactical abilities."
        case .stunned: return "Heavy impacts, arcane disruption and boss powers."
        case .guarded: return "Defend action, shields and defensive abilities."
        case .marked: return "Hunter, oath and fire abilities that prime a target."
        case .weakened: return "Debuffs, oath pressure and dirty tricks."
        case .exposed: return "Precision strikes, frost magic and broken guard."
        case .knockedDown: return "Ground Slam, cave hazards and failed movement checks."
        }
    }
}
