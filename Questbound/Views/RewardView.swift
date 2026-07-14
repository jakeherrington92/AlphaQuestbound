import SwiftUI

struct RewardView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int
    let reward: CombatReward
    var onComplete: (() -> Void)?

    @State private var hasAppliedReward = false
    @State private var appliedHero: Hero?
    @State private var showLevelUp = false
    @State private var pendingGearPrompts: [ItemDefinition] = []
    @State private var activeGearPrompt: ItemDefinition?
    @State private var didCompleteRewardFlow = false

    private var hero: Hero? {
        appliedHero ?? saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    rewardCard("Rewards") {
                        detailRow("XP Gained", "\(reward.xp)")
                        detailRow("Gold Gained", "\(reward.totalGold)")
                        if let hero {
                            detailRow("Current XP After Reward", "\(hero.xp + (hasAppliedReward ? 0 : reward.xp))")
                            detailRow("Current Gold After Reward", "\(hero.gold + (hasAppliedReward ? 0 : reward.totalGold))")
                        }
                        levelReadyText
                    }

                    enemySummaryCard
                    itemRewardsCard

                    Button {
                        applyAndContinue()
                    } label: {
                        Text(hasAppliedReward ? "Continue" : "Accept Rewards")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
        }
        .navigationTitle("Victory Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showLevelUp) {
            LevelUpFlowView(slotID: slotID)
        }
        .sheet(item: $activeGearPrompt) { item in
            GearUpgradePromptView(slotID: slotID, item: item) {
                showNextGearPrompt()
            }
        }
    }

    private var enemySummaryCard: some View {
        rewardCard("Enemy Rewards") {
            ForEach(reward.enemySummaries) { summary in
                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.enemyName)
                        .fontWeight(.semibold)
                    Text("\(summary.tier.rawValue.capitalized) • \(summary.xp) XP • \(summary.gold) gold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if summary.id != reward.enemySummaries.last?.id {
                    Divider()
                }
            }
        }
    }

    private var itemRewardsCard: some View {
        rewardCard("Loot") {
            if reward.items.isEmpty {
                Text("No item drops this time.")
                    .foregroundStyle(.secondary)
            } else {
                groupedItems
            }
        }
    }

    private var groupedItems: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(ItemCategory.allCases) { category in
                let items = reward.items.filter { $0.category == category }
                if !items.isEmpty {
                    Text(category.displayName)
                        .font(.subheadline.weight(.semibold))
                    ForEach(items) { item in
                        rewardItemRow(item)
                    }
                }
            }
        }
    }

    private func rewardItemRow(_ item: RewardLineItem) -> some View {
        HStack(spacing: 10) {
            if let definition = ItemData.definition(named: item.itemName) {
                ItemIconPlaceholder(item: definition)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.itemName) x\(item.quantity)")
                    .font(.subheadline.weight(.semibold))
                Text("\(item.rarity.displayName) • \(item.category.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var levelReadyText: some View {
        if let hero,
           let nextXP = ProgressionRules.versionOne.xpRequired(for: hero.level + 1),
           hero.xp + (hasAppliedReward ? 0 : reward.xp) >= nextXP {
            Text("You have enough XP to level up.")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    private func applyAndContinue() {
        if !hasAppliedReward, let hero {
            var updated = LootEngine.applied(reward, to: hero)
            updated.combatState = nil
            updated.currentAdventureState.currentCombatState = nil
            saveStore.updateHero(updated, in: slotID)
            appliedHero = updated
            pendingGearPrompts = gearPrompts(for: reward, hero: updated)
            activeGearPrompt = pendingGearPrompts.first
            hasAppliedReward = true
            if activeGearPrompt == nil {
                finishRewardFlow(updated)
            }
        } else {
            dismiss()
        }
    }

    private func gearPrompts(for reward: CombatReward, hero: Hero) -> [ItemDefinition] {
        reward.items
            .compactMap { ItemData.definition(named: $0.itemName) }
            .filter { $0.isEquippable && ItemData.upgradePromptSlot(for: $0, hero: hero) != nil }
    }

    private func showNextGearPrompt() {
        if !pendingGearPrompts.isEmpty {
            pendingGearPrompts.removeFirst()
        }
        activeGearPrompt = pendingGearPrompts.first
        if activeGearPrompt == nil, let hero {
            finishRewardFlow(hero)
        }
    }

    private func finishRewardFlow(_ hero: Hero) {
        guard !didCompleteRewardFlow else { return }
        didCompleteRewardFlow = true
        onComplete?()
        if LevelUpEngine.pendingNextLevel(for: hero) != nil {
            showLevelUp = true
        }
    }

    private func rewardCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

struct GearUpgradePromptView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss
    @State private var comparisonItem: ItemDefinition?

    let slotID: Int
    let item: ItemDefinition
    let onClose: () -> Void

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("New Gear Upgrade Found")
                        .font(.title2.bold())
                    ItemDetailHeader(item: item)

                    if let hero {
                        let slot = ItemData.upgradePromptSlot(for: item, hero: hero)
                        let emptySlot = slot.flatMap { hero.equippedItems.slots[$0] } == nil
                        Text(comparisonText(slot: slot, emptySlot: emptySlot))
                            .font(.headline)
                            .foregroundStyle(QuestboundTheme.accent)
                        promptCard("Stat Improvements") {
                            Text(item.effectText.isEmpty ? "No listed stat effect." : item.effectText)
                                .foregroundStyle(.secondary)
                            if emptySlot, let slot {
                                Text("Empty \(slot.displayName) stats are treated as 0.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        promptCard("Details") {
                            detailRow("Effect", item.effectText)
                            detailRow("Build Fit", ItemData.buildFitSummary(for: item, hero: hero))
                            detailRow("Build Style", ItemData.buildStyleText(for: item))
                            detailRow("Value", "\(item.value) gold")
                            if let issue = ItemData.requirementIssue(for: item, hero: hero) {
                                detailRow("Requirement", issue)
                            }
                        }

                        Button {
                            comparisonItem = item
                        } label: {
                            Label("Compare Gear", systemImage: "info.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(QuestboundTheme.accent)

                        Button {
                            equipNow(hero: hero, slot: slot)
                        } label: {
                            Text("Equip Now")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(slot == nil || ItemData.requirementIssue(for: item, hero: hero) != nil)
                    }

                    Button {
                        close()
                    } label: {
                        Text("Keep in Backpack")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(20)
            }
        }
        .sheet(item: $comparisonItem) { item in
            ItemComparisonView(slotID: slotID, item: item)
        }
    }

    private func comparisonText(slot: EquipmentSlot?, emptySlot: Bool) -> String {
        guard let slot else { return "Incompatible with current hero." }
        return emptySlot ? "Better than Empty \(slot.displayName) Slot" : "Compare with equipped \(slot.displayName)"
    }

    private func equipNow(hero: Hero, slot: EquipmentSlot?) {
        guard let slot else { return }
        let updated = ItemData.equippedHero(hero, with: item, in: slot)
        saveStore.updateHero(updated, in: slotID)
        close()
    }

    private func close() {
        dismiss()
        onClose()
    }

    private func promptCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
