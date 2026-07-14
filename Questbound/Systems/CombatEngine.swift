import Foundation

struct DamageRollResult: Equatable {
    var expression: String
    var dice: [Int]
    var flatModifier: Int
    var attributeModifier: Int
    var total: Int
    var damageType: DamageType

    var summary: String {
        let diceText = dice.map(String.init).joined(separator: ", ")
        let modifierTotal = flatModifier + attributeModifier
        let modifierText = modifierTotal == 0 ? "" : " \(modifierTotal > 0 ? "+" : "-") \(abs(modifierTotal))"
        return "\(expression) [\(diceText)]\(modifierText) = \(total) \(damageType.rawValue) damage"
    }
}

private struct DamageAdjustment {
    var label: String
    var amount: Int
}

private struct DamageResolution {
    var finalDamage: Int
    var breakdownLines: [String]
}

enum CombatEngine {
    static func primaryAttackName(for hero: Hero, state: CombatState? = nil) -> String {
        if hero.path == .shadowstep, state?.usedAbilityIDs.contains("opening-strike") == true {
            return "Weapon Attack"
        }
        switch hero.path {
        case .bladeguard: return "Guarded Strike"
        case .shadowstep: return "Opening Strike"
        case .wildwarden: return "Marked Shot"
        case .embermage: return "Ember Bolt"
        case .oathkeeper: return "Vowblade Strike"
        }
    }

    static func startCombat(
        hero: Hero,
        encounterID: String,
        enemyIDs: [String],
        heroInitiativeBonus: Int = 0,
        enemyInitiativeBonus: Int = 0
    ) -> CombatState {
        let enemies = enemyIDs.compactMap { EnemyData.enemy(id: $0) }
        let enemyStates = enemies.map { enemy in
            CombatEnemyState(enemyID: enemy.id, currentHealth: enemy.maxHealth)
        }
        var enemyInitiatives: [UUID: Int] = [:]
        for enemyState in enemyStates {
            let enemy = EnemyData.enemy(id: enemyState.enemyID)
            enemyInitiatives[enemyState.id] = Int.random(in: 1...20) + (enemy?.initiativeBonus ?? 0) + enemyInitiativeBonus
        }

        let equipmentInitiative = ItemData.initiativeBonus(for: hero)
        let heroInitiative = Int.random(in: 1...20)
            + hero.attributes.modifier(for: .agility)
            + equipmentInitiative
            + heroInitiativeBonus
        let firstEnemyInitiative = enemyInitiatives.values.max() ?? 0
        let heroStarts = heroInitiative >= firstEnemyInitiative

        var log = [
            "Combat begins.",
            "You roll initiative \(heroInitiative) including \(equipmentInitiative >= 0 ? "+" : "")\(equipmentInitiative) from equipment. Enemies highest initiative \(firstEnemyInitiative)."
        ]
        for passive in hero.abilities.filter({
            $0.actionType == .passive && AbilityRules.implementationStatus(for: $0).isActivePassive
        }) {
            log.append("Passive active: \(passive.name) - \(passive.summary)")
        }

        return CombatState(
            encounterID: encounterID,
            enemyIDs: enemyIDs,
            enemies: enemyStates,
            roundNumber: 1,
            heroInitiative: heroInitiative,
            enemyInitiatives: enemyInitiatives,
            activeConditions: [],
            phase: heroStarts ? .heroTurn : .enemyTurn,
            combatLog: log,
            isActive: true
        )
    }

    static func beginHeroTurn(hero: inout Hero, state: inout CombatState) {
        guard state.phase == .heroTurn, hero.currentHealth > 0 else { return }
        state.roundNumber += state.hasUsedMajorAction ? 1 : 0
        state.quickDefenceBonus = 0
        state.hasUsedQuickAction = false
        state.hasUsedMajorAction = false
        state.hasUsedConsumable = false
        tickCooldowns(&state)

        applyStartOfTurnDamage(to: &hero, state: &state)
        let endedAtTurnStart = state.activeConditions.filter { $0.type == .guarded }
        state.activeConditions.removeAll { $0.type == .guarded }
        for condition in endedAtTurnStart {
            append("\(condition.type.displayName) expires.", to: &state)
        }
        for condition in tickConditions(&state.activeConditions) {
            append("\(condition.type.displayName) expires.", to: &state)
        }

        if hero.currentHealth <= 0 {
            hero.currentHealth = 0
            state.phase = .defeated
            state.isActive = false
            append("You fall in battle.", to: &state)
        } else {
            append("Your turn begins.", to: &state)
        }
    }

    static func useMinorHealingDraught(hero: inout Hero, state: inout CombatState) -> String? {
        useHealingConsumable("Minor Healing Draught", hero: &hero, state: &state)
    }

    static func useHealingConsumable(_ itemName: String, hero: inout Hero, state: inout CombatState) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
        guard !state.hasUsedConsumable else { return "You already used a consumable this turn." }
        guard let owned = hero.inventory.itemQuantities[itemName], owned > 0 else {
            return "No \(itemName) available."
        }

        let healing = healingAmount(for: itemName)
        hero.currentHealth = min(hero.maxHealth, hero.currentHealth + healing)
        if owned == 1 {
            hero.inventory.itemQuantities[itemName] = nil
        } else {
            hero.inventory.itemQuantities[itemName] = owned - 1
        }
        state.hasUsedQuickAction = true
        state.hasUsedConsumable = true
        append("You use \(itemName) and restore \(healing) HP.", to: &state)
        return nil
    }

    static func useCombatConsumable(_ itemName: String, hero: inout Hero, state: inout CombatState) -> String? {
        if healingConsumableNames.contains(itemName) {
            return useHealingConsumable(itemName, hero: &hero, state: &state)
        }
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
        guard !state.hasUsedConsumable else { return "You already used a consumable this turn." }
        guard let owned = hero.inventory.itemQuantities[itemName], owned > 0 else {
            return "No \(itemName) available."
        }

        if staminaConsumableNames.contains(itemName) {
            guard hero.maxStamina > 0 else { return "This hero does not use Stamina." }
            guard hero.currentStamina < hero.maxStamina else { return "Stamina is already full." }
            if hero.currentAdventureState.isActive,
               hero.currentAdventureState.staminaDraughtUses >= GameConstants.maxStaminaDraughtUsesPerAdventure {
                return "You have already used \(GameConstants.maxStaminaDraughtUsesPerAdventure) Stamina Draughts this adventure."
            }

            let previousStamina = hero.currentStamina
            if itemName == "Hero's Stamina Draught" {
                hero.currentStamina = hero.maxStamina
            } else {
                hero.currentStamina = min(hero.maxStamina, hero.currentStamina + staminaAmount(for: itemName))
            }
            let restored = hero.currentStamina - previousStamina
            consume(itemName, owned: owned, hero: &hero)
            if hero.currentAdventureState.isActive {
                hero.currentAdventureState.staminaDraughtUses += 1
            }
            state.hasUsedQuickAction = true
            state.hasUsedConsumable = true
            append("You use \(itemName) and restore \(restored) Stamina.", to: &state)
            if hero.currentAdventureState.isActive {
                append(
                    "Stamina Draught uses this adventure: \(hero.currentAdventureState.staminaDraughtUses) / \(GameConstants.maxStaminaDraughtUsesPerAdventure).",
                    to: &state
                )
            }
            return nil
        }

        switch itemName {
        case "Fire Oil":
            guard !state.pendingFireOilBonus, state.pendingElementalFlask == nil else {
                return "A weapon coating is already active."
            }
            consume(itemName, owned: owned, hero: &hero)
            state.pendingFireOilBonus = true
            state.hasUsedQuickAction = true
            state.hasUsedConsumable = true
            append("Fire Oil applied. Your next weapon hit deals +1d4 fire.", to: &state)
            return nil
        case "Antivenom":
            guard state.activeConditions.contains(where: { $0.type == .poisoned }) else {
                return "You are not Poisoned."
            }
            consume(itemName, owned: owned, hero: &hero)
            state.activeConditions.removeAll { $0.type == .poisoned }
            state.hasUsedQuickAction = true
            state.hasUsedConsumable = true
            append("You use Antivenom and remove Poisoned.", to: &state)
            return nil
        case "Focus Tonic":
            guard hero.maxFocus > 0 else { return "This hero does not use Focus." }
            guard hero.currentFocus < hero.maxFocus else { return "Focus is already full." }
            consume(itemName, owned: owned, hero: &hero)
            hero.currentFocus = min(hero.maxFocus, hero.currentFocus + 1)
            state.hasUsedQuickAction = true
            state.hasUsedConsumable = true
            append("You use Focus Tonic and restore 1 Focus.", to: &state)
            return nil
        default:
            return "\(itemName) is not implemented in combat yet."
        }
    }

    static let healingConsumableNames = ["Minor Healing Draught", "Healing Draught", "Greater Healing Draught", "Hero's Healing Draught"]
    static let staminaConsumableNames = ItemData.staminaDraughtNames

    private static func consume(_ itemName: String, owned: Int, hero: inout Hero) {
        if owned == 1 {
            hero.inventory.itemQuantities[itemName] = nil
        } else {
            hero.inventory.itemQuantities[itemName] = owned - 1
        }
    }

    private static func healingAmount(for itemName: String) -> Int {
        switch itemName {
        case "Healing Draught":
            return Int.random(in: 1...8) + Int.random(in: 1...8) + 3
        case "Greater Healing Draught":
            return Int.random(in: 1...8) + Int.random(in: 1...8) + Int.random(in: 1...8) + 5
        case "Hero's Healing Draught":
            return Int.random(in: 1...8) + Int.random(in: 1...8) + Int.random(in: 1...8) + Int.random(in: 1...8) + 8
        default:
            return Int.random(in: 1...8) + 2
        }
    }

    private static func staminaAmount(for itemName: String) -> Int {
        switch itemName {
        case "Stamina Draught": return 2
        case "Greater Stamina Draught": return 3
        default: return 1
        }
    }

    private static func isWeaponHit(actionName: String) -> Bool {
        !["Ember Bolt", "Frost Snare", "Burning Surge", "Starfall Pulse", "Voidfall Pulse"].contains(actionName)
    }

    static func basicAttack(hero: inout Hero, state: inout CombatState, targetID: UUID) -> String? {
        performHeroAttack(hero: &hero, state: &state, targetID: targetID, actionName: primaryAttackName(for: hero, state: state), mode: .pathAttack)
    }

    static func cleavingBlow(hero: inout Hero, state: inout CombatState, targetID: UUID) -> String? {
        guard hero.abilities.contains(where: { $0.id == "cleaving-blow" }) else { return "Cleaving Blow is not unlocked." }
        guard (state.abilityCooldowns["cleaving-blow"] ?? 0) == 0 else { return "Cleaving Blow is cooling down." }
        return performHeroAttack(hero: &hero, state: &state, targetID: targetID, actionName: "Cleaving Blow", mode: .cleavingBlow)
    }

    static func useAbility(_ ability: Ability, hero: inout Hero, state: inout CombatState, targetID: UUID?) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard (state.abilityCooldowns[ability.id] ?? 0) == 0 else { return "\(ability.name) is cooling down." }
        if let issue = resourceIssue(for: ability, hero: hero) {
            return issue
        }
        if ability.techniqueType != nil {
            return useSubpathTechnique(ability, hero: &hero, state: &state, targetID: targetID)
        }

        switch ability.id {
        case "cleaving-blow":
            guard let targetID else { return "Choose a living enemy." }
            return cleavingBlow(hero: &hero, state: &state, targetID: targetID)
        case "tempest-step", "sure-shot":
            guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
            spendResource(for: ability, hero: &hero)
            state.pendingAttackBonus += ability.id == "sure-shot" ? 2 : 1
            state.pendingDamageBonus += ability.id == "tempest-step" ? 1 : 0
            state.hasUsedQuickAction = true
            startCooldown(for: ability, state: &state)
            append("\(ability.name): \(ability.summary)", to: &state)
            return nil
        case "cinder-mark":
            guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
            guard let targetID,
                  let targetIndex = state.enemies.firstIndex(where: { $0.id == targetID && $0.currentHealth > 0 }),
                  let enemy = EnemyData.enemy(id: state.enemies[targetIndex].enemyID)
            else { return "Choose a living enemy." }
            for index in state.enemies.indices where index != targetIndex && state.enemies[index].cinderMarkPending {
                state.enemies[index].cinderMarkPending = false
                state.enemies[index].cinderMarkRemainingTurns = 0
                state.enemies[index].conditions.removeAll { $0.type == .marked }
            }
            spendResource(for: ability, hero: &hero)
            state.enemies[targetIndex].cinderMarkPending = true
            state.enemies[targetIndex].cinderMarkRemainingTurns = 2
            addCondition(Condition(type: .marked, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
            state.hasUsedQuickAction = true
            startCooldown(for: ability, state: &state)
            append("Cinder Mark settles on \(enemy.name). The next successful fire spell against it gains +1d6 fire damage.", to: &state)
            return nil
        case "shield-wall", "dawnward":
            guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
            addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
            state.hasUsedQuickAction = true
            spendResource(for: ability, hero: &hero)
            startCooldown(for: ability, state: &state)
            append("\(ability.name): \(ability.summary)", to: &state)
            return nil
        case "relentless-assault":
            guard let targetID else { return "Choose a living enemy." }
            guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
            spendResource(for: ability, hero: &hero)
            return performHeroAttack(hero: &hero, state: &state, targetID: targetID, actionName: "Relentless Assault", mode: .relentlessAssault)
        case "catch-breath":
            guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
            guard hero.maxStamina > 0 else { return "This hero does not use Stamina." }
            guard hero.currentStamina < hero.maxStamina else { return "Stamina is full." }
            hero.currentStamina = min(hero.maxStamina, hero.currentStamina + 1)
            state.hasUsedQuickAction = true
            startCooldown(for: ability, state: &state)
            append("Catch Breath restores 1 Stamina.", to: &state)
            return nil
        case "bastion-sweep", "whirlwind-cut", "shadow-chain", "scatterknives", "pack-assault",
             "piercing-volley", "cinder-burst", "astral-cascade", "dawnwave", "radiant-judgement":
            return performCapstoneAbility(
                ability,
                hero: &hero,
                state: &state,
                primaryTargetID: targetID
            )
        case "frost-snare", "burning-surge", "starfall-pulse", "veil-strike":
            guard let targetID else { return "Choose a living enemy." }
            guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
            spendResource(for: ability, hero: &hero)
            return performHeroAttack(hero: &hero, state: &state, targetID: targetID, actionName: ability.name, mode: .ability(ability))
        case "mend-the-wounded":
            guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
            spendResource(for: ability, hero: &hero)
            let healing = Int.random(in: 1...6) + hero.attributes.modifier(for: .presence)
            hero.currentHealth = min(hero.maxHealth, hero.currentHealth + max(1, healing))
            state.hasUsedQuickAction = true
            startCooldown(for: ability, state: &state)
            append("\(ability.name) restores \(max(1, healing)) HP.", to: &state)
            return nil
        default:
            return "\(ability.name) is not available in combat yet."
        }
    }

    private static func useSubpathTechnique(
        _ ability: Ability,
        hero: inout Hero,
        state: inout CombatState,
        targetID: UUID?
    ) -> String? {
        guard !state.hasUsedQuickAction else { return "You already used a Quick Action this turn." }
        var targetIndex: Int?
        if ability.targetType == .enemy {
            guard let targetID,
                  let index = state.enemies.firstIndex(where: { $0.id == targetID && $0.currentHealth > 0 })
            else { return "Choose a living enemy." }
            targetIndex = index
        }

        switch ability.id {
        case "shield-brace":
            addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
            state.nextPhysicalDamageReduction = max(state.nextPhysicalDamageReduction, 1)
        case "elemental-flask":
            guard state.pendingFireOilBonus == false, state.pendingElementalFlask == nil else {
                return "A weapon coating is already active."
            }
            if hero.currentAdventureState.isActive,
               hero.currentAdventureState.elementalFlaskUses >= GameConstants.maxElementalFlaskUsesPerAdventure {
                return "No Elemental Flask uses remaining."
            }
            let elementRoll = Int.random(in: 1...4)
            let element: ElementalFlaskElement
            switch elementRoll {
            case 1: element = .fire
            case 2: element = .waterIce
            case 3: element = .wind
            default: element = .earth
            }
            state.pendingElementalFlask = element
            if hero.currentAdventureState.isActive {
                hero.currentAdventureState.elementalFlaskUses += 1
            }
            state.hasUsedQuickAction = true
            startCooldown(for: ability, state: &state)
            append("Elemental Flask coats your weapon. Element Roll: 1d4 [\(elementRoll)] = \(element.displayName).", to: &state)
            append("Your next successful weapon attack deals +1d4 \(element.damageType.rawValue) damage.", to: &state)
            return nil
        case "veil-step":
            state.quickDefenceBonus = max(state.quickDefenceBonus, 1)
            state.pendingAttackBonus = max(state.pendingAttackBonus, 1)
        case "loaded-trick":
            state.pendingDamageBonus = min(2, max(state.pendingDamageBonus, 1))
        case "pack-instinct":
            state.quickDefenceBonus = max(state.quickDefenceBonus, 1)
        case "steady-aim":
            state.pendingAttackBonus = max(state.pendingAttackBonus, 1)
            state.pendingDamageBonus = min(2, max(state.pendingDamageBonus, 1))
        case "kindled-focus":
            if hero.currentFocus < hero.maxFocus {
                hero.currentFocus = min(hero.maxFocus, hero.currentFocus + 1)
                append("Kindled Focus restores 1 Focus.", to: &state)
            } else {
                state.pendingKindledFireSpell = true
                append("Kindled Focus empowers your next fire spell for +1 fire damage.", to: &state)
            }
        case "starlit-ward":
            state.pendingDamageReductionDie = max(state.pendingDamageReductionDie, 4)
        case "dawns-grace":
            let healing = Int.random(in: 1...4)
            hero.currentHealth = min(hero.maxHealth, hero.currentHealth + healing)
            append("Dawn's Grace restores \(healing) HP.", to: &state)
        case "judgement-spark":
            state.pendingDamageBonus = min(2, max(state.pendingDamageBonus, 1))
        case "pocket-sand":
            if let targetIndex {
                state.enemies[targetIndex].nextAttackPenalty = max(state.enemies[targetIndex].nextAttackPenalty, 1)
            }
        case "pinning-threat":
            if let targetIndex {
                let type: ConditionType = state.enemies[targetIndex].conditions.contains(where: { $0.type == .marked }) ? .exposed : .marked
                addCondition(Condition(type: type, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
            }
        case "marked-in-shadow":
            if let targetIndex {
                if state.enemies[targetIndex].conditions.contains(where: { $0.type == .exposed }) {
                    state.pendingDamageBonus = min(2, state.pendingDamageBonus + 1)
                }
                addCondition(Condition(type: .exposed, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
            }
        case "cinder-veil":
            if let targetIndex {
                let burning = state.enemies[targetIndex].conditions.contains(where: { $0.type == .burning })
                addCondition(Condition(type: .exposed, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
                if burning {
                    addCondition(Condition(type: .weakened, remainingTurns: 1), to: &state.enemies[targetIndex].conditions)
                }
            }
        case "brand-of-doubt":
            if let targetIndex {
                addCondition(Condition(type: .marked, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
                state.enemies[targetIndex].nextAttackPenalty = max(state.enemies[targetIndex].nextAttackPenalty, 1)
            }
        default:
            if let targetIndex, let condition = ability.conditionApplied {
                let tacticalDuration = [.exposed, .marked, .slowed].contains(condition) ? 2 : 1
                addCondition(
                    Condition(type: condition, remainingTurns: max(ability.durationTurns ?? 1, tacticalDuration)),
                    to: &state.enemies[targetIndex].conditions
                )
            }
        }

        state.hasUsedQuickAction = true
        startCooldown(for: ability, state: &state)
        if let targetIndex, let enemy = EnemyData.enemy(id: state.enemies[targetIndex].enemyID) {
            append("\(ability.name) targets \(enemy.name). \(ability.summary)", to: &state)
        } else if ability.id != "dawns-grace", ability.id != "kindled-focus" {
            append("\(ability.name): \(ability.summary)", to: &state)
        }
        return nil
    }

    private static func performCapstoneAbility(
        _ ability: Ability,
        hero: inout Hero,
        state: inout CombatState,
        primaryTargetID: UUID?
    ) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
        guard !livingEnemies(in: state).isEmpty else { return "No living enemies remain." }
        if let issue = resourceIssue(for: ability, hero: hero) {
            return issue
        }

        let selectedIndex = primaryTargetID.flatMap { id in
            state.enemies.firstIndex(where: { $0.id == id && $0.currentHealth > 0 })
        }
        if ability.targetPattern == .twoEnemies || ability.targetPattern == .primaryPlusSplash {
            guard selectedIndex != nil else { return "Choose a living enemy." }
        }

        spendResource(for: ability, hero: &hero)
        append("\(ability.name) begins.", to: &state)

        switch ability.id {
        case "bastion-sweep", "whirlwind-cut":
            performWeaponCapstone(
                ability,
                hero: hero,
                state: &state,
                targetIndices: state.enemies.indices.filter { state.enemies[$0].currentHealth > 0 }
            )
            if ability.id == "bastion-sweep" {
                addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
                append("Bastion Sweep leaves you Guarded until your next turn.", to: &state)
            }
        case "shadow-chain":
            let indices = orderedTargetIndices(primary: selectedIndex, state: state, limit: 2)
            performWeaponCapstone(
                ability,
                hero: hero,
                state: &state,
                targetIndices: indices,
                exposedDamageBonus: 1
            )
        case "scatterknives":
            performWeaponCapstone(
                ability,
                hero: hero,
                state: &state,
                targetIndices: state.enemies.indices.filter { state.enemies[$0].currentHealth > 0 },
                allTargetDamagePenalty: 1
            )
        case "pack-assault":
            let indices = orderedTargetIndices(primary: selectedIndex, state: state, limit: 2)
            performWeaponCapstone(
                ability,
                hero: hero,
                state: &state,
                targetIndices: indices,
                markedDamageBonus: 2
            )
        case "piercing-volley":
            let indices = orderedTargetIndices(primary: selectedIndex, state: state, limit: 2)
            performWeaponCapstone(
                ability,
                hero: hero,
                state: &state,
                targetIndices: indices,
                markedDamageBonus: 1
            )
        case "cinder-burst":
            guard let selectedIndex else { return "Choose a living enemy." }
            performCinderBurst(hero: hero, state: &state, primaryIndex: selectedIndex)
        case "radiant-judgement":
            performAreaSpell(
                name: ability.name,
                expression: "1d6",
                attribute: .presence,
                damageType: .oathfire,
                undeadBonus: 1,
                hero: hero,
                state: &state
            )
        case "astral-cascade":
            performAreaSpell(
                name: ability.name,
                expression: "1d6",
                attribute: .mind,
                damageType: .arcane,
                hero: hero,
                state: &state
            )
        case "dawnwave":
            performAreaSpell(
                name: ability.name,
                expression: "1d4",
                attribute: .presence,
                damageType: .oathfire,
                hero: hero,
                state: &state
            )
            addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
            append("Dawnwave leaves you Guarded until your next turn.", to: &state)
        default:
            return "\(ability.name) is not available in combat yet."
        }

        clearPendingAttackBonuses(&state)
        startCooldown(for: ability, state: &state)
        if livingEnemies(in: state).isEmpty {
            state.phase = .victory
            state.isActive = false
            state.hasUsedMajorAction = true
            append("Victory. Collect your rewards.", to: &state)
        } else {
            finishHeroMajorAction(hero: &hero, state: &state)
        }
        return nil
    }

    private static func orderedTargetIndices(
        primary: Int?,
        state: CombatState,
        limit: Int
    ) -> [Int] {
        let living = state.enemies.indices.filter { state.enemies[$0].currentHealth > 0 }
        guard let primary else { return Array(living.prefix(limit)) }
        return Array(([primary] + living.filter { $0 != primary }).prefix(limit))
    }

    private static func performWeaponCapstone(
        _ ability: Ability,
        hero: Hero,
        state: inout CombatState,
        targetIndices: [Int],
        secondTargetDamagePenalty: Int = 0,
        markedDamageBonus: Int = 0,
        exposedDamageBonus: Int = 0,
        allTargetDamagePenalty: Int = 0
    ) {
        let weapon = equippedWeapon(for: hero)
        let attribute = attackAttribute(for: weapon)
        let attributeModifier = hero.attributes.modifier(for: attribute)
        let trainingBonus = SkillCheckHelper.trainingBonus(for: hero)
        let poisoned = state.activeConditions.contains { $0.type == .poisoned }
        let agilityPenalty = attribute == .agility && state.activeConditions.contains {
            $0.type == .knockedDown || $0.type == .slowed
        } ? -1 : 0
        let pendingAttackBonus = state.pendingAttackBonus
        var temporaryDamagePending = state.pendingDamageBonus
        let elementalFlask = state.pendingElementalFlask
        var elementalFlaskTriggered = false

        if let elementalFlask {
            append("\(ability.name): Elemental Flask is active (\(elementalFlask.displayName)).", to: &state)
        }

        for (position, index) in targetIndices.enumerated() {
            guard state.enemies[index].currentHealth > 0,
                  let enemy = EnemyData.enemy(id: state.enemies[index].enemyID) else { continue }
            let roll = DiceRoller.roll(.d20, disadvantage: poisoned)
            let attackBonus = attributeModifier + trainingBonus + agilityPenalty + pendingAttackBonus
            let total = roll.total + attackBonus
            let defence = effectiveEnemyDefence(state.enemies[index])
            let hit = !roll.natural1 && (roll.natural20 || total >= defence)
            append("\(ability.name) - \(enemy.name): \(roll.keptDice.first ?? 0) + \(attackBonus) = \(total) vs Defence \(defence). \(hit ? "Hit." : "Miss.")", to: &state)
            if !hit, elementalFlask != nil {
                append("Elemental Flask does not affect the missed strike against \(enemy.name).", to: &state)
            }
            guard hit else { continue }

            let damage = rollHeroDamage(hero: hero, weapon: weapon, critical: roll.natural20)
            var bonuses: [DamageAdjustment] = []
            if temporaryDamagePending > 0 {
                bonuses.append(DamageAdjustment(label: "Temporary bonus", amount: temporaryDamagePending))
                temporaryDamagePending = 0
            }
            if markedDamageBonus > 0,
               state.enemies[index].conditions.contains(where: { $0.type == .marked }) {
                bonuses.append(DamageAdjustment(label: "Marked target", amount: markedDamageBonus))
            }
            if exposedDamageBonus > 0,
               state.enemies[index].conditions.contains(where: { $0.type == .exposed }) {
                bonuses.append(DamageAdjustment(label: "Exposed target", amount: exposedDamageBonus))
            }
            var reductions: [DamageAdjustment] = []
            if position == 1 && secondTargetDamagePenalty > 0 {
                reductions.append(DamageAdjustment(label: "Second strike", amount: secondTargetDamagePenalty))
            }
            if allTargetDamagePenalty > 0 {
                reductions.append(DamageAdjustment(label: "Scattered strike", amount: allTargetDamagePenalty))
            }
            append("\(enemy.name) base damage: \(damage.summary).", to: &state)
            let resolution = resolveDamageModifiers(
                baseDamage: damage.total,
                damageType: .physical,
                target: enemy,
                bonuses: bonuses,
                reductions: reductions
            )
            for line in resolution.breakdownLines {
                append("\(enemy.name): \(line)", to: &state)
            }
            var totalDamage = max(1, resolution.finalDamage)

            if state.pendingFireOilBonus {
                let fireRoll = Int.random(in: 1...4)
                state.pendingFireOilBonus = false
                let fireResolution = resolveDamageModifiers(
                    baseDamage: fireRoll,
                    damageType: .fire,
                    target: enemy
                )
                append("Fire Oil against \(enemy.name): 1d4 [\(fireRoll)] fire.", to: &state)
                for line in fireResolution.breakdownLines {
                    append("Fire Oil: \(line)", to: &state)
                }
                totalDamage += fireResolution.finalDamage
            } else if let element = elementalFlask {
                let elementalRoll = Int.random(in: 1...4)
                elementalFlaskTriggered = true
                let elementalResolution = resolveDamageModifiers(
                    baseDamage: elementalRoll,
                    damageType: element.damageType,
                    target: enemy
                )
                append(
                    "Elemental Flask adds 1d4 [\(elementalRoll)] \(element.damageType.rawValue) damage to \(enemy.name).",
                    to: &state
                )
                for line in elementalResolution.breakdownLines {
                    append("Elemental Flask: \(line)", to: &state)
                }
                totalDamage += elementalResolution.finalDamage
            }

            state.enemies[index].currentHealth = max(0, state.enemies[index].currentHealth - totalDamage)
            append("\(ability.name) deals \(totalDamage) damage to \(enemy.name).", to: &state)
            if roll.natural20 {
                append("\(enemy.name): Critical hit; only this target's weapon dice are doubled.", to: &state)
            }
            if state.enemies[index].currentHealth == 0 {
                append("\(enemy.name) is defeated.", to: &state)
            }
        }

        if elementalFlaskTriggered {
            state.pendingElementalFlask = nil
            append("Elemental Flask fades from your weapon after \(ability.name).", to: &state)
        } else if elementalFlask != nil {
            append("Every \(ability.name) strike missed. Elemental Flask remains active.", to: &state)
        }
    }

    private static func performCinderBurst(
        hero: Hero,
        state: inout CombatState,
        primaryIndex: Int
    ) {
        guard let primaryEnemy = EnemyData.enemy(id: state.enemies[primaryIndex].enemyID) else { return }
        let mindModifier = hero.attributes.modifier(for: .mind)
        let trainingBonus = SkillCheckHelper.trainingBonus(for: hero)
        let poisoned = state.activeConditions.contains { $0.type == .poisoned }
        let roll = DiceRoller.roll(.d20, disadvantage: poisoned)
        let attackBonus = mindModifier + trainingBonus + state.pendingAttackBonus
        let total = roll.total + attackBonus
        let defence = effectiveEnemyDefence(state.enemies[primaryIndex])
        let hit = !roll.natural1 && (roll.natural20 || total >= defence)
        append("Cinder Burst - \(primaryEnemy.name): \(roll.keptDice.first ?? 0) + \(attackBonus) = \(total) vs Defence \(defence). \(hit ? "Hit." : "Miss.")", to: &state)
        guard hit else { return }

        let base = rollDamage(
            expression: "1d8",
            attributeModifier: mindModifier,
            damageType: .fire,
            critical: false
        )
        append("\(primaryEnemy.name) primary base damage: \(base.summary).", to: &state)
        var bonuses: [DamageAdjustment] = []
        if state.pendingDamageBonus > 0 {
            bonuses.append(DamageAdjustment(label: "Temporary bonus", amount: state.pendingDamageBonus))
        }
        if state.pendingKindledFireSpell {
            bonuses.append(DamageAdjustment(label: "Kindled Focus", amount: 1))
            state.pendingKindledFireSpell = false
        }
        if state.enemies[primaryIndex].cinderMarkPending {
            let cinderRoll = Int.random(in: 1...6)
            bonuses.append(DamageAdjustment(label: "Cinder Mark 1d6 [\(cinderRoll)]", amount: cinderRoll))
            state.enemies[primaryIndex].cinderMarkPending = false
            state.enemies[primaryIndex].cinderMarkRemainingTurns = 0
            state.enemies[primaryIndex].conditions.removeAll { $0.type == .marked }
        }
        let primaryResolution = resolveDamageModifiers(
            baseDamage: base.total,
            damageType: .fire,
            target: primaryEnemy,
            bonuses: bonuses
        )
        for line in primaryResolution.breakdownLines {
            append("\(primaryEnemy.name): \(line)", to: &state)
        }
        state.enemies[primaryIndex].currentHealth = max(
            0,
            state.enemies[primaryIndex].currentHealth - primaryResolution.finalDamage
        )
        append("Cinder Burst deals \(primaryResolution.finalDamage) fire damage to \(primaryEnemy.name).", to: &state)
        if state.enemies[primaryIndex].currentHealth == 0 {
            append("\(primaryEnemy.name) is defeated.", to: &state)
        }

        for index in state.enemies.indices where index != primaryIndex && state.enemies[index].currentHealth > 0 {
            guard let enemy = EnemyData.enemy(id: state.enemies[index].enemyID) else { continue }
            let splashRoll = Int.random(in: 1...4)
            append("\(enemy.name) splash base damage: 1d4 [\(splashRoll)] = \(splashRoll) fire damage.", to: &state)
            let resolution = resolveDamageModifiers(
                baseDamage: splashRoll,
                damageType: .fire,
                target: enemy
            )
            for line in resolution.breakdownLines {
                append("\(enemy.name): \(line)", to: &state)
            }
            state.enemies[index].currentHealth = max(
                0,
                state.enemies[index].currentHealth - resolution.finalDamage
            )
            append("Cinder Burst splash deals \(resolution.finalDamage) fire damage to \(enemy.name).", to: &state)
            if state.enemies[index].currentHealth == 0 {
                append("\(enemy.name) is defeated.", to: &state)
            }
        }
    }

    private static func performAreaSpell(
        name: String,
        expression: String,
        attribute: AttributeType,
        damageType: DamageType,
        undeadBonus: Int = 0,
        hero: Hero,
        state: inout CombatState
    ) {
        let attributeModifier = hero.attributes.modifier(for: attribute)
        for index in state.enemies.indices where state.enemies[index].currentHealth > 0 {
            guard let enemy = EnemyData.enemy(id: state.enemies[index].enemyID) else { continue }
            let base = rollDamage(
                expression: expression,
                attributeModifier: attributeModifier,
                damageType: damageType,
                critical: false
            )
            let appliedUndeadBonus = enemy.family.localizedCaseInsensitiveContains("Undead") ? undeadBonus : 0
            append("\(enemy.name) base damage: \(base.summary).", to: &state)
            let bonuses = appliedUndeadBonus > 0
                ? [DamageAdjustment(label: "Undead judgement", amount: appliedUndeadBonus)]
                : []
            let resolution = resolveDamageModifiers(
                baseDamage: base.total,
                damageType: damageType,
                target: enemy,
                bonuses: bonuses
            )
            for line in resolution.breakdownLines {
                append("\(enemy.name): \(line)", to: &state)
            }
            state.enemies[index].currentHealth = max(
                0,
                state.enemies[index].currentHealth - resolution.finalDamage
            )
            append("\(name) deals \(resolution.finalDamage) \(damageType.rawValue) damage to \(enemy.name).", to: &state)
            if state.enemies[index].currentHealth == 0 {
                append("\(enemy.name) is defeated.", to: &state)
            }
        }
    }

    private static func performHeroAttack(hero: inout Hero, state: inout CombatState, targetID: UUID, actionName: String, mode: HeroAttackMode) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
        guard let targetIndex = state.enemies.firstIndex(where: { $0.id == targetID }),
              state.enemies[targetIndex].currentHealth > 0,
              let enemy = EnemyData.enemy(id: state.enemies[targetIndex].enemyID)
        else { return "Choose a living enemy." }

        let weapon = equippedWeapon(for: hero)
        let attackAttribute = mode.isPathAttack && hero.path == .embermage ? .mind : attackAttribute(for: weapon)
        let attributeModifier = hero.attributes.modifier(for: attackAttribute)
        let trainingBonus = SkillCheckHelper.trainingBonus(for: hero)
        let poisoned = state.activeConditions.contains { $0.type == .poisoned }
        let agilityConditionPenalty = attackAttribute == .agility && (
            state.activeConditions.contains { $0.type == .knockedDown }
                || state.activeConditions.contains { $0.type == .slowed }
        ) ? -1 : 0
        let openingBonus = hero.path == .shadowstep && actionName == "Opening Strike" && !state.usedAbilityIDs.contains("opening-strike") ? 2 : 0
        let roll = DiceRoller.roll(.d20, disadvantage: poisoned)
        let pendingAttackBonus = state.pendingAttackBonus
        let attackTotal = roll.total + attributeModifier + trainingBonus + agilityConditionPenalty + openingBonus + pendingAttackBonus
        let targetDefence = effectiveEnemyDefence(state.enemies[targetIndex])

        if roll.natural1 {
            append("\(actionName): you roll 1 + \(attributeModifier + trainingBonus + agilityConditionPenalty + openingBonus + pendingAttackBonus) = \(attackTotal) vs Defence \(targetDefence). Natural 1. Miss.", to: &state)
            clearPendingAttackBonuses(&state)
            finishHeroMajorAction(hero: &hero, state: &state)
            return nil
        }

        let hit = roll.natural20 || attackTotal >= targetDefence
        append("\(actionName): you roll \(roll.keptDice.first ?? 0) + \(attributeModifier + trainingBonus + agilityConditionPenalty + openingBonus + pendingAttackBonus) = \(attackTotal) vs Defence \(targetDefence). \(hit ? "Hit." : "Miss.")", to: &state)

        if hit {
            let damage = rollPathDamage(hero: hero, weapon: weapon, actionName: actionName, mode: mode, critical: roll.natural20)
            append("\(actionName) hits \(enemy.name).", to: &state)
            append("Base damage: \(damage.summary).", to: &state)

            var bonuses: [DamageAdjustment] = []
            if state.pendingDamageBonus > 0 {
                bonuses.append(DamageAdjustment(label: "Temporary bonus", amount: state.pendingDamageBonus))
            }
            if state.pendingKindledFireSpell, isFireSpell(actionName: actionName, mode: mode) {
                bonuses.append(DamageAdjustment(label: "Kindled Focus", amount: 1))
                state.pendingKindledFireSpell = false
            }
            if actionName != "Cinder Mark",
               isFireSpell(actionName: actionName, mode: mode),
               state.enemies[targetIndex].cinderMarkPending {
                let cinderRoll = Int.random(in: 1...6)
                bonuses.append(DamageAdjustment(label: "Cinder Mark 1d6 [\(cinderRoll)]", amount: cinderRoll))
                state.enemies[targetIndex].cinderMarkPending = false
                state.enemies[targetIndex].cinderMarkRemainingTurns = 0
                state.enemies[targetIndex].conditions.removeAll { $0.type == .marked }
            }
            let weakenedPenalty = state.activeConditions.contains(where: { $0.type == .weakened }) ? 1 : 0
            let reductions = weakenedPenalty > 0
                ? [DamageAdjustment(label: "Weakened", amount: 1)]
                : []
            let primaryResolution = resolveDamageModifiers(
                baseDamage: damage.total,
                damageType: damage.damageType,
                target: enemy,
                bonuses: bonuses,
                reductions: reductions
            )
            for line in primaryResolution.breakdownLines {
                append(line, to: &state)
            }
            if weakenedPenalty > 0 {
                state.activeConditions.removeAll { $0.type == .weakened }
            }

            var totalDamage = primaryResolution.finalDamage
            var hasSecondaryFireDamage = false
            if state.pendingFireOilBonus, isWeaponHit(actionName: actionName) {
                let fireRoll = Int.random(in: 1...4)
                state.pendingFireOilBonus = false
                hasSecondaryFireDamage = true
                append("Fire Oil base: 1d4 [\(fireRoll)] = \(fireRoll) fire damage.", to: &state)
                let oilResolution = resolveDamageModifiers(
                    baseDamage: fireRoll,
                    damageType: .fire,
                    target: enemy
                )
                for line in oilResolution.breakdownLines {
                    append("Fire Oil: \(line)", to: &state)
                }
                totalDamage += oilResolution.finalDamage
            } else if let element = state.pendingElementalFlask,
                      isWeaponHit(actionName: actionName) {
                let elementalRoll = Int.random(in: 1...4)
                state.pendingElementalFlask = nil
                let elementalResolution = resolveDamageModifiers(
                    baseDamage: elementalRoll,
                    damageType: element.damageType,
                    target: enemy
                )
                append(
                    "Elemental Flask adds 1d4 [\(elementalRoll)] \(element.damageType.rawValue) damage.",
                    to: &state
                )
                for line in elementalResolution.breakdownLines {
                    append("Elemental Flask: \(line)", to: &state)
                }
                totalDamage += elementalResolution.finalDamage
            }
            let finalType = hasSecondaryFireDamage && damage.damageType != .fire
                ? "mixed"
                : damage.damageType.rawValue
            append("Final damage: \(totalDamage) \(finalType).", to: &state)
            state.enemies[targetIndex].currentHealth = max(0, state.enemies[targetIndex].currentHealth - totalDamage)
            if roll.natural20 {
                append("Critical hit.", to: &state)
            }
            if state.enemies[targetIndex].currentHealth == 0 {
                append("\(enemy.name) is defeated.", to: &state)
                if mode.isCleavingBlow {
                    applyCleaveDamage(from: enemy.name, damage: totalDamage, state: &state)
                }
            }
            if actionName == "Marked Shot" {
                addCondition(Condition(type: .marked, remainingTurns: 2), to: &state.enemies[targetIndex].conditions)
                append("\(enemy.name) is Marked.", to: &state)
            }
            if case let .ability(ability) = mode,
               let condition = ability.conditionApplied,
               state.enemies[targetIndex].currentHealth > 0 {
                var updatedEnemyState = state.enemies[targetIndex]
                applyAbilityCondition(
                    condition,
                    from: ability,
                    to: &updatedEnemyState,
                    enemy: enemy,
                    state: &state
                )
                state.enemies[targetIndex] = updatedEnemyState
            }
        }

        if actionName == "Opening Strike" {
            state.usedAbilityIDs.insert("opening-strike")
        }
        if mode.isCleavingBlow {
            state.usedAbilityIDs.insert("cleaving-blow")
            startCooldown(id: "cleaving-blow", state: &state)
        }
        if case .relentlessAssault = mode {
            startCooldown(id: "relentless-assault", state: &state)
        }
        if case let .ability(ability) = mode {
            startCooldown(for: ability, state: &state)
        }
        if actionName == "Guarded Strike" {
            addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
            append("Guarded Strike reinforces your guard.", to: &state)
        }

        if livingEnemies(in: state).isEmpty {
            state.phase = .victory
            state.isActive = false
            state.hasUsedMajorAction = true
            append("Victory. Collect your rewards.", to: &state)
        } else {
            clearPendingAttackBonuses(&state)
            finishHeroMajorAction(hero: &hero, state: &state)
        }
        return nil
    }

    static func defend(hero: inout Hero, state: inout CombatState) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
        addCondition(Condition(type: .guarded, remainingTurns: 1), to: &state.activeConditions)
        append("You are Guarded until your next turn.", to: &state)
        finishHeroMajorAction(hero: &hero, state: &state)
        return nil
    }

    static func flee(hero: inout Hero, state: inout CombatState) -> String? {
        guard state.phase == .heroTurn else { return "It is not your turn." }
        guard !state.hasUsedMajorAction else { return "You already used a Major Action this turn." }
        guard let hardestEnemy = livingEnemies(in: state).compactMap({ EnemyData.enemy(id: $0.enemyID) }).max(by: { fleeTarget(for: $0.tier) < fleeTarget(for: $1.tier) }) else {
            state.phase = .escaped
            state.isActive = false
            return nil
        }
        guard hardestEnemy.tier != .finalBoss else { return "You cannot flee this fight." }

        let bestModifier = max(hero.attributes.modifier(for: .agility), hero.attributes.modifier(for: .instinct))
        let equipmentBonus = ItemData.fleeBonus(for: hero)
        let roll = DiceRoller.roll(.d20)
        let total = roll.total + bestModifier + equipmentBonus
        let target = fleeTarget(for: hardestEnemy.tier)
        append("You try to flee: \(roll.keptDice.first ?? 0) + \(bestModifier) + equipment \(equipmentBonus) = \(total) vs Target \(target).", to: &state)

        if total >= target {
            state.phase = .escaped
            state.isActive = false
            state.hasUsedMajorAction = true
            append("You escape and return to Greywick.", to: &state)
        } else {
            state.hasUsedMajorAction = true
            append("Flee failed. Enemies attack with advantage.", to: &state)
            runEnemyTurn(hero: &hero, state: &state, advantage: true)
        }
        return nil
    }

    static func runEnemyTurn(hero: inout Hero, state: inout CombatState, advantage: Bool = false) {
        guard state.phase != .victory, state.phase != .defeated, state.phase != .escaped else { return }
        if state.phase == .heroTurn {
            tickHeroWindowConditions(&state)
        }
        state.phase = .enemyTurn

        for index in state.enemies.indices where state.enemies[index].currentHealth > 0 {
            guard hero.currentHealth > 0, let enemy = EnemyData.enemy(id: state.enemies[index].enemyID) else { continue }
            var enemyState = state.enemies[index]
            applyEnemyStartOfTurnDamage(enemy: enemy, enemyState: &enemyState, state: &state)
            if enemyState.currentHealth <= 0 {
                state.enemies[index] = enemyState
                continue
            }
            if enemyState.conditions.contains(where: { $0.type == .stunned }) {
                append("\(enemy.name) is Stunned and loses its action.", to: &state)
                for condition in tickEnemyActionConditions(&enemyState.conditions) {
                    append("\(enemy.name)'s \(condition.type.displayName) expires.", to: &state)
                }
                state.enemies[index] = enemyState
                continue
            }
            enemyAttack(enemy: enemy, enemyState: &enemyState, hero: &hero, state: &state, advantage: advantage)
            state.enemies[index] = enemyState
        }

        if hero.currentHealth <= 0 {
            hero.currentHealth = 0
            state.phase = .defeated
            state.isActive = false
            append("You are defeated. Test combat ends.", to: &state)
        } else if livingEnemies(in: state).isEmpty {
            state.phase = .victory
            state.isActive = false
            append("Victory. Collect your rewards.", to: &state)
        } else {
            state.phase = .heroTurn
            beginHeroTurn(hero: &hero, state: &state)
        }
    }

    static func effectiveHeroDefence(hero: Hero, state: CombatState) -> Int {
        var defence = ItemData.defence(for: hero) + state.temporaryDefenceBonus + state.quickDefenceBonus
        if state.activeConditions.contains(where: { $0.type == .guarded }) {
            defence += 2
        }
        if state.activeConditions.contains(where: { $0.type == .exposed }) {
            defence -= 1
        }
        if state.activeConditions.contains(where: { $0.type == .knockedDown }) {
            defence -= 2
        }
        return defence
    }

    static func effectiveEnemyDefence(_ enemyState: CombatEnemyState) -> Int {
        guard let enemy = EnemyData.enemy(id: enemyState.enemyID) else { return 10 }
        var defence = enemy.defence
        if enemyState.conditions.contains(where: { $0.type == .exposed }) {
            defence -= 1
        }
        if enemyState.conditions.contains(where: { $0.type == .knockedDown }) {
            defence -= 2
        }
        return defence
    }

    private static func finishHeroMajorAction(hero: inout Hero, state: inout CombatState) {
        state.hasUsedMajorAction = true
        runEnemyTurn(hero: &hero, state: &state)
    }

    private static func enemyAttack(enemy: Enemy, enemyState: inout CombatEnemyState, hero: inout Hero, state: inout CombatState, advantage: Bool) {
        defer {
            for condition in tickEnemyActionConditions(&enemyState.conditions) {
                append("\(enemy.name)'s \(condition.type.displayName) expires.", to: &state)
            }
        }
        let useGroundSlam = enemy.id == "bristleback-brute" && !enemyState.hasUsedSpecial
        let useDirtySlash = enemy.id == "greywick-raider" && !enemyState.hasUsedSpecial
        let wasFirstAttack = enemyState.firstAttackPending
        if enemy.id == "emberheart-golem", state.roundNumber.isMultiple(of: 3) {
            let roll = DiceRoller.roll(.d20)
            let modifier = hero.attributes.modifier(for: .endurance)
            let total = roll.total + modifier
            let pulse = Int.random(in: 1...4)
            let rawDamage = total >= 14 ? pulse / 2 : pulse
            let damage = applyIncomingFireReduction(rawDamage, hero: &hero, state: &state)
            hero.currentHealth = max(0, hero.currentHealth - damage)
            append("Ember Pulse surges through the forge. Your Endurance Check: \(roll.total) + \(modifier) = \(total) vs Target 14.", to: &state)
            append(total >= 14
                ? "You withstand the pulse and take \(damage) fire damage."
                : "The pulse deals \(damage) fire damage.", to: &state)
            return
        }
        if enemy.id == "bell-drowned-warden", Int.random(in: 1...100) <= 30 {
            // Drowned Toll uses whichever hero resistance modifier is higher.
            let enduranceModifier = hero.attributes.modifier(for: .endurance)
            let presenceModifier = hero.attributes.modifier(for: .presence)
            let resistanceAttribute = presenceModifier > enduranceModifier ? "Presence" : "Endurance"
            let saveModifier = max(enduranceModifier, presenceModifier)
            let saveRoll = DiceRoller.roll(.d20)
            let saveTotal = saveRoll.total + saveModifier
            if saveTotal < 13 {
                addCondition(Condition(type: .weakened, remainingTurns: 2), to: &state.activeConditions)
                append("Drowned Toll rings through the chamber. Your \(resistanceAttribute) Check: \(saveRoll.total) + \(saveModifier) = \(saveTotal) vs Target 13. You fail to resist and become Weakened.", to: &state)
            } else {
                append("Drowned Toll rings through the chamber. Your \(resistanceAttribute) Check: \(saveRoll.total) + \(saveModifier) = \(saveTotal) vs Target 13. You resist.", to: &state)
            }
        }
        let attackPenalty = enemyState.nextAttackPenalty
        let attackBonus = enemy.attackBonus
            + (enemy.id == "raider-lookout" && enemyState.firstAttackPending ? 1 : 0)
            - attackPenalty
        let poisoned = enemyState.conditions.contains(where: { $0.type == .poisoned })
        let roll = DiceRoller.roll(.d20, advantage: advantage, disadvantage: poisoned)
        let total = roll.total + attackBonus
        let heroDefence = effectiveHeroDefence(hero: hero, state: state)
        let actionName = useGroundSlam ? " uses Ground Slam" : " attacks"

        enemyState.firstAttackPending = false
        enemyState.nextAttackPenalty = 0
        if useGroundSlam {
            enemyState.hasUsedSpecial = true
            append("\(enemy.name) uses Ground Slam.", to: &state)
        } else if useDirtySlash {
            enemyState.hasUsedSpecial = true
        }

        if roll.natural1 {
            append("\(enemy.name)\(actionName): 1 + \(attackBonus) = \(total) vs Defence \(heroDefence). Natural 1. Miss.", to: &state)
            return
        }

        let hit = roll.natural20 || total >= heroDefence
        append("\(enemy.name)\(actionName): \(roll.keptDice.first ?? 0) + \(attackBonus) = \(total) vs Defence \(heroDefence). \(hit ? "Hit." : "Miss.")", to: &state)
        guard hit else { return }

        let damageExpression = useGroundSlam ? "1d6 + 2" : enemy.damageExpression
        let damage = rollDamage(expression: damageExpression, attributeModifier: 0, damageType: enemy.damageType, critical: roll.natural20)
        let weakenedPenalty = enemyState.conditions.contains(where: { $0.type == .weakened }) ? 1 : 0
        var finalDamage = max(0, damage.total - weakenedPenalty)
        append("Base damage: \(damage.summary).", to: &state)
        if weakenedPenalty > 0 {
            append("Weakened: -1 damage.", to: &state)
        }
        let emberBonus: Int
        switch enemy.id {
        case "ash-beetle":
            emberBonus = Int.random(in: 1...100) <= 20 ? 1 : 0
        case "emberbound-guard":
            emberBonus = Int.random(in: 1...100) <= 25 ? 1 : 0
        case "emberheart-golem":
            emberBonus = enemyState.currentHealth * 2 < enemy.maxHealth ? 1 : 0
        default:
            emberBonus = 0
        }
        if emberBonus > 0 {
            let appliedEmberBonus = applyIncomingFireReduction(emberBonus, hero: &hero, state: &state)
            finalDamage += appliedEmberBonus
            append("\(enemy.name)'s ember power adds +\(appliedEmberBonus) fire damage.", to: &state)
        }
        if damage.damageType == .fire {
            finalDamage = applyIncomingFireReduction(finalDamage, hero: &hero, state: &state)
        }
        if damage.damageType == .physical, state.nextPhysicalDamageReduction > 0 {
            let reduction = min(finalDamage, state.nextPhysicalDamageReduction)
            finalDamage = max(0, finalDamage - reduction)
            state.nextPhysicalDamageReduction = 0
            append("Shield Brace reduces physical damage by \(reduction).", to: &state)
        }
        if state.pendingDamageReductionDie > 0 {
            let die = state.pendingDamageReductionDie
            let reductionRoll = Int.random(in: 1...die)
            let reduction = min(finalDamage, reductionRoll)
            finalDamage = max(0, finalDamage - reduction)
            state.pendingDamageReductionDie = 0
            append("Void Ward rolls 1d\(die) [\(reductionRoll)] and reduces damage by \(reduction).", to: &state)
        }
        hero.currentHealth = max(0, hero.currentHealth - finalDamage)
        append("Final damage: \(finalDamage) \(damage.damageType.rawValue).", to: &state)
        if roll.natural20 {
            append("\(enemy.name) lands a critical hit.", to: &state)
        }

        if enemy.id == "tunnel-skitter", Int.random(in: 1...100) <= 20 {
            addCondition(Condition(type: .poisoned, remainingTurns: 2), to: &state.activeConditions)
            append("You are Poisoned for 1 turn.", to: &state)
        }
        if useDirtySlash {
            addCondition(Condition(type: .bleeding, remainingTurns: 1), to: &state.activeConditions)
            append("Dirty Slash applies Bleeding for 1 turn.", to: &state)
        }
        if useGroundSlam {
            addCondition(Condition(type: .knockedDown, remainingTurns: 2), to: &state.activeConditions)
            append("Ground Slam knocks you down.", to: &state)
        }
        if enemy.id == "bone-rat-swarm", Int.random(in: 1...100) <= 20 {
            addCondition(Condition(type: .bleeding, remainingTurns: 1), to: &state.activeConditions)
            append("Gnawing Bones applies Bleeding for 1 turn.", to: &state)
        }
        if enemy.id == "bell-touched-warden", wasFirstAttack, Int.random(in: 1...100) <= 50 {
            addCondition(Condition(type: .weakened, remainingTurns: 2), to: &state.activeConditions)
            append("Bell-Touched Strike applies Weakened for 1 turn.", to: &state)
        }
        if enemy.id == "bell-drowned-warden", Int.random(in: 1...100) <= 25 {
            addCondition(Condition(type: .slowed, remainingTurns: 2), to: &state.activeConditions)
            append("Grave Pull applies Slowed for 1 turn.", to: &state)
        }
        if ["ember-skitter", "emberheart-golem"].contains(enemy.id),
           Int.random(in: 1...100) <= 20 {
            addCondition(Condition(type: .burning, remainingTurns: 1), to: &state.activeConditions)
            append("\(enemy.name) applies Burning for 1 turn.", to: &state)
        }
        if enemy.id == "furnace-hound", Int.random(in: 1...100) <= 25 {
            addCondition(Condition(type: .burning, remainingTurns: 1), to: &state.activeConditions)
            append("Flame Snap applies Burning for 1 turn.", to: &state)
        }
    }

    private static func applyStartOfTurnDamage(to hero: inout Hero, state: inout CombatState) {
        for condition in state.activeConditions {
            switch condition.type {
            case .bleeding:
                hero.currentHealth = max(0, hero.currentHealth - 1)
                append("Bleeding deals 1 physical damage.", to: &state)
            case .burning:
                let damage = applyIncomingFireReduction(1, hero: &hero, state: &state)
                hero.currentHealth = max(0, hero.currentHealth - damage)
                append("Burning deals \(damage) fire damage.", to: &state)
            default:
                break
            }
        }
    }

    private static func applyIncomingFireReduction(_ damage: Int, hero: inout Hero, state: inout CombatState) -> Int {
        guard damage > 0 else { return 0 }
        let available = hero.currentAdventureState.temporaryBonuses["emberShrineFireReduction", default: 0]
        guard available > 0 else { return damage }
        let reduction = min(damage, available)
        let remaining = available - reduction
        if remaining > 0 {
            hero.currentAdventureState.temporaryBonuses["emberShrineFireReduction"] = remaining
        } else {
            hero.currentAdventureState.temporaryBonuses["emberShrineFireReduction"] = nil
        }
        append("Shrine protection reduces incoming fire damage by \(reduction).", to: &state)
        return max(0, damage - reduction)
    }

    @discardableResult
    private static func tickConditions(_ conditions: inout [Condition]) -> [Condition] {
        var expired: [Condition] = []
        conditions = conditions.compactMap { condition in
            guard let turns = condition.remainingTurns else { return condition }
            guard turns > 1 else {
                expired.append(condition)
                return nil
            }
            var updated = condition
            updated.remainingTurns = turns - 1
            return updated
        }
        return expired
    }

    private static func tickHeroWindowConditions(_ state: inout CombatState) {
        let types: Set<ConditionType> = [.exposed, .marked, .slowed]
        for index in state.enemies.indices {
            let enemyName = EnemyData.enemy(id: state.enemies[index].enemyID)?.name ?? "Enemy"
            if state.enemies[index].cinderMarkPending {
                state.enemies[index].cinderMarkRemainingTurns -= 1
                if state.enemies[index].cinderMarkRemainingTurns <= 0 {
                    state.enemies[index].cinderMarkPending = false
                    state.enemies[index].conditions.removeAll { $0.type == .marked }
                    append("Cinder Mark expires on \(enemyName).", to: &state)
                }
            }
            let expired = tickConditions(&state.enemies[index].conditions, matching: types)
            for condition in expired {
                append("\(enemyName) is no longer \(condition.type.displayName).", to: &state)
            }
        }
    }

    private static func tickEnemyActionConditions(_ conditions: inout [Condition]) -> [Condition] {
        tickConditions(
            &conditions,
            matching: [.bleeding, .burning, .poisoned, .stunned, .weakened, .knockedDown]
        )
    }

    @discardableResult
    private static func tickConditions(
        _ conditions: inout [Condition],
        matching types: Set<ConditionType>
    ) -> [Condition] {
        var expired: [Condition] = []
        conditions = conditions.compactMap { condition in
            guard types.contains(condition.type),
                  let turns = condition.remainingTurns else { return condition }
            guard turns > 1 else {
                expired.append(condition)
                return nil
            }
            var updated = condition
            updated.remainingTurns = turns - 1
            return updated
        }
        return expired
    }

    private static func applyEnemyStartOfTurnDamage(
        enemy: Enemy,
        enemyState: inout CombatEnemyState,
        state: inout CombatState
    ) {
        for condition in enemyState.conditions {
            let damage: Int
            let damageType: DamageType
            switch condition.type {
            case .bleeding:
                damage = 1
                damageType = .physical
            case .burning:
                damage = 1
                damageType = .fire
            default:
                continue
            }
            append("\(enemy.name)'s \(condition.type.displayName) base damage: \(damage) \(damageType.rawValue).", to: &state)
            let resolution = resolveDamageModifiers(
                baseDamage: damage,
                damageType: damageType,
                target: enemy
            )
            for line in resolution.breakdownLines {
                append(line, to: &state)
            }
            enemyState.currentHealth = max(0, enemyState.currentHealth - resolution.finalDamage)
            append("Final damage: \(resolution.finalDamage) \(damageType.rawValue).", to: &state)
            if enemyState.currentHealth == 0 {
                append("\(enemy.name) is defeated by \(condition.type.displayName).", to: &state)
            }
        }
    }

    private static func applyAbilityCondition(
        _ condition: ConditionType,
        from ability: Ability,
        to enemyState: inout CombatEnemyState,
        enemy: Enemy,
        state: inout CombatState
    ) {
        guard !enemy.immunities.contains(condition) else {
            append("\(enemy.name) is immune to \(condition.displayName).", to: &state)
            return
        }
        if ability.id == "packwarden-strike",
           !enemyState.conditions.contains(where: { $0.type == .marked }) {
            return
        }
        let requestedDuration = ability.durationTurns ?? (condition == .burning ? 2 : 1)
        let duration: Int
        if [.exposed, .marked, .slowed].contains(condition) {
            duration = max(2, requestedDuration)
        } else {
            duration = requestedDuration
        }
        addCondition(Condition(type: condition, remainingTurns: duration), to: &enemyState.conditions)
        if condition == .exposed {
            append("\(ability.name) applies Exposed to \(enemy.name). Its Defence is reduced by 1 until the end of your next turn.", to: &state)
        } else {
            append("\(ability.name) applies \(condition.displayName) to \(enemy.name).", to: &state)
        }

        if ability.id == "trapmasters-gambit" {
            addCondition(Condition(type: .exposed, remainingTurns: 1), to: &enemyState.conditions)
            append("Trapmaster's Gambit also applies Exposed.", to: &state)
        } else if ability.id == "packwarden-strike" {
            append("The Mark leaves \(enemy.name) Weakened.", to: &state)
        }
    }

    private static func addCondition(_ condition: Condition, to conditions: inout [Condition]) {
        if let index = conditions.firstIndex(where: { $0.type == condition.type }) {
            let currentTurns = conditions[index].remainingTurns ?? 0
            let newTurns = condition.remainingTurns ?? 0
            conditions[index].remainingTurns = max(currentTurns, newTurns)
            return
        }
        conditions.append(condition)
    }

    private static func livingEnemies(in state: CombatState) -> [CombatEnemyState] {
        state.enemies.filter { $0.currentHealth > 0 }
    }

    private static func fleeTarget(for tier: EnemyTier) -> Int {
        switch tier {
        case .minor: return 10
        case .standard: return 12
        case .strong: return 15
        case .boss: return 18
        case .finalBoss: return Int.max
        }
    }

    private static func equippedWeapon(for hero: Hero) -> ItemDefinition? {
        if let weaponName = hero.equippedItems.slots[.mainWeapon],
           let weapon = ItemData.definition(named: weaponName),
           weapon.category == .weapon {
            return weapon
        }
        return hero.inventory.itemQuantities.keys
            .compactMap(ItemData.definition(named:))
            .first { $0.category == .weapon }
    }

    private static func attackAttribute(for weapon: ItemDefinition?) -> AttributeType {
        guard let weapon else { return .might }
        if weapon.name == "Rune Staff" {
            return .might
        }
        return weapon.attackAttribute ?? .might
    }

    private static func rollHeroDamage(hero: Hero, weapon: ItemDefinition?, critical: Bool) -> DamageRollResult {
        let attribute = attackAttribute(for: weapon)
        let modifier = hero.attributes.modifier(for: attribute)
        let expression = weapon?.damage?.components(separatedBy: " physical").first ?? "1d4"
        return rollDamage(
            expression: expression,
            attributeModifier: modifier,
            damageType: .physical,
            critical: critical
        )
    }

    private static func rollPathDamage(hero: Hero, weapon: ItemDefinition?, actionName: String, mode: HeroAttackMode, critical: Bool) -> DamageRollResult {
        switch actionName {
        case "Ember Bolt":
            return rollDamage(expression: "1d8", attributeModifier: hero.attributes.modifier(for: .mind), damageType: .fire, critical: critical)
        case "Vowblade Strike":
            var damage = rollHeroDamage(hero: hero, weapon: weapon, critical: critical)
            let oathfire = Int.random(in: 1...4)
            damage.total += oathfire
            damage.expression += " + 1d4 oathfire"
            return damage
        case "Relentless Assault":
            var damage = rollHeroDamage(hero: hero, weapon: weapon, critical: critical)
            let extra = Int.random(in: 1...8)
            damage.total += extra
            damage.expression += " + 1d8"
            return damage
        case "Frost Snare":
            return rollDamage(expression: "1d6", attributeModifier: hero.attributes.modifier(for: .mind), damageType: .frost, critical: critical)
        case "Cinder Mark":
            return rollDamage(expression: "1d6", attributeModifier: hero.attributes.modifier(for: .mind), damageType: .fire, critical: critical)
        case "Burning Surge":
            return rollDamage(expression: "2d8", attributeModifier: hero.attributes.modifier(for: .mind), damageType: .fire, critical: critical)
        case "Starfall Pulse", "Voidfall Pulse":
            return rollDamage(expression: "1d8", attributeModifier: hero.attributes.modifier(for: .mind), damageType: .arcane, critical: critical)
        case "Oathfire Smite":
            var damage = rollHeroDamage(hero: hero, weapon: weapon, critical: critical)
            damage.total += Int.random(in: 1...6) + Int.random(in: 1...6)
            damage.expression += " + 2d6 oathfire"
            return damage
        default:
            return rollHeroDamage(hero: hero, weapon: weapon, critical: critical)
        }
    }

    private static func resourceIssue(for ability: Ability, hero: Hero) -> String? {
        let cost = AbilityRules.resourceCost(for: ability)
        switch AbilityRules.resourceType(for: ability) {
        case .stamina where hero.currentStamina < cost:
            return "Not enough Stamina."
        case .focus where hero.currentFocus < cost:
            return "Not enough Focus."
        default:
            return nil
        }
    }

    private static func spendResource(for ability: Ability, hero: inout Hero) {
        let cost = AbilityRules.resourceCost(for: ability)
        guard cost > 0 else { return }
        switch AbilityRules.resourceType(for: ability) {
        case .stamina:
            hero.currentStamina = max(0, hero.currentStamina - cost)
        case .focus:
            hero.currentFocus = max(0, hero.currentFocus - cost)
        case .none:
            break
        }
    }

    private static func startCooldown(for ability: Ability, state: inout CombatState) {
        let cooldown = AbilityRules.cooldownTurns(for: ability)
        if cooldown > 0 {
            state.abilityCooldowns[ability.id] = cooldown
        }
    }

    private static func startCooldown(id: String, state: inout CombatState) {
        let cooldown = AbilityRules.cooldownTurns(for: id)
        if cooldown > 0 {
            state.abilityCooldowns[id] = cooldown
        }
    }

    private static func tickCooldowns(_ state: inout CombatState) {
        state.abilityCooldowns = state.abilityCooldowns.reduce(into: [:]) { partial, pair in
            let remaining = pair.value - 1
            if remaining > 0 {
                partial[pair.key] = remaining
            }
        }
    }

    private static func clearPendingAttackBonuses(_ state: inout CombatState) {
        state.pendingAttackBonus = 0
        state.pendingDamageBonus = 0
    }

    private static func resolveDamageModifiers(
        baseDamage: Int,
        damageType: DamageType,
        target: Enemy,
        bonuses: [DamageAdjustment] = [],
        reductions: [DamageAdjustment] = []
    ) -> DamageResolution {
        var damage = max(0, baseDamage)
        var lines: [String] = []

        for bonus in bonuses where bonus.amount > 0 {
            damage += bonus.amount
            lines.append("\(bonus.label): +\(bonus.amount) \(damageType.rawValue) damage.")
        }

        let weakness = target.weaknesses[damageType] ?? 0
        if weakness > 0 {
            damage += weakness
            lines.append("\(target.name) is weak to \(damageType.rawValue): +\(weakness) damage.")
        }

        let resistance = target.resistances[damageType] ?? 0
        if resistance > 0 {
            damage -= resistance
            lines.append("\(target.name) resists \(damageType.rawValue): -\(resistance) damage.")
        }

        for reduction in reductions where reduction.amount > 0 {
            damage -= reduction.amount
            lines.append("\(reduction.label): -\(reduction.amount) damage.")
        }

        return DamageResolution(finalDamage: max(0, damage), breakdownLines: lines)
    }

    private static func isFireSpell(actionName: String, mode: HeroAttackMode) -> Bool {
        if ["Ember Bolt", "Cinder Burst", "Burning Surge"].contains(actionName) {
            return true
        }
        if case let .ability(ability) = mode {
            return ability.damageType == .fire
        }
        return false
    }

    private static func applyCleaveDamage(from defeatedEnemyName: String, damage: Int, state: inout CombatState) {
        let cleaveAmount = max(1, damage / 2)
        guard let secondIndex = state.enemies.firstIndex(where: { $0.currentHealth > 0 }),
              let secondEnemy = EnemyData.enemy(id: state.enemies[secondIndex].enemyID) else {
            append("No second enemy is available for cleave damage.", to: &state)
            return
        }
        let resolution = resolveDamageModifiers(
            baseDamage: cleaveAmount,
            damageType: .physical,
            target: secondEnemy
        )
        state.enemies[secondIndex].currentHealth = max(
            0,
            state.enemies[secondIndex].currentHealth - resolution.finalDamage
        )
        append("Cleaving Blow defeats \(defeatedEnemyName). Half damage carries to \(secondEnemy.name).", to: &state)
        for line in resolution.breakdownLines {
            append(line, to: &state)
        }
        append("Final cleave damage: \(resolution.finalDamage) physical.", to: &state)
        if state.enemies[secondIndex].currentHealth == 0 {
            append("\(secondEnemy.name) is defeated.", to: &state)
        }
    }

    private static func rollDamage(
        expression: String,
        attributeModifier: Int,
        damageType: DamageType,
        critical: Bool
    ) -> DamageRollResult {
        let cleaned = expression.lowercased()
            .replacingOccurrences(of: damageType.rawValue, with: "")
            .replacingOccurrences(of: "physical", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let dicePattern = #"(\d*)d(4|6|8|10|12|20|100)"#
        let regex = try? NSRegularExpression(pattern: dicePattern)
        let matches = regex?.matches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) ?? []
        var dice: [Int] = []
        var diceTotal = 0

        for _ in 0..<(critical ? 2 : 1) {
            for match in matches {
                let countText = text(match, index: 1, source: cleaned)
                let dieText = text(match, index: 2, source: cleaned)
                let count = countText.isEmpty ? 1 : Int(countText) ?? 1
                let die = Int(dieText) ?? 4
                for _ in 0..<count {
                    let roll = Int.random(in: 1...die)
                    dice.append(roll)
                    diceTotal += roll
                }
            }
        }

        let expressionWithoutDice = matches.reversed().reduce(cleaned) { partial, match in
            guard let range = Range(match.range, in: partial) else { return partial }
            var copy = partial
            copy.replaceSubrange(range, with: "")
            return copy
        }
        let flatModifier = expressionWithoutDice
            .split(separator: "+")
            .flatMap { $0.split(separator: " ") }
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .reduce(0, +)

        let total = max(1, diceTotal + flatModifier + attributeModifier)
        return DamageRollResult(
            expression: expression.trimmingCharacters(in: .whitespacesAndNewlines),
            dice: dice,
            flatModifier: flatModifier,
            attributeModifier: attributeModifier,
            total: total,
            damageType: damageType
        )
    }

    private static func text(_ match: NSTextCheckingResult, index: Int, source: String) -> String {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: source) else {
            return ""
        }
        return String(source[swiftRange])
    }

    private static func append(_ entry: String, to state: inout CombatState) {
        state.combatLog.append(entry)
        if state.combatLog.count > 80 {
            state.combatLog.removeFirst(state.combatLog.count - 80)
        }
    }
}

private enum HeroAttackMode {
    case pathAttack
    case cleavingBlow
    case relentlessAssault
    case ability(Ability)

    var isPathAttack: Bool {
        if case .pathAttack = self { return true }
        return false
    }

    var isCleavingBlow: Bool {
        if case .cleavingBlow = self { return true }
        return false
    }
}
