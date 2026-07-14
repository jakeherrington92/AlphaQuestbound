import Foundation

struct LevelUpPreview: Equatable {
    var oldLevel: Int
    var newLevel: Int
    var oldMaxHealth: Int
    var newMaxHealth: Int
    var hpGain: Int
    var oldMaxFocus: Int
    var newMaxFocus: Int
    var focusGain: Int
    var oldMaxStamina: Int
    var newMaxStamina: Int
    var staminaGain: Int
    var oldTrainingBonus: Int
    var newTrainingBonus: Int
    var unlocks: [String]
    var newAbilities: [Ability]
    var requiresAttributeIncrease: Bool
    var requiresSubpathSelection: Bool
}

enum AttributeIncreaseMode: String, CaseIterable, Identifiable {
    case oneAttributePlusTwo
    case twoAttributesPlusOne

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneAttributePlusTwo:
            return "+2 to one attribute"
        case .twoAttributesPlusOne:
            return "+1 to two attributes"
        }
    }
}

enum LevelUpEngine {
    static func pendingNextLevel(for hero: Hero) -> Int? {
        guard hero.level < GameConstants.versionOneLevelCap else { return nil }
        let nextLevel = hero.level + 1
        guard let requiredXP = ProgressionRules.versionOne.xpRequired(for: nextLevel),
              hero.xp >= requiredXP else { return nil }
        return nextLevel
    }

    static func preview(hero: Hero, targetLevel: Int, attributeIncreases: [AttributeType: Int] = [:]) -> LevelUpPreview {
        let oldTrainingBonus = ProgressionRules.versionOne.trainingBonus(for: hero.level) ?? 0
        let newTrainingBonus = ProgressionRules.versionOne.trainingBonus(for: targetLevel) ?? oldTrainingBonus
        let updatedAttributes = attributes(hero.attributes, applying: attributeIncreases)
        let hpGain = hpGain(for: hero.path, attributes: updatedAttributes)
        let oldFocus = hero.maxFocus
        let newFocus = maxFocus(for: hero.path, attributes: updatedAttributes, level: targetLevel)
        let newStamina = maxStamina(for: hero.path, level: targetLevel)
        let newAbilities = abilitiesUnlocked(path: hero.path, subpathID: hero.selectedSubpath?.id, level: targetLevel)

        return LevelUpPreview(
            oldLevel: hero.level,
            newLevel: targetLevel,
            oldMaxHealth: hero.maxHealth,
            newMaxHealth: hero.maxHealth + hpGain,
            hpGain: hpGain,
            oldMaxFocus: oldFocus,
            newMaxFocus: newFocus,
            focusGain: max(0, newFocus - oldFocus),
            oldMaxStamina: hero.maxStamina,
            newMaxStamina: newStamina,
            staminaGain: max(0, newStamina - hero.maxStamina),
            oldTrainingBonus: oldTrainingBonus,
            newTrainingBonus: newTrainingBonus,
            unlocks: unlocks(for: hero, targetLevel: targetLevel, newAbilities: newAbilities),
            newAbilities: newAbilities,
            requiresAttributeIncrease: ProgressionRules.versionOne.attributeIncreaseLevels.contains(targetLevel),
            requiresSubpathSelection: targetLevel == 3 && hero.selectedSubpath == nil
        )
    }

    static func applyLevelUp(
        hero: Hero,
        targetLevel: Int,
        attributeIncreases: [AttributeType: Int],
        selectedSubpath: Subpath?,
        selectedPortrait: Portrait?
    ) -> Hero {
        var updated = hero
        let oldFocus = hero.maxFocus
        let oldStamina = hero.maxStamina
        updated.attributes = attributes(hero.attributes, applying: attributeIncreases)
        let hpGain = hpGain(for: hero.path, attributes: updated.attributes)
        updated.level = min(targetLevel, GameConstants.versionOneLevelCap)
        updated.maxHealth += hpGain
        updated.currentHealth = min(updated.maxHealth, updated.currentHealth + hpGain)

        let newMaxFocus = maxFocus(for: updated.path, attributes: updated.attributes, level: updated.level)
        updated.focus = newMaxFocus
        updated.maxFocus = newMaxFocus
        if newMaxFocus > oldFocus {
            updated.currentFocus = min(newMaxFocus, updated.currentFocus + (newMaxFocus - oldFocus))
        } else {
            updated.currentFocus = min(updated.currentFocus, newMaxFocus)
        }
        let newMaxStamina = maxStamina(for: updated.path, level: updated.level)
        updated.maxStamina = newMaxStamina
        if newMaxStamina > oldStamina {
            updated.currentStamina = min(newMaxStamina, updated.currentStamina + (newMaxStamina - oldStamina))
        } else {
            updated.currentStamina = min(updated.currentStamina, newMaxStamina)
        }

        if let selectedSubpath, updated.selectedSubpath == nil {
            updated.selectedSubpath = selectedSubpath
            updated.subpath = selectedSubpath.name
        }
        if let selectedPortrait {
            updated.portrait = selectedPortrait
        }

        let newAbilities = abilitiesUnlocked(path: updated.path, subpathID: updated.selectedSubpath?.id, level: updated.level)
        for ability in newAbilities where !updated.abilities.contains(where: { $0.id == ability.id }) {
            updated.abilities.append(ability)
        }

        updated.lastPlayedAt = Date()
        return updated
    }

    static func attributes(_ attributes: Attributes, applying increases: [AttributeType: Int]) -> Attributes {
        var updated = attributes
        for (attribute, increase) in increases {
            let current = updated.score(for: attribute)
            let capped = min(GameConstants.versionOneAttributeCap, current + increase)
            switch attribute {
            case .might: updated.might = capped
            case .agility: updated.agility = capped
            case .endurance: updated.endurance = capped
            case .mind: updated.mind = capped
            case .instinct: updated.instinct = capped
            case .presence: updated.presence = capped
            }
        }
        return updated
    }

    static func maxFocus(for path: Path, attributes: Attributes, level: Int) -> Int {
        switch path {
        case .embermage:
            return max(1, 2 + attributes.modifier(for: .mind) + level)
        case .oathkeeper:
            return max(1, 1 + attributes.modifier(for: .presence) + level)
        case .bladeguard, .shadowstep, .wildwarden:
            return 0
        }
    }

    static func maxStamina(for path: Path, level: Int) -> Int {
        Hero.staminaMaximum(path: path, level: level)
    }

    static func hpGain(for path: Path, attributes: Attributes) -> Int {
        let enduranceModifier = attributes.modifier(for: .endurance)
        let base: Int
        switch path {
        case .bladeguard:
            base = 7
        case .shadowstep:
            base = 5
        case .wildwarden:
            base = 6
        case .embermage:
            base = 4
        case .oathkeeper:
            base = 6
        }
        return max(1, base + enduranceModifier)
    }

    static func abilitiesUnlocked(path: Path, subpathID: String?, level: Int) -> [Ability] {
        switch level {
        case 2:
            return [levelTwoAbility(for: path)]
        case 3:
            guard let subpathID else { return [] }
            return levelThreeTechniques(for: subpathID)
        case 4:
            guard let subpathID else { return [] }
            return [levelFourAbility(for: subpathID)]
        case 5:
            guard let subpathID else { return [] }
            return [
                levelFiveSubpathCapstone(for: subpathID),
                levelFiveAbility(for: subpathID)
            ]
        default:
            return []
        }
    }

    private static func levelThreeTechniques(for subpathID: String) -> [Ability] {
        switch subpathID {
        case "iron-vanguard":
            return [
                technique("shield-brace", "Shield Brace", "Brace behind your shield. Gain Guarded and reduce the next physical hit by 1.", .buff, .selfTarget, .guarded, "Shield Brace fortifies your guard."),
                technique("cracking-bash", "Cracking Bash", "Rattle an enemy's guard. Apply Exposed for 1 turn.", .debuff, .enemy, .exposed, "Cracking Bash exposes the enemy.")
            ]
        case "storm-duelist":
            return [
                Ability(
                    id: "elemental-flask",
                    name: "Elemental Flask",
                    summary: "Coat your weapon with a volatile flask. Roll 1d4 for Fire, Water/Ice, Wind or Earth. Your next successful weapon attack deals +1d4 elemental damage.",
                    actionType: .quick,
                    requiredLevel: 3,
                    useLimit: "3 uses per adventure",
                    tags: ["Level 3", "Quick Technique", "Buff", "Weapon Coating", "Elemental"],
                    techniqueType: .buff,
                    source: .subpath,
                    cooldown: 3,
                    targetType: .selfTarget,
                    combatLogText: "Elemental Flask coats your weapon."
                ),
                technique("tempest-feint", "Tempest Feint", "Draw the enemy off-balance. Apply Weakened for 1 turn.", .debuff, .enemy, .weakened, "Tempest Feint weakens the enemy.")
            ]
        case "nightblade":
            return [
                technique("veil-step", "Veil Step", "Slip into shadow. Gain +1 Defence and +1 to your next attack this turn.", .buff, .selfTarget, nil, "Veil Step sharpens your attack and defence."),
                technique("marked-in-shadow", "Marked in Shadow", "Mark a weak point. Apply Exposed for 1 turn.", .debuff, .enemy, .exposed, "Marked in Shadow exposes a weak point.")
            ]
        case "trickhand":
            return [
                technique("loaded-trick", "Loaded Trick", "Prepare a trick. Your next item or attack gains a small bonus.", .buff, .selfTarget, nil, "Loaded Trick prepares a small offensive bonus."),
                technique("pocket-sand", "Pocket Sand", "Blind and distract an enemy. Its next attack suffers -1.", .debuff, .enemy, nil, "Pocket Sand disrupts the enemy's next attack.")
            ]
        case "beastcaller":
            return [
                technique("pack-instinct", "Pack Instinct", "Move with pack instinct. Gain +1 Defence until next turn.", .buff, .selfTarget, nil, "Pack Instinct heightens your defence."),
                technique("hamstring-call", "Hamstring Call", "Strike at movement. Apply Slowed for 1 turn.", .debuff, .enemy, .slowed, "Hamstring Call slows the enemy.")
            ]
        case "deepwood-archer":
            return [
                technique("steady-aim", "Steady Aim", "Take careful aim. Your next ranged attack gains +1 to hit and damage.", .buff, .selfTarget, nil, "Steady Aim prepares a precise strike."),
                technique("pinning-threat", "Pinning Threat", "Keep an enemy under pressure. Apply Marked for 1 turn.", .debuff, .enemy, .marked, "Pinning Threat marks the enemy.")
            ]
        case "flamecaller":
            return [
                technique("kindled-focus", "Kindled Focus", "Restore 1 Focus. At full Focus, empower your next fire spell for +1 fire damage.", .buff, .selfTarget, nil, "Kindled Focus restores or empowers your magic."),
                technique("cinder-veil", "Cinder Veil", "Smoke and cinders expose the enemy. Apply Exposed.", .debuff, .enemy, .exposed, "Cinder Veil exposes the enemy.")
            ]
        case "starweaver":
            return [
                technique("starlit-ward", "Void Ward", "Wrap yourself in starless magic. Reduce the next incoming damage by 1d4.", .buff, .selfTarget, nil, "Void Ward surrounds you."),
                technique("fracture-pattern", "Fracture Pattern", "Unravel an enemy's arcane pattern. Apply Exposed for 1 turn.", .debuff, .enemy, .exposed, "Fracture Pattern exposes the enemy.")
            ]
        case "dawnshield":
            return [
                technique("dawns-grace", "Dawn's Grace", "Call a small blessing. Restore 1d4 HP.", .buff, .selfTarget, nil, "Dawn's Grace restores your health."),
                technique("mercys-rebuke", "Mercy's Rebuke", "Rebuke an enemy's violence. Apply Weakened for 1 turn.", .debuff, .enemy, .weakened, "Mercy's Rebuke weakens the enemy.")
            ]
        case "judgement-flame":
            return [
                technique("judgement-spark", "Judgement Spark", "Ignite your oath. Your next attack deals +1 oathfire.", .buff, .selfTarget, nil, "Judgement Spark empowers your next attack."),
                technique("brand-of-doubt", "Brand of Doubt", "Brand an enemy with judgement. Apply Marked and weaken its next attack.", .debuff, .enemy, .marked, "Brand of Doubt marks and weakens the enemy.")
            ]
        default:
            return []
        }
    }

    private static func technique(
        _ id: String,
        _ name: String,
        _ summary: String,
        _ type: TechniqueType,
        _ target: AbilityTargetType,
        _ condition: ConditionType?,
        _ log: String
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            summary: summary,
            actionType: .quick,
            requiredLevel: 3,
            conditionApplied: condition,
            tags: ["Level 3", "Quick Technique", type.rawValue.capitalized],
            techniqueType: type,
            source: .subpath,
            cooldown: 3,
            targetType: target,
            durationTurns: 1,
            combatLogText: log
        )
    }

    private static func unlocks(for hero: Hero, targetLevel: Int, newAbilities: [Ability]) -> [String] {
        var unlocks: [String] = []
        switch targetLevel {
        case 2:
            unlocks.append("New Path ability")
            unlocks.append("Attribute increase")
        case 3:
            unlocks.append("Choose Subpath")
            unlocks.append("Training Bonus increases to +3")
        case 4:
            unlocks.append("Subpath ability")
            unlocks.append("Attribute increase")
        case 5:
            unlocks.append("Signature ability")
            unlocks.append("Attribute increase")
            unlocks.append("Training Bonus increases to +4")
        default:
            break
        }
        unlocks.append(contentsOf: newAbilities.map { "Ability: \($0.name)" })
        if targetLevel >= GameConstants.versionOneLevelCap {
            unlocks.append("Version 1 level cap reached")
        }
        return unlocks
    }

    private static func levelTwoAbility(for path: Path) -> Ability {
        switch path {
        case .bladeguard:
            return ability("cleaving-blow", "Cleaving Blow", "Melee attack. On hit, deal weapon damage. If this defeats an enemy, deal half the damage rolled to another enemy.", .major, 2, .physical, nil, nil, "Once per combat")
        case .shadowstep:
            return ability("quick-cut", "Quick Cut", "Light weapon attack with +2 to hit and -1 damage.", .major, 2, .physical, nil, nil, "At-will")
        case .wildwarden:
            return ability("pinning-shot", "Pinning Shot", "Ranged attack. On hit, deal weapon damage and the enemy's next attack roll has -1.", .major, 2, .physical, nil, nil, "Once per combat")
        case .embermage:
            return ability("frost-snare", "Frost Snare", "Spell attack using Mind. On hit, deal 1d6 frost and apply Exposed until the end of your next turn.", .major, 2, .frost, .exposed, "1 Focus", nil)
        case .oathkeeper:
            return ability("mend-the-wounded", "Mend the Wounded", "Restore 1d6 + Presence modifier HP.", .quick, 2, nil, nil, "1 Focus", nil)
        }
    }

    private static func levelFourAbility(for subpathID: String) -> Ability {
        switch subpathID {
        case "iron-vanguard":
            return ability("shield-wall", "Shield Wall", "Gain +2 Defence until start of next turn. If also using Defend this turn, reduce incoming physical damage by 2.", .quick, 4, nil, nil, nil, "Once per combat")
        case "storm-duelist":
            return ability("tempest-step", "Tempest Step", "Next melee attack this turn gains +1 to hit and +1 damage.", .quick, 4, nil, nil, nil, "Once per combat")
        case "nightblade":
            return ability("veil-strike", "Veil Strike", "On hit, deal weapon damage and apply Exposed until start next turn.", .major, 4, .shadow, .exposed, "1 Stamina", nil)
        case "trickhand":
            return ability("dirty-trick", "Dirty Trick", "Apply Weakened or Exposed to one enemy until start next turn.", .quick, 4, nil, .weakened, nil, "Once per combat")
        case "beastcaller":
            return ability("companions-instinct", "Companion's Instinct", "When you Mark an enemy, the next attack against that enemy gains +1 to hit. Future pet also gains +1.", .passive, 4, nil, .marked, nil, nil)
        case "deepwood-archer":
            return ability("sure-shot", "Sure Shot", "Next ranged attack this turn gains +2 to hit.", .quick, 4, nil, nil, "1 Stamina", nil)
        case "flamecaller":
            return Ability(
                id: "cinder-mark",
                name: "Cinder Mark",
                summary: "Mark an enemy with embers. Your next successful fire spell against that enemy deals +1d6 fire damage.",
                actionType: .quick,
                requiredLevel: 4,
                damageType: .fire,
                conditionApplied: .marked,
                cost: "1 Focus",
                useLimit: nil,
                tags: ["Level 4", "Quick Setup", "Fire"],
                source: .subpath,
                cooldown: 3,
                targetType: .enemy,
                durationTurns: 2,
                combatLogText: "Cinder Mark brands the enemy with burning magic."
            )
        case "starweaver":
            return ability("arcane-ward", "Void Ward", "Bend starless arcane patterns to reduce the next incoming damage by 1d6.", .quick, 4, .arcane, nil, "1 Focus", "Once per combat")
        case "dawnshield":
            return ability("dawnward", "Dawnward", "Gain +2 Defence and resistance 2 against the next damage taken.", .quick, 4, nil, .guarded, "1 Focus", "Once per combat")
        default:
            return ability("brand-of-judgement", "Brand of Judgement", "Mark enemy. Next successful melee attack against it deals +1d6 Oathfire.", .quick, 4, .oathfire, .marked, "1 Focus", "Once per combat")
        }
    }

    private static func levelFiveAbility(for subpathID: String) -> Ability {
        switch subpathID {
        case "iron-vanguard":
            return ability("iron-reprisal", "Iron Reprisal", "When an enemy misses with a physical attack, immediately deal damage equal to Might modifier + shield bonus.", .passive, 5, .physical, nil, nil, "Once per combat")
        case "storm-duelist":
            return ability("relentless-assault", "Relentless Assault", "On hit, weapon damage +1d8 physical.", .major, 5, .physical, nil, "1 Stamina", nil)
        case "nightblade":
            return ability("shadow-flurry", "Shadow Flurry", "Make two dagger attacks. If enemy is Exposed, add +1d6 to one attack.", .major, 5, .shadow, nil, "1 Stamina", nil)
        case "trickhand":
            return ability("trapmasters-gambit", "Trapmaster's Gambit", "Agility attack vs Defence. On hit, deal 1d6 physical and apply Slowed + Exposed for 1 turn.", .major, 5, .physical, .slowed, nil, "Once per combat")
        case "beastcaller":
            return ability("packwarden-strike", "Packwarden Strike", "Ranged or melee attack. On hit, weapon damage +1d6. If enemy is Marked, apply Weakened.", .major, 5, .physical, .weakened, "1 Stamina", nil)
        case "deepwood-archer":
            return ability("hunters-volley", "Hunter's Volley", "Make two ranged attacks.", .major, 5, .physical, nil, "1 Stamina", nil)
        case "flamecaller":
            return ability("burning-surge", "Burning Surge", "Spell attack using Mind. On hit, deal 2d8 fire and apply Burning.", .major, 5, .fire, .burning, "2 Focus", "Once per combat")
        case "starweaver":
            return ability("starfall-pulse", "Voidfall Pulse", "Spell attack using Mind. On hit, deal 1d8 arcane and apply Stunned until start enemy's next turn.", .major, 5, .arcane, .stunned, "2 Focus", "Once per combat")
        case "dawnshield":
            return ability("stand-unbroken", "Stand Unbroken", "When you would be reduced to 0 HP, stay at 1 HP and gain Guarded until start next turn.", .passive, 5, nil, .guarded, nil, "Once per adventure")
        default:
            return ability("oathfire-smite", "Oathfire Smite", "Melee attack. On hit, weapon damage +2d6 Oathfire and apply Weakened.", .major, 5, .oathfire, .weakened, "2 Focus", "Once per combat")
        }
    }

    private static func levelFiveSubpathCapstone(for subpathID: String) -> Ability {
        switch subpathID {
        case "iron-vanguard":
            return Ability(
                id: "bastion-sweep",
                name: "Bastion Sweep",
                summary: "Strike every enemy with your weapon, then gain Guarded until your next turn.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Iron Vanguard", "Weapon"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .stamina,
                combatType: .physicalMelee
            )
        case "storm-duelist":
            return Ability(
                id: "whirlwind-cut",
                name: "Whirlwind Cut",
                summary: "Sweep your weapon through all nearby enemies. Make a separate weapon attack against each enemy.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Storm Duelist", "Weapon"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .stamina,
                combatType: .physicalMelee
            )
        case "nightblade":
            return Ability(
                id: "shadow-chain",
                name: "Shadow Chain",
                summary: "Slip between foes and strike up to 2 enemies. Exposed targets take +1 damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Nightblade", "Weapon"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .twoEnemies,
                resourceType: .stamina,
                combatType: .physicalMelee
            )
        case "trickhand":
            return Ability(
                id: "scatterknives",
                name: "Scatterknives",
                summary: "Hurl concealed blades at every enemy. Each target takes a separate weapon attack at -1 damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Trickhand", "Weapon"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .stamina,
                combatType: .physicalRanged
            )
        case "beastcaller":
            return Ability(
                id: "pack-assault",
                name: "Pack Assault",
                summary: "Strike up to 2 enemies. Marked targets take +2 damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Beastcaller", "Weapon"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .twoEnemies,
                resourceType: .stamina,
                combatType: .physicalMelee
            )
        case "deepwood-archer":
            return Ability(
                id: "piercing-volley",
                name: "Piercing Volley",
                summary: "Loose precise shots at up to 2 enemies. Marked targets take +1 damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .physical,
                cost: "2 Stamina",
                tags: ["Level 5", "Deepwood Archer", "Ranged"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .twoEnemies,
                resourceType: .stamina,
                combatType: .physicalRanged
            )
        case "flamecaller":
            return Ability(
                id: "cinder-burst",
                name: "Cinder Burst",
                summary: "Primary target takes 1d8 + Mind fire. Other living enemies take 1d4 fire splash damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .fire,
                cost: "1 Focus",
                tags: ["Level 5", "Flamecaller", "Fire"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .primaryPlusSplash,
                resourceType: .focus,
                combatType: .spell
            )
        case "starweaver":
            return Ability(
                id: "astral-cascade",
                name: "Astral Cascade",
                summary: "Unleash falling starlight. All enemies take 1d6 + Mind arcane damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .arcane,
                cost: "1 Focus",
                tags: ["Level 5", "Voidweaver", "Void", "Arcane", "Disruption"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .focus,
                combatType: .spell
            )
        case "dawnshield":
            return Ability(
                id: "dawnwave",
                name: "Dawnwave",
                summary: "Send a protective wave across the battlefield. All enemies take 1d4 + Presence oathfire damage and you gain Guarded.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .oathfire,
                cost: "1 Focus",
                tags: ["Level 5", "Dawnshield", "Oathfire"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .focus,
                combatType: .oath
            )
        default:
            return Ability(
                id: "radiant-judgement",
                name: "Radiant Judgement",
                summary: "Call judgement across the battlefield. All enemies take 1d6 + Presence oathfire damage.",
                actionType: .major,
                requiredLevel: 5,
                damageType: .oathfire,
                cost: "1 Focus",
                tags: ["Level 5", "Judgement Flame", "Oathfire"],
                source: .subpath,
                cooldown: 4,
                targetType: .enemy,
                targetPattern: .allEnemies,
                resourceType: .focus,
                combatType: .oath
            )
        }
    }

    private static func ability(
        _ id: String,
        _ name: String,
        _ summary: String,
        _ actionType: ActionType,
        _ level: Int,
        _ damageType: DamageType?,
        _ condition: ConditionType?,
        _ cost: String?,
        _ useLimit: String?
    ) -> Ability {
        Ability(
            id: id,
            name: name,
            summary: summary,
            actionType: actionType,
            requiredLevel: level,
            damageType: damageType,
            conditionApplied: condition,
            cost: cost,
            useLimit: useLimit,
            tags: ["Level \(level)"]
        )
    }
}
