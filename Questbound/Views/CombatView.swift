import SwiftUI

struct CombatView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int
    let encounterID: String
    let title: String
    let enemyIDs: [String]
    var onRewardComplete: (() -> Void)?
    var onDefeat: (() -> Void)?
    var onEscape: (() -> Void)?

    @State private var hero: Hero?
    @State private var combatState: CombatState?
    @State private var selectedEnemyID: UUID?
    @State private var message: String?
    @State private var victoryReward: CombatReward?
    @State private var rewardClaimed = false
    @State private var showCombatHelp = false
    @State private var selectedActionPanel: CombatActionPanel = .major
    @State private var showFullCombatLog = false
    @State private var outcomePopup: OutcomeResult?
    @State private var showAbandonAdventureConfirm = false
    @State private var returnToGreywick = false
    @State private var didNotifyRewardComplete = false
    @State private var completedAdventure: AdventureDefinition?
    @State private var completionReward: AdventureCompletionReward?

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero, let combatState {
                    VStack(alignment: .leading, spacing: 16) {
                        TutorialTipView(tip: .combat)
                        helpButton
                        heroCard(hero, state: combatState)
                        enemiesCard(combatState)
                        commandMenu
                        recentCombatLog(combatState)
                        combatLog(combatState)
                    }
                    .padding(20)
                } else {
                    Text("No combat loaded.")
                        .foregroundStyle(.white)
                        .padding(20)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadCombat)
        .alert("Combat", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .alert("Combat Help", isPresented: $showCombatHelp) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Choose a living enemy, then use one Quick Action and one Major Action each turn. Defend grants Guarded for +2 Defence. Flee attempts to escape and may provoke an enemy attack on failure.")
        }
        .alert("Abandon Adventure?", isPresented: $showAbandonAdventureConfirm) {
            Button("Abandon and Return", role: .destructive) {
                abandonAdventureAndReturnToGreywick()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will keep accepted combat rewards, but will not receive adventure completion rewards. The shop will not refresh and no gold penalty is applied.")
        }
        .navigationDestination(isPresented: $returnToGreywick) {
            GreywickHubView(slotID: slotID)
                .navigationBarBackButtonHidden(true)
        }
        .navigationDestination(item: $completedAdventure) { adventure in
            if let completionReward {
                AdventureCompleteView(slotID: slotID, adventure: adventure, reward: completionReward)
            }
        }
        .sheet(item: $outcomePopup) { outcome in
            OutcomePopupView(outcome: outcome) {
                outcomePopup = nil
            }
        }
    }

    private var helpButton: some View {
        Button {
            showCombatHelp = true
        } label: {
            Label("Combat Help", systemImage: "questionmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(QuestboundTheme.accent)
    }

    private func loadCombat() {
        guard hero == nil, combatState == nil,
              let savedHero = saveStore.slots.first(where: { $0.id == slotID })?.hero else { return }
        var loadedHero = savedHero
        var loadedState: CombatState
        if let savedCombat = savedHero.combatState,
           savedCombat.encounterID == encounterID,
           savedCombat.phase == .victory || savedCombat.isActive {
            loadedState = savedCombat
        } else {
            let modifiers = adventureCombatModifiers(hero: loadedHero)
            loadedState = CombatEngine.startCombat(
                hero: loadedHero,
                encounterID: encounterID,
                enemyIDs: enemyIDs,
                heroInitiativeBonus: modifiers.heroInitiative,
                enemyInitiativeBonus: modifiers.enemyInitiative
            )
            loadedState.pendingAttackBonus += modifiers.firstAttack
            loadedState.pendingDamageBonus += modifiers.firstDamage
            loadedState.temporaryDefenceBonus += modifiers.defence
            appendAdventureModifierLog(to: &loadedState, modifiers: modifiers)
            for condition in modifiers.heroConditions where !loadedState.activeConditions.contains(where: { $0.type == condition.type }) {
                loadedState.activeConditions.append(condition)
            }
            if let enemyCondition = modifiers.enemyCondition,
               let targetIndex = loadedState.enemies.firstIndex(where: { $0.currentHealth > 0 }) {
                loadedState.enemies[targetIndex].conditions.append(enemyCondition)
            }
            if loadedState.phase == .enemyTurn {
                CombatEngine.runEnemyTurn(hero: &loadedHero, state: &loadedState)
            } else {
                CombatEngine.beginHeroTurn(hero: &loadedHero, state: &loadedState)
            }
        }
        hero = loadedHero
        combatState = loadedState
        selectedEnemyID = loadedState.enemies.first(where: { $0.currentHealth > 0 })?.id
        prepareRewardIfNeeded(hero: loadedHero, state: loadedState)
        persistCombat(hero: loadedHero, state: loadedState)
    }

    private func adventureCombatModifiers(hero: Hero) -> (
        heroInitiative: Int,
        enemyInitiative: Int,
        firstAttack: Int,
        firstDamage: Int,
        defence: Int,
        heroConditions: [Condition],
        enemyCondition: Condition?
    ) {
        let flags = hero.currentAdventureState.temporaryBonuses
        var heroInitiative = 0
        var enemyInitiative = 0
        var firstAttack = 0
        var firstDamage = 0
        var defence = 0
        var heroConditions: [Condition] = []
        var enemyCondition: Condition?

        switch encounterID {
        case "crypt-restless-dead":
            heroInitiative += flags["cryptNextHeroInitiative", default: 0]
            enemyInitiative += flags["cryptFirstEnemyInitiative", default: 0]
            firstAttack += flags["cryptFirstAttackBonus", default: 0]
        case "crypt-bone-watch":
            heroInitiative += flags["cryptBoneWatchHeroInitiative", default: 0]
            enemyInitiative += flags["cryptBellRung", default: 0]
            firstAttack += flags["cryptNextAttackBonus", default: 0]
            defence += flags["cryptGraveward", default: 0]
            if flags["cryptStartSlowed"] == 1 {
                heroConditions.append(Condition(type: .slowed, remainingTurns: 2))
            }
            if flags["cryptStartExposed"] == 1 {
                heroConditions.append(Condition(type: .exposed, remainingTurns: 2))
            }
        case "crypt-bell-drowned-warden":
            heroInitiative += flags["cryptBossHeroInitiative", default: 0]
            enemyInitiative += flags["cryptBossEnemyInitiative", default: 0]
            if flags["cryptStartMarked"] == 1 {
                heroConditions.append(Condition(type: .marked, remainingTurns: 2))
            }
            if flags["cryptBossExposed"] == 1 {
                enemyCondition = Condition(type: .exposed, remainingTurns: 1)
            } else if flags["cryptBossWeakened"] == 1 {
                enemyCondition = Condition(type: .weakened, remainingTurns: 1)
            }
        case "ember-ash-beetle-nest":
            heroInitiative += flags["emberFirstHeroInitiative", default: 0]
            enemyInitiative += flags["emberFirstEnemyInitiative", default: 0]
        case "emberbound-patrol":
            if flags["emberVeinRoute"] == 1 {
                enemyInitiative += 1
            }
            if flags["coolingChannelCleared"] == 1 {
                enemyCondition = Condition(type: .exposed, remainingTurns: 2)
            }
            firstAttack += flags["forgeMarkingsStudied", default: 0]
        case "ember-furnace-hound":
            firstAttack += flags["forgeMarkingsStudied", default: 0]
            firstAttack += flags["bridgeSecured", default: 0]
            firstDamage += flags["emberBlessingDamage", default: 0]
            firstDamage += flags["emberBloodDamage", default: 0]
        case "emberheart-golem":
            firstAttack += flags["flameRhythmStudied", default: 0]
            firstDamage += flags["heatDrawn", default: 0]
            enemyInitiative += flags["restedBeforeBoss", default: 0]
            if flags["ventsOpened"] == 1 {
                enemyCondition = Condition(type: .exposed, remainingTurns: 2)
            }
        default:
            break
        }
        return (heroInitiative, enemyInitiative, firstAttack, firstDamage, defence, heroConditions, enemyCondition)
    }

    private func appendAdventureModifierLog(
        to state: inout CombatState,
        modifiers: (
            heroInitiative: Int,
            enemyInitiative: Int,
            firstAttack: Int,
            firstDamage: Int,
            defence: Int,
            heroConditions: [Condition],
            enemyCondition: Condition?
        )
    ) {
        if modifiers.heroInitiative > 0 {
            state.combatLog.append("Adventure bonus: you gain +\(modifiers.heroInitiative) initiative.")
        }
        if modifiers.enemyInitiative > 0 {
            state.combatLog.append("Adventure consequence: enemies gain +\(modifiers.enemyInitiative) initiative.")
        }
        if modifiers.firstAttack > 0 {
            state.combatLog.append("Adventure bonus: your next attack gains +\(modifiers.firstAttack) to hit.")
        }
        if modifiers.firstDamage > 0 {
            state.combatLog.append("Adventure bonus: your next damage gains +\(modifiers.firstDamage).")
        }
        if modifiers.defence > 0 {
            state.combatLog.append("Adventure bonus: you gain +\(modifiers.defence) Defence.")
        }
        for condition in modifiers.heroConditions {
            state.combatLog.append("Adventure consequence: you start with \(condition.type.displayName).")
        }
        if let enemyCondition = modifiers.enemyCondition {
            state.combatLog.append("Adventure bonus: the first enemy starts \(enemyCondition.type.displayName).")
        }
    }

    private func heroCard(_ hero: Hero, state: CombatState) -> some View {
        combatCard("Hero") {
            HStack(spacing: 12) {
                PortraitBadge(option: hero.portrait)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hero.name)
                        .font(.title3.bold())
                    Text("\(hero.origin.rawValue) \(hero.path.rawValue)")
                        .foregroundStyle(.secondary)
                }
            }

            detailRow("HP", "\(hero.currentHealth) / \(hero.maxHealth)")
            if hero.maxFocus > 0 {
                detailRow("Focus", "\(hero.currentFocus) / \(hero.maxFocus)")
            }
            if hero.maxStamina > 0 {
                detailRow("Stamina", "\(hero.currentStamina) / \(hero.maxStamina)")
            }
            detailRow("Defence", "\(CombatEngine.effectiveHeroDefence(hero: hero, state: state))")
            detailRow("Initiative", "\(state.heroInitiative)")
            conditionLinks(state.activeConditions, targetName: hero.name)

            switch state.phase {
            case .heroTurn:
                Text("Your turn")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            case .victory:
                Text("Victory")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                if rewardClaimed {
                    if onRewardComplete != nil {
                        Button(isFinalBossCombat ? "Complete Adventure" : "Continue Adventure") {
                            finishAdventureCombat()
                        }
                        .buttonStyle(.borderedProminent)

                        if !isFinalBossCombat {
                            Button(role: .destructive) {
                                showAbandonAdventureConfirm = true
                            } label: {
                                Text("Abandon Adventure")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Button("Return to Greywick") {
                            finishCombat()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if let victoryReward {
                    NavigationLink {
                        if victoryReward.hasBossFortune {
                            BossRewardView(slotID: slotID, reward: victoryReward) {
                                rewardClaimed = true
                                if isFinalBossCombat {
                                    saveStore.markFinalBossRewardsClaimed(slotID: slotID, encounterID: encounterID)
                                }
                            }
                        } else {
                            RewardView(slotID: slotID, reward: victoryReward) {
                                rewardClaimed = true
                                if isFinalBossCombat {
                                    saveStore.markFinalBossRewardsClaimed(slotID: slotID, encounterID: encounterID)
                                }
                            }
                        }
                    } label: {
                        Text(isFinalBossCombat ? "Claim Rewards" : "Collect Rewards")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("Preparing rewards...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            case .defeated:
                Text("Defeated")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                Button("Return to Greywick") {
                    finishCombat()
                }
                .buttonStyle(.borderedProminent)
            case .escaped:
                Text("Escaped")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                Button("Return to Greywick") {
                    finishCombat()
                }
                .buttonStyle(.borderedProminent)
            case .enemyTurn:
                Text("Enemy turn")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
    }

    private func enemiesCard(_ state: CombatState) -> some View {
        combatCard("Enemies") {
            ForEach(state.enemies) { enemyState in
                if let enemy = EnemyData.enemy(id: enemyState.enemyID) {
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            if enemyState.currentHealth > 0 {
                                selectedEnemyID = enemyState.id
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(enemy.name)
                                        .fontWeight(.semibold)
                                    Text("\(enemy.tier.rawValue.capitalized) • \(enemy.family)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedEnemyID == enemyState.id {
                                    Image(systemName: "target")
                                }
                            }
                            detailRow("HP", "\(enemyState.currentHealth) / \(enemy.maxHealth)")
                            detailRow("Defence", "\(CombatEngine.effectiveEnemyDefence(enemyState))")
                            }
                        }
                        .buttonStyle(.plain)

                        conditionLinks(enemyState.conditions, targetName: enemy.name)
                        NavigationLink {
                            EnemyDetailView(
                                enemy: enemy,
                                currentHealth: enemyState.currentHealth,
                                activeConditions: enemyState.conditions
                            )
                        } label: {
                            Label("Details", systemImage: "info.circle")
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedEnemyID == enemyState.id ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(enemyState.currentHealth > 0 ? 1 : 0.48)
                }
            }
        }
    }

    private var commandMenu: some View {
        combatCard("Actions") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                commandButton(.items, icon: "cross.case")
                commandButton(.quick, icon: "bolt")
                commandButton(.major, icon: "burst")
                commandButton(.flee, icon: "figure.run")
            }

            selectedActionPanelView
        }
    }

    private func commandButton(_ panel: CombatActionPanel, icon: String) -> some View {
        Button {
            selectedActionPanel = panel
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                Text(panel.title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .padding(.horizontal, 6)
            .background(selectedActionPanel == panel ? QuestboundTheme.accent.opacity(0.28) : Color.white.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedActionPanel == panel ? QuestboundTheme.accent.opacity(0.9) : QuestboundTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var selectedActionPanelView: some View {
        switch selectedActionPanel {
        case .items:
            itemsPanel
        case .quick:
            quickActionPanel
        case .major:
            majorActionPanel
        case .flee:
            fleePanel
        }
    }

    private var itemsPanel: some View {
        actionPanel(title: "Items") {
            ForEach(ownedCombatConsumables, id: \.name) { item in
                let count = hero?.inventory.itemQuantities[item.name] ?? 0
                let disabled = combatConsumableDisabledReason(item) != nil
                Button {
                    useCombatConsumable(item.name)
                } label: {
                    combatActionCard(
                        title: item.name,
                        meta: "x\(count) available",
                        status: combatConsumableStatus(item),
                        description: combatConsumableDescription(item),
                        isDisabled: disabled
                    )
                }
                .buttonStyle(.plain)
                .disabled(disabled)
            }

            if ownedCombatConsumables.isEmpty {
                emptyActionText("No combat consumables in your pack.")
            }
        }
    }

    private var quickActionPanel: some View {
        actionPanel(title: "Quick Actions") {
            ForEach(visibleQuickAbilities) { ability in
                abilityButton(ability)
            }

            if visibleQuickAbilities.isEmpty {
                emptyActionText("No quick abilities unlocked yet.")
            }
        }
    }

    private var majorActionPanel: some View {
        actionPanel(title: "Major Actions") {
            Button {
                basicAttack()
            } label: {
                combatActionCard(
                    title: primaryAttackLabel,
                    meta: "At-will",
                    status: canUseMajorAction && selectedEnemyID != nil ? "Ready" : majorUnavailableText,
                    description: primaryAttackDescription,
                    isDisabled: !canUseMajorAction || selectedEnemyID == nil
                )
            }
            .buttonStyle(.plain)
            .disabled(!canUseMajorAction || selectedEnemyID == nil)

            ForEach(visibleMajorAbilities) { ability in
                abilityButton(ability)
            }

            Button {
                defend()
            } label: {
                combatUtilityCard(
                    title: "Defend",
                    status: canUseMajorAction ? "Ready" : "Major Action already used",
                    description: "Gain +2 Defence until your next turn.",
                    isDisabled: !canUseMajorAction
                )
            }
            .buttonStyle(.plain)
            .disabled(!canUseMajorAction)

            Button {
                endTurn()
            } label: {
                combatUtilityCard(
                    title: "End Turn",
                    status: canUseMajorAction ? "Ready" : "Major Action already used",
                    description: "Pass the rest of your turn to the enemies.",
                    isDisabled: !canUseMajorAction
                )
            }
            .buttonStyle(.plain)
            .disabled(!canUseMajorAction)
        }
    }

    private var fleePanel: some View {
        actionPanel(title: "Flee") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Flee uses a Major Action. If you fail, the enemy attacks with advantage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    flee()
                } label: {
                    combatUtilityCard(
                    title: "Attempt Flee",
                    status: canUseMajorAction ? "Ready" : "Major Action already used",
                    description: "Attempt to escape. If you fail, the enemy attacks with advantage.",
                    isDisabled: !canUseMajorAction
                )
                }
                .buttonStyle(.plain)
                .disabled(!canUseMajorAction)
            }
        }
    }

    private func actionPanel<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                content()
            }
        }
        .padding(.top, 4)
    }

    private func combatLog(_ state: CombatState) -> some View {
        combatCard("Log Options") {
            DisclosureGroup(isExpanded: $showFullCombatLog) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(state.combatLog.suffix(20).reversed().enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .font(.footnote)
                        Divider()
                    }
                }
            } label: {
                Label("View Full Log", systemImage: "scroll")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func recentCombatLog(_ state: CombatState) -> some View {
        combatCard("Recent Log") {
            ForEach(Array(state.combatLog.suffix(6).reversed().enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .font(.footnote.weight(entry == state.combatLog.last ? .semibold : .regular))
            }
        }
    }

    private var canUseQuickAction: Bool {
        guard let combatState else { return false }
        return combatState.phase == .heroTurn && !combatState.hasUsedQuickAction && combatState.isActive
    }

    private var canUseMajorAction: Bool {
        guard let combatState else { return false }
        return combatState.phase == .heroTurn && !combatState.hasUsedMajorAction && combatState.isActive
    }

    private var majorUnavailableText: String {
        guard let combatState else { return "Unavailable" }
        if combatState.phase != .heroTurn || !combatState.isActive {
            return "Unavailable"
        }
        if combatState.hasUsedMajorAction {
            return "Major Action already used"
        }
        if selectedEnemyID == nil {
            return "No valid target"
        }
        return "Unavailable"
    }

    private var primaryAttackLabel: String {
        guard let hero else { return "Attack" }
        return CombatEngine.primaryAttackName(for: hero, state: combatState)
    }

    private var primaryAttackDescription: String {
        switch hero?.path {
        case .bladeguard:
            return "Melee attack. On hit, deal weapon damage and gain +1 Defence until your next turn."
        case .shadowstep:
            return "Precision attack. First use gains +2 to hit."
        case .wildwarden:
            return "Ranged attack. On hit, mark the enemy."
        case .embermage:
            return "Spell attack using Mind. On hit, deal 1d8 fire."
        case .oathkeeper:
            return "Melee attack. On hit, deal weapon damage plus oathfire."
        case nil:
            return "Attack with your equipped weapon."
        }
    }

    private var visibleQuickAbilities: [Ability] {
        guard let hero else { return [] }
        var abilities = hero.abilities.filter {
            $0.actionType == .quick && AbilityRules.isCombatAvailable($0)
        }
        if hero.maxStamina > 0 {
            abilities.append(AbilityRules.catchBreath)
        }
        return abilities
    }

    private var visibleMajorAbilities: [Ability] {
        hero?.abilities.filter { ability in
            ability.actionType == .major
                && !primaryAbilityIDs.contains(ability.id)
                && AbilityRules.isCombatAvailable(ability)
        } ?? []
    }

    private var primaryAbilityIDs: Set<String> {
        ["guarded-strike", "opening-strike", "marked-shot", "ember-bolt", "vowblade-strike"]
    }

    private var ownedCombatConsumables: [ItemDefinition] {
        guard let hero else { return [] }
        return hero.inventory.itemQuantities.keys
            .compactMap(ItemData.definition(named:))
            .filter { item in
                item.category == .consumable
                    && combatConsumableNames.contains(item.name)
                    && (hero.inventory.itemQuantities[item.name] ?? 0) > 0
                    && (!CombatEngine.staminaConsumableNames.contains(item.name) || hero.maxStamina > 0)
            }
            .sorted { lhs, rhs in
                combatConsumableNames.firstIndex(of: lhs.name) ?? Int.max < combatConsumableNames.firstIndex(of: rhs.name) ?? Int.max
            }
    }

    private var combatConsumableNames: [String] {
        CombatEngine.healingConsumableNames
            + CombatEngine.staminaConsumableNames
            + ["Fire Oil", "Antivenom", "Focus Tonic", "Smoke Powder", "Stone Salve", "Flash Dust", "Wardstone Shard"]
    }

    private func abilityButton(_ ability: Ability) -> some View {
        let disabled = isAbilityDisabled(ability)
        return Button {
            useAbility(ability)
        } label: {
            abilityActionCard(ability, isDisabled: disabled)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func abilityActionCard(_ ability: Ability, isDisabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(ability.name)
                .font(.subheadline.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
            Text(abilityCategoryText(ability))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Cost: \(abilityCostText(ability))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Cooldown: \(abilityCooldownText(ability))")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if ability.id == "elemental-flask" {
                Text(elementalFlaskUsesText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if let useLimit = ability.useLimit {
                Text(useLimit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let pattern = ability.targetPattern {
                Text("Targets: \(pattern.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(abilityStatusText(ability))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDisabled ? .secondary : QuestboundTheme.accent)
                .fixedSize(horizontal: false, vertical: true)
            Text(abilityDescriptionText(ability))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(isDisabled ? Color.gray.opacity(0.16) : Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDisabled ? Color.gray.opacity(0.32) : QuestboundTheme.border, lineWidth: 1)
        }
        .opacity(isDisabled ? 0.62 : 1)
    }

    private func combatActionCard(title: String, meta: String, status: String, description: String, isDisabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(meta)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDisabled ? .secondary : QuestboundTheme.accent)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 106, alignment: .topLeading)
        .background(isDisabled ? Color.gray.opacity(0.16) : Color.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDisabled ? Color.gray.opacity(0.32) : QuestboundTheme.border, lineWidth: 1)
        }
        .opacity(isDisabled ? 0.62 : 1)
    }

    private func combatUtilityCard(title: String, status: String, description: String, isDisabled: Bool) -> some View {
        combatActionCard(title: title, meta: "Utility", status: status, description: description, isDisabled: isDisabled)
    }

    private func emptyActionText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func potionStatusText(_ count: Int) -> String {
        guard let combatState else { return "Unavailable" }
        if count == 0 {
            return "No potion available"
        }
        if combatState.phase != .heroTurn || !combatState.isActive {
            return "Unavailable"
        }
        if combatState.hasUsedQuickAction {
            return "Quick Action already used"
        }
        return "Ready"
    }

    private func combatConsumableStatus(_ item: ItemDefinition) -> String {
        combatConsumableDisabledReason(item) ?? "Ready"
    }

    private func combatConsumableDisabledReason(_ item: ItemDefinition) -> String? {
        guard let hero, let combatState else { return "Unavailable" }
        let count = hero.inventory.itemQuantities[item.name] ?? 0
        if count == 0 { return "None available" }
        if combatState.phase != .heroTurn || !combatState.isActive { return "Unavailable" }
        if combatState.hasUsedQuickAction { return "Quick Action already used" }
        if combatState.hasUsedConsumable { return "Consumable already used" }
        switch item.name {
        case "Fire Oil":
            return !combatState.pendingFireOilBonus && combatState.pendingElementalFlask == nil
                ? nil
                : "Weapon coating active"
        case let name where CombatEngine.staminaConsumableNames.contains(name):
            if hero.currentStamina >= hero.maxStamina { return "Stamina full" }
            if hero.currentAdventureState.isActive,
               hero.currentAdventureState.staminaDraughtUses >= GameConstants.maxStaminaDraughtUsesPerAdventure {
                return "Adventure limit reached"
            }
            return nil
        case "Antivenom":
            return combatState.activeConditions.contains(where: { $0.type == .poisoned }) ? nil : "Not needed"
        case "Focus Tonic":
            if hero.maxFocus <= 0 { return "No Focus pool" }
            return hero.currentFocus < hero.maxFocus ? nil : "Focus full"
        case "Smoke Powder", "Stone Salve", "Flash Dust", "Wardstone Shard":
            return "Future-ready"
        default:
            return nil
        }
    }

    private func combatConsumableDescription(_ item: ItemDefinition) -> String {
        switch item.name {
        case let name where CombatEngine.staminaConsumableNames.contains(name):
            let effect = item.effectText.replacingOccurrences(of: "Restores", with: "Restore")
            if let hero, hero.currentAdventureState.isActive {
                return "\(effect) Uses this adventure: \(hero.currentAdventureState.staminaDraughtUses) / \(GameConstants.maxStaminaDraughtUsesPerAdventure)."
            }
            return "\(effect) Adventure limit: \(GameConstants.maxStaminaDraughtUsesPerAdventure) uses."
        case "Fire Oil":
            return "Next weapon hit deals +1d4 fire."
        case "Antivenom":
            return "Remove Poisoned."
        case "Focus Tonic":
            return "Restore 1 Focus."
        case "Smoke Powder":
            return "+2 next Flee/Stealth. Full combat support later."
        case "Stone Salve":
            return "Remove Knocked Down and gain Defence. Full support later."
        case "Flash Dust":
            return "Apply Exposed. Full support later."
        case "Wardstone Shard":
            return "Reduce next damage by 1d8. Full support later."
        default:
            return item.effectText.replacingOccurrences(of: "Restores", with: "Restore")
        }
    }

    private func abilityCostText(_ ability: Ability) -> String {
        let cost = AbilityRules.resourceCost(for: ability)
        switch AbilityRules.resourceType(for: ability) {
        case .stamina where cost > 0: return "\(cost) Stamina"
        case .focus where cost > 0: return "\(cost) Focus"
        default: return "None"
        }
    }

    private func abilityCooldownText(_ ability: Ability) -> String {
        let cooldown = AbilityRules.cooldownTurns(for: ability)
        guard cooldown > 0 else { return "None" }
        return "\(cooldown) turn\(cooldown == 1 ? "" : "s")"
    }

    private func abilityCategoryText(_ ability: Ability) -> String {
        if ability.id == "cinder-mark" { return "Quick Setup" }
        if ability.techniqueType == .buff { return "Quick Technique • Buff" }
        if ability.techniqueType == .debuff { return "Quick Technique • Debuff" }
        if ability.actionType == .passive { return "Passive" }
        if ability.damageType != nil {
            switch ability.id {
            case "frost-snare", "burning-surge", "starfall-pulse", "cinder-burst", "astral-cascade", "dawnwave", "radiant-judgement":
                return "Major Spell"
            case "bastion-sweep", "whirlwind-cut", "shadow-chain", "scatterknives", "pack-assault", "piercing-volley":
                return "Major Weapon Ability"
            default:
                return "Weapon Attack"
            }
        }
        return "Utility"
    }

    private func abilityStatusText(_ ability: Ability) -> String {
        guard let hero, let combatState else { return "Unavailable" }
        let cooldown = combatState.abilityCooldowns[ability.id] ?? 0
        if cooldown > 0 {
            return "Cooldown: \(cooldown) turn\(cooldown == 1 ? "" : "s") remaining"
        }
        let cost = AbilityRules.resourceCost(for: ability)
        if AbilityRules.resourceType(for: ability) == .stamina, hero.currentStamina < cost {
            return "Not enough Stamina"
        }
        if AbilityRules.resourceType(for: ability) == .focus, hero.currentFocus < cost {
            return "Not enough Focus"
        }
        if ability.id == "catch-breath", hero.currentStamina >= hero.maxStamina {
            return "Stamina full"
        }
        if ability.id == "elemental-flask" {
            if combatState.pendingFireOilBonus || combatState.pendingElementalFlask != nil {
                return "Weapon coating already active"
            }
            if hero.currentAdventureState.isActive,
               hero.currentAdventureState.elementalFlaskUses >= GameConstants.maxElementalFlaskUsesPerAdventure {
                return "No Elemental Flask uses remaining"
            }
        }
        if ability.actionType == .passive {
            return "Passive"
        }
        if ability.targetType == .enemy, selectedEnemyID == nil {
            return "No valid target"
        }
        if ability.actionType == .quick, combatState.hasUsedQuickAction {
            return "Quick Action already used"
        }
        if ability.actionType == .major, combatState.hasUsedMajorAction {
            return "Major Action already used"
        }
        return "Ready"
    }

    private func abilityDescriptionText(_ ability: Ability) -> String {
        switch ability.id {
        case "guarded-strike":
            return "Melee attack. On hit, deal weapon damage and gain +1 Defence until your next turn."
        case "cleaving-blow":
            return "Melee attack. If this defeats an enemy, half damage carries to another enemy."
        case "relentless-assault":
            return "On hit, deal weapon damage +1d8 physical."
        case "tempest-step":
            return "Your next melee attack gains +1 to hit and +1 damage."
        case "elemental-flask":
            return "3 uses/adventure. Next weapon hit deals +1d4 random elemental damage."
        case "frost-snare":
            return "Spell attack using Mind. On hit, deal 1d6 frost and apply Exposed until the end of your next turn."
        case "kindled-focus":
            return "Restore 1 Focus. At full Focus, empower your next fire spell."
        case "cinder-mark":
            return "Setup: next successful fire spell against this enemy deals +1d6 fire."
        case "catch-breath":
            return "Regain your footing. Restore 1 Stamina."
        case "defend":
            return "Gain +2 Defence until your next turn."
        default:
            return ability.summary
                .replacingOccurrences(of: "Major Action. ", with: "")
                .replacingOccurrences(of: "Quick Action. ", with: "")
                .replacingOccurrences(of: "Passive. ", with: "")
        }
    }

    private func isAbilityDisabled(_ ability: Ability) -> Bool {
        guard let hero, let combatState else { return true }
        if combatState.phase != .heroTurn { return true }
        if ability.actionType == .quick, combatState.hasUsedQuickAction { return true }
        if ability.actionType == .major, combatState.hasUsedMajorAction { return true }
        if ability.actionType == .major, selectedEnemyID == nil { return true }
        if ability.targetType == .enemy, selectedEnemyID == nil { return true }
        if (combatState.abilityCooldowns[ability.id] ?? 0) > 0 { return true }
        let cost = AbilityRules.resourceCost(for: ability)
        if AbilityRules.resourceType(for: ability) == .stamina, hero.currentStamina < cost { return true }
        if AbilityRules.resourceType(for: ability) == .focus, hero.currentFocus < cost { return true }
        if ability.id == "catch-breath", hero.currentStamina >= hero.maxStamina { return true }
        if ability.id == "elemental-flask" {
            if combatState.pendingFireOilBonus || combatState.pendingElementalFlask != nil { return true }
            if hero.currentAdventureState.isActive,
               hero.currentAdventureState.elementalFlaskUses >= GameConstants.maxElementalFlaskUsesPerAdventure {
                return true
            }
        }
        return false
    }

    private var elementalFlaskUsesText: String {
        guard let hero, hero.currentAdventureState.isActive else {
            return "Uses: adventure limit applies"
        }
        let remaining = max(
            0,
            GameConstants.maxElementalFlaskUsesPerAdventure - hero.currentAdventureState.elementalFlaskUses
        )
        return "Uses remaining: \(remaining) / \(GameConstants.maxElementalFlaskUsesPerAdventure)"
    }

    private var placeholderHero: Hero {
        Hero(
            name: "",
            origin: .hearthborn,
            path: .bladeguard,
            portrait: .bladeguardBaseMale,
            attributes: Attributes()
        )
    }

    private func usePotion() {
        useHealingItem("Minor Healing Draught")
    }

    private func useHealingItem(_ itemName: String) {
        useCombatConsumable(itemName)
    }

    private func useCombatConsumable(_ itemName: String) {
        guard var hero, var state = combatState else { return }
        let previousLogCount = state.combatLog.count
        if let issue = CombatEngine.useCombatConsumable(itemName, hero: &hero, state: &state) {
            message = issue
        }
        self.hero = hero
        combatState = state
        showCombatOutcome(title: "\(itemName) Used", previousLogCount: previousLogCount, state: state)
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func basicAttack() {
        guard var hero, var state = combatState, let selectedEnemyID else { return }
        let previousLogCount = state.combatLog.count
        let actionTitle = primaryAttackLabel
        if let issue = CombatEngine.basicAttack(hero: &hero, state: &state, targetID: selectedEnemyID) {
            message = issue
        }
        self.hero = hero
        combatState = state
        showCombatOutcome(title: actionTitle, previousLogCount: previousLogCount, state: state)
        self.selectedEnemyID = state.enemies.first(where: { $0.id == selectedEnemyID && $0.currentHealth > 0 })?.id
            ?? state.enemies.first(where: { $0.currentHealth > 0 })?.id
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func cleavingBlow() {
        guard var hero, var state = combatState, let selectedEnemyID else { return }
        if let issue = CombatEngine.cleavingBlow(hero: &hero, state: &state, targetID: selectedEnemyID) {
            message = issue
        }
        self.hero = hero
        combatState = state
        self.selectedEnemyID = state.enemies.first(where: { $0.id == selectedEnemyID && $0.currentHealth > 0 })?.id
            ?? state.enemies.first(where: { $0.currentHealth > 0 })?.id
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func useAbility(_ ability: Ability) {
        guard var hero, var state = combatState else { return }
        let previousLogCount = state.combatLog.count
        if let issue = CombatEngine.useAbility(ability, hero: &hero, state: &state, targetID: selectedEnemyID) {
            message = issue
        }
        self.hero = hero
        combatState = state
        showCombatOutcome(title: ability.name, previousLogCount: previousLogCount, state: state)
        if let selectedEnemyID {
            self.selectedEnemyID = state.enemies.first(where: { $0.id == selectedEnemyID && $0.currentHealth > 0 })?.id
                ?? state.enemies.first(where: { $0.currentHealth > 0 })?.id
        }
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func defend() {
        guard var hero, var state = combatState else { return }
        let previousLogCount = state.combatLog.count
        if let issue = CombatEngine.defend(hero: &hero, state: &state) {
            message = issue
        }
        self.hero = hero
        combatState = state
        showCombatOutcome(title: "Defend", previousLogCount: previousLogCount, state: state)
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func flee() {
        guard var hero, var state = combatState else { return }
        let previousLogCount = state.combatLog.count
        if let issue = CombatEngine.flee(hero: &hero, state: &state) {
            message = issue
        }
        self.hero = hero
        combatState = state
        showCombatOutcome(title: state.phase == .escaped ? "Flee Successful" : "Flee Failed", previousLogCount: previousLogCount, state: state)
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func endTurn() {
        guard var hero, var state = combatState else { return }
        let previousLogCount = state.combatLog.count
        state.hasUsedMajorAction = true
        state.combatLog.append("You end your turn.")
        CombatEngine.runEnemyTurn(hero: &hero, state: &state)
        self.hero = hero
        combatState = state
        showCombatOutcome(title: "Enemy Turn", previousLogCount: previousLogCount, state: state)
        prepareRewardIfNeeded(hero: hero, state: state)
        persistCombat(hero: hero, state: state)
    }

    private func showCombatOutcome(title: String, previousLogCount: Int, state: CombatState) {
        let newEntries = Array(state.combatLog.dropFirst(previousLogCount))
        guard !newEntries.isEmpty else { return }
        let sections = combatOutcomeSections(actionTitle: title, entries: newEntries, state: state)
        let hasEnemySection = sections.contains { $0.title.hasPrefix("Enemy") }
        outcomePopup = OutcomeResult(
            title: hasEnemySection ? "Combat Result" : title,
            mainResult: hasEnemySection ? "The exchange resolves." : newEntries.first ?? title,
            details: sections.isEmpty ? Array(newEntries.dropFirst()) : [],
            sections: sections
        )
    }

    private func combatOutcomeSections(actionTitle: String, entries: [String], state: CombatState) -> [OutcomeSection] {
        let enemyNames = state.enemies.compactMap { EnemyData.enemy(id: $0.enemyID)?.name }
        let enemyStartIndex = entries.firstIndex { entry in
            if entry.hasPrefix("Drowned Toll") {
                return true
            }
            return enemyNames.contains { name in
                entry.hasPrefix("\(name) attacks:")
                    || entry.hasPrefix("\(name) uses")
                    || entry.hasPrefix("\(name) deals")
                    || entry.hasPrefix("\(name) lands")
            }
        }

        let playerLines: [String]
        let enemyLines: [String]
        if let enemyStartIndex {
            playerLines = Array(entries[..<enemyStartIndex])
            enemyLines = Array(entries[enemyStartIndex...])
        } else {
            playerLines = entries
            enemyLines = []
        }

        var sections: [OutcomeSection] = []
        if !playerLines.isEmpty {
            sections.append(OutcomeSection(title: playerSectionTitle(actionTitle: actionTitle, lines: playerLines), lines: playerLines))
        }

        if !enemyLines.isEmpty {
            var lines = enemyLines
            if enemyLines.contains(where: { $0.contains("Miss.") }) && !enemyLines.contains(where: { $0.contains("Hit.") || $0.contains("deals") }) {
                lines.append("No damage taken.")
            }
            sections.append(OutcomeSection(title: enemySectionTitle(lines: enemyLines), lines: lines))
        } else if state.phase == .victory {
            sections.append(OutcomeSection(title: "Enemy Turn: Enemy defeated", lines: ["No enemies acted."]))
        }

        sections.append(OutcomeSection(title: "Result", lines: combatResultLines(state: state)))
        return sections
    }

    private func playerSectionTitle(actionTitle: String, lines: [String]) -> String {
        if actionTitle.localizedCaseInsensitiveContains("Draught") { return "Your Action: Potion Used" }
        if actionTitle == "Defend" { return "Your Action: Defend" }
        if actionTitle.localizedCaseInsensitiveContains("Flee") { return "Your Action: Flee Attempt" }
        if lines.contains(where: { $0.contains("Hit.") }) { return "Your Attack: Hit" }
        if lines.contains(where: { $0.contains("Miss.") }) { return "Your Attack: Miss" }
        return "Your Action: \(actionTitle)"
    }

    private func enemySectionTitle(lines: [String]) -> String {
        if lines.contains(where: { $0.hasPrefix("Drowned Toll") }) {
            return "Drowned Toll"
        }
        let attackCount = lines.filter { $0.contains(" attacks:") || $0.contains(" uses Ground Slam") }.count
        if attackCount > 1 { return "Enemy Turn" }
        if lines.contains(where: { $0.contains("Hit.") || $0.contains("deals") }) { return "Enemy Attack: Hit" }
        if lines.contains(where: { $0.contains("Miss.") }) { return "Enemy Attack: Miss" }
        return "Enemy Turn"
    }

    private func combatResultLines(state: CombatState) -> [String] {
        switch state.phase {
        case .victory:
            return ["Combat won. Collect your rewards."]
        case .defeated:
            return ["You were defeated."]
        case .escaped:
            return ["You escaped the fight."]
        case .heroTurn:
            return ["Your turn begins."]
        case .enemyTurn:
            return ["Enemy turn continues."]
        }
    }

    private func finishCombat() {
        if rewardClaimed {
            dismiss()
            return
        }
        if var hero {
            hero.combatState = nil
            hero.currentAdventureState.currentCombatState = nil
            saveStore.updateHero(hero, in: slotID)
        }
        if combatState?.phase == .defeated {
            onDefeat?()
            if onDefeat != nil {
                returnToGreywick = true
                return
            }
        }
        if combatState?.phase == .escaped {
            onEscape?()
            if onEscape != nil {
                returnToGreywick = true
                return
            }
        }
        dismiss()
    }

    private func abandonAdventureAndReturnToGreywick() {
        outcomePopup = nil
        message = nil
        saveStore.abandonAdventure(slotID: slotID)
        if var hero {
            hero.currentAdventureState = saveStore.slots.first(where: { $0.id == slotID })?.hero?.currentAdventureState ?? hero.currentAdventureState
            hero.combatState = nil
            self.hero = hero
        }
        returnToGreywick = true
    }

    private var isFinalBossCombat: Bool {
        guard onRewardComplete != nil,
              let activeHero = hero ?? saveStore.slots.first(where: { $0.id == slotID })?.hero,
              let room = AdventureEngine.currentRoom(for: activeHero) else { return false }
        return room.type == .boss && room.nextRoomID == nil && room.id == encounterID
    }

    private func finishAdventureCombat() {
        guard !didNotifyRewardComplete else { return }
        didNotifyRewardComplete = true
        if isFinalBossCombat || AdventureEngine.hasPendingAdventureCompletion(
            saveStore.slots.first(where: { $0.id == slotID })?.hero ?? placeholderHero
        ) {
            guard let result = saveStore.completeFinalBossAdventure(slotID: slotID, encounterID: encounterID) else {
                didNotifyRewardComplete = false
                message = "Adventure completion could not be finalised. Your progress remains saved."
                return
            }
            completionReward = result.1
            completedAdventure = result.0
            return
        }
        onRewardComplete?()
        dismiss()
    }

    private func prepareRewardIfNeeded(hero: Hero, state: CombatState) {
        guard state.phase == .victory, victoryReward == nil else { return }
        victoryReward = LootEngine.reward(for: hero, encounterID: encounterID, enemyIDs: enemyIDs)
    }

    private func persistCombat(hero: Hero, state: CombatState) {
        var updatedHero = hero
        updatedHero.combatState = state
        if updatedHero.currentAdventureState.isActive {
            updatedHero.currentAdventureState.currentCombatState = state
        }
        saveStore.updateHero(updatedHero, in: slotID)
    }

    private func conditionLinks(_ conditions: [Condition], targetName: String) -> some View {
        Group {
            if conditions.isEmpty {
                detailRow("Conditions", "None")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Conditions")
                        .foregroundStyle(.secondary)
                    FlowConditionLinks(conditions: conditions, targetName: targetName)
                }
            }
        }
    }

    private func combatCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

private struct FlowConditionLinks: View {
    let conditions: [Condition]
    let targetName: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
            ForEach(conditions) { condition in
                NavigationLink {
                    ConditionInfoView(condition: condition, targetName: targetName)
                } label: {
                    Text(condition.type.displayName)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum CombatActionPanel {
    case items
    case quick
    case major
    case flee

    var title: String {
        switch self {
        case .items:
            return "Items"
        case .quick:
            return "Quick"
        case .major:
            return "Major"
        case .flee:
            return "Flee"
        }
    }
}

struct OutcomeResult: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var mainResult: String
    var rollBreakdown: String?
    var details: [String]
    var rewards: [String]
    var consequences: [String]
    var sections: [OutcomeSection]

    init(
        title: String,
        mainResult: String,
        rollBreakdown: String? = nil,
        details: [String] = [],
        rewards: [String] = [],
        consequences: [String] = [],
        sections: [OutcomeSection] = []
    ) {
        self.title = title
        self.mainResult = mainResult
        self.rollBreakdown = rollBreakdown
        self.details = details
        self.rewards = rewards
        self.consequences = consequences
        self.sections = sections
    }
}

struct OutcomeSection: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var lines: [String]
}

struct OutcomePopupView: View {
    let outcome: OutcomeResult
    let onClose: () -> Void

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(outcome.title)
                        .font(.title2.bold())
                    Text(outcome.mainResult)
                        .foregroundStyle(.secondary)

                    if let rollBreakdown = outcome.rollBreakdown {
                        outcomeSection("Roll", lines: [rollBreakdown])
                    }
                    if !outcome.sections.isEmpty {
                        ForEach(outcome.sections) { section in
                            outcomeSection(section.title, lines: section.lines)
                        }
                    }
                    if !outcome.details.isEmpty {
                        outcomeSection("Result", lines: outcome.details)
                    }
                    if !outcome.rewards.isEmpty {
                        outcomeSection("Rewards", lines: outcome.rewards)
                    }
                    if !outcome.consequences.isEmpty {
                        outcomeSection("Consequences", lines: outcome.consequences)
                    }

                    Button {
                        onClose()
                    } label: {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(QuestboundTheme.card)
                .questboundParchmentText()
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(QuestboundTheme.border, lineWidth: 1)
                }
                .padding(20)
            }
        }
    }

    private func outcomeSection(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
