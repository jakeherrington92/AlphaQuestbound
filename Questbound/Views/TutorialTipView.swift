import SwiftUI

enum TutorialTip: String, CaseIterable, Identifiable {
    case mainMenu
    case greywick
    case inventory
    case shop
    case adventureBoard
    case adventureRoom
    case combat
    case bossFortune
    case levelUp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mainMenu: return "Getting Started"
        case .greywick: return "Greywick Hub"
        case .inventory: return "Inventory"
        case .shop: return "Shop"
        case .adventureBoard: return "Adventure Board"
        case .adventureRoom: return "Adventuring"
        case .combat: return "Combat"
        case .bossFortune: return "Boss Fortune"
        case .levelUp: return "Level Up"
        }
    }

    var message: String {
        switch self {
        case .mainMenu:
            return "Create a hero from New Hero or the Character Vault. Continue opens your most recently played hero."
        case .greywick:
            return "Greywick is your home base. Rest restores you, shops trade gear, and the Adventure Board starts quests."
        case .inventory:
            return "Equipped gear is marked in lists. Weapons, armour and charms can be changed from Change Equipment."
        case .shop:
            return "Buy prices can change during sale events. Merchant Demand improves gear sell values, but equipped items must be unequipped first."
        case .adventureBoard:
            return "Unlocked adventures can be started or resumed here. Abandoning keeps earned loot but skips completion rewards."
        case .adventureRoom:
            return "Use Save / Exit when leaving an adventure. Room rewards and completed combats are tracked to avoid duplicates."
        case .combat:
            return "Each hero turn allows one Quick Action and one Major Action. Defend boosts Defence until your next turn."
        case .bossFortune:
            return "A Fortune Roll is free and can double boss gold, but failure reduces that boss reward. It can only be attempted once."
        case .levelUp:
            return "Level-up choices are saved after confirmation. Subpath selection at Level 3 is permanent in Version 1."
        }
    }
}

struct TutorialTipView: View {
    @EnvironmentObject private var saveStore: SaveStore
    let tip: TutorialTip

    var body: some View {
        if !saveStore.settings.dismissedTutorialTips.contains(tip.id) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb")
                        .foregroundStyle(QuestboundTheme.accent)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tip.title)
                            .font(.subheadline.weight(.bold))
                        Text(tip.message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Button {
                    saveStore.dismissTutorialTip(tip.id)
                } label: {
                    Text("Got It")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(QuestboundTheme.card)
            .questboundParchmentText()
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(QuestboundTheme.border, lineWidth: 1)
            }
        }
    }
}
