import SwiftUI

struct BossRewardView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int
    let reward: CombatReward
    var onComplete: (() -> Void)?

    @State private var fortuneAttempted = false
    @State private var fortuneSkipped = false
    @State private var fortuneSucceeded = false
    @State private var fortuneRoll: Int?
    @State private var hasAppliedReward = false
    @State private var appliedHero: Hero?
    @State private var showLevelUp = false
    @State private var pendingFortuneTarget: Int?
    @State private var pendingGearPrompts: [ItemDefinition] = []
    @State private var activeGearPrompt: ItemDefinition?
    @State private var didCompleteRewardFlow = false

    private var hero: Hero? {
        appliedHero ?? saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    private var finalBossGold: Int {
        if fortuneSucceeded {
            return reward.bossGold * 2
        }
        if fortuneAttempted {
            return max(0, reward.bossGold - failedFortunePenalty)
        }
        return reward.bossGold
    }

    private var failedFortunePenalty: Int {
        guard reward.bossGold > 0 else { return 0 }
        return max(1, reward.bossGold * failurePenaltyPercent / 100)
    }

    private var failedFortuneGold: Int {
        max(0, reward.bossGold - failedFortunePenalty)
    }

    private var failurePenaltyPercent: Int {
        guard let hero else { return 25 }
        return LootEngine.hasFortuneKissedPendant(hero: hero) ? 15 : 25
    }

    private var finalTotalGold: Int {
        reward.nonBossGold + finalBossGold
    }

    private var canContinue: Bool {
        fortuneAttempted || fortuneSkipped || !reward.hasBossFortune
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TutorialTipView(tip: .bossFortune)
                    bossSummaryCard
                    fortuneCard
                    bossLootSections

                    Button {
                        applyAndContinue()
                    } label: {
                        Text(hasAppliedReward ? "Continue" : "Accept Boss Rewards")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canContinue)
                }
                .padding(20)
            }
        }
        .navigationTitle("Boss Rewards")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: restoreFortuneOutcome)
        .alert("Attempt Fortune Roll?", isPresented: Binding(
            get: { pendingFortuneTarget != nil },
            set: { if !$0 { pendingFortuneTarget = nil } }
        )) {
            Button("Roll Fortune") {
                if let target = pendingFortuneTarget {
                    attemptFortuneRoll(target: target)
                }
                pendingFortuneTarget = nil
            }
            Button("Cancel", role: .cancel) {
                pendingFortuneTarget = nil
            }
        } message: {
            Text("Success doubles boss gold. Failure reduces boss gold by \(failurePenaltyPercent)%. This roll is free and can only be attempted once.")
        }
        .navigationDestination(isPresented: $showLevelUp) {
            LevelUpFlowView(slotID: slotID)
        }
        .sheet(item: $activeGearPrompt) { item in
            GearUpgradePromptView(slotID: slotID, item: item) {
                showNextGearPrompt()
            }
        }
    }

    private var bossSummaryCard: some View {
        rewardCard(reward.bossName ?? "Boss") {
            detailRow("Boss XP", "\(reward.xp)")
            detailRow("Base Boss Gold", "\(reward.bossGold)")
            if reward.nonBossGold > 0 {
                detailRow("Other Gold", "\(reward.nonBossGold)")
            }
            detailRow("Final Gold", "\(finalTotalGold)")
            if let hero {
                detailRow("Current XP After Reward", "\(hero.xp + (hasAppliedReward ? 0 : reward.xp))")
                detailRow("Current Gold After Reward", "\(hero.gold + (hasAppliedReward ? 0 : finalTotalGold))")
            }
            levelReadyText
        }
    }

    private var fortuneCard: some View {
        rewardCard("Boss Fortune Roll") {
            if let hero {
                let target = LootEngine.fortuneTarget(for: hero)
                Text("Attempt a Fortune Roll. Success doubles boss gold. Failure reduces boss gold by \(failurePenaltyPercent)%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                detailRow("Boss Gold", "\(reward.bossGold) gold")
                detailRow("Success", "\(reward.bossGold * 2) gold")
                detailRow("Failure", "\(failedFortuneGold) gold")
                detailRow("Required Roll", "\(target)+")

                if fortuneAttempted {
                    detailRow("Roll", "\(fortuneRoll ?? 0)")
                    Text(fortuneResultText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(fortuneSucceeded ? .green : .secondary)
                } else if fortuneSkipped {
                    Text("Fortune Roll skipped.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Button {
                            pendingFortuneTarget = target
                        } label: {
                            Label("Roll Fortune", systemImage: "die.face.5")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Skip") {
                            fortuneSkipped = true
                            persistFortuneOutcome()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var fortuneResultText: String {
        if fortuneSucceeded {
            return "Fortune Roll succeeded. Boss gold doubled to \(reward.bossGold * 2)."
        }
        if failurePenaltyPercent == 15 {
            return "Fortune-Kissed Pendant softens the loss. Boss gold reduced by 15%. You receive \(failedFortuneGold) gold instead of \(reward.bossGold)."
        }
        return "Fortune Roll failed. Boss gold reduced by 25%. You receive \(failedFortuneGold) gold instead of \(reward.bossGold)."
    }

    private var bossLootSections: some View {
        Group {
            rewardItemsCard("Weapon Reward", items: reward.items.filter { $0.category == .weapon })
            rewardItemsCard("Armour Reward", items: reward.items.filter { $0.category == .armour })
            rewardItemsCard("Materials", items: reward.items.filter { $0.category == .material })
            rewardItemsCard(
                "Bonus Reward",
                items: reward.items.filter { ![.weapon, .armour, .material].contains($0.category) }
            )
        }
    }

    private func rewardItemsCard(_ title: String, items: [RewardLineItem]) -> some View {
        rewardCard(title) {
            if items.isEmpty {
                Text("No \(title.lowercased()) recorded.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    if let definition = ItemData.definition(named: item.itemName) {
                        HStack(alignment: .top, spacing: 10) {
                            ItemIconPlaceholder(item: definition)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(item.itemName) x\(item.quantity)")
                                    .font(.subheadline.weight(.semibold))
                                Text("\(item.rarity.displayName) • \(item.category.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let hero, definition.isEquippable {
                                    Text(ItemData.buildFitSummary(for: definition, hero: hero))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(QuestboundTheme.accent)
                                }
                                NavigationLink {
                                    ItemDetailView(slotID: slotID, item: definition)
                                } label: {
                                    Label(definition.isEquippable ? "Compare / Details" : "View Details", systemImage: "info.circle")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
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

    private func attemptFortuneRoll(target: Int) {
        guard !fortuneAttempted, !fortuneSkipped else { return }
        let roll = Int.random(in: 1...20)
        fortuneRoll = roll
        fortuneSucceeded = roll >= max(13, target)
        fortuneAttempted = true
        persistFortuneOutcome()
    }

    private var fortuneDefaultsKey: String {
        "questbound.boss-fortune.\(reward.id.uuidString)"
    }

    private func persistFortuneOutcome() {
        let outcome: [String: Any] = [
            "attempted": fortuneAttempted,
            "skipped": fortuneSkipped,
            "succeeded": fortuneSucceeded,
            "roll": fortuneRoll ?? 0
        ]
        UserDefaults.standard.set(outcome, forKey: fortuneDefaultsKey)
    }

    private func restoreFortuneOutcome() {
        guard let outcome = UserDefaults.standard.dictionary(forKey: fortuneDefaultsKey) else { return }
        fortuneAttempted = outcome["attempted"] as? Bool ?? false
        fortuneSkipped = outcome["skipped"] as? Bool ?? false
        fortuneSucceeded = outcome["succeeded"] as? Bool ?? false
        let storedRoll = outcome["roll"] as? Int ?? 0
        fortuneRoll = storedRoll > 0 ? storedRoll : nil
    }

    private func applyAndContinue() {
        guard canContinue else { return }
        if !hasAppliedReward, let hero {
            var updated = LootEngine.applied(reward, to: hero, finalBossGold: finalBossGold)
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
