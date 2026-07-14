import Foundation

enum AbilityImplementationStatus: String {
    case implemented = "Implemented"
    case passiveImplemented = "Passive implemented"
    case planningOnly = "Planning only"

    var isCombatAvailable: Bool {
        self == .implemented
    }

    var isActivePassive: Bool {
        self == .passiveImplemented
    }
}

enum AbilityRules {
    static func implementationStatus(for ability: Ability) -> AbilityImplementationStatus {
        if implementedCombatAbilityIDs.contains(ability.id) {
            return .implemented
        }
        if implementedPassiveAbilityIDs.contains(ability.id) {
            return .passiveImplemented
        }
        return .planningOnly
    }

    static func isCombatAvailable(_ ability: Ability) -> Bool {
        implementationStatus(for: ability).isCombatAvailable
    }

    static func cooldownTurns(for abilityID: String) -> Int {
        if subpathQuickTechniqueIDs.contains(abilityID) {
            return 3
        }
        switch abilityID {
        case "cleaving-blow": return 2
        case "tempest-step": return 2
        case "relentless-assault", "shadow-flurry", "hunters-volley": return 3
        case "catch-breath": return 4
        case "bastion-sweep", "whirlwind-cut", "shadow-chain", "scatterknives", "pack-assault",
             "piercing-volley", "cinder-burst", "astral-cascade", "dawnwave", "radiant-judgement":
            return 4
        case "shield-wall", "veil-strike", "dirty-trick", "sure-shot", "cinder-mark", "arcane-ward", "dawnward", "brand-of-judgement": return 3
        case "trapmasters-gambit", "packwarden-strike", "burning-surge", "starfall-pulse", "oathfire-smite": return 4
        case "frost-snare", "pinning-shot": return 2
        default: return 0
        }
    }

    static func cooldownTurns(for ability: Ability) -> Int {
        ability.cooldown ?? cooldownTurns(for: ability.id)
    }

    static func focusCost(for ability: Ability) -> Int {
        guard resourceType(for: ability) == .focus else { return 0 }
        return resourceCost(for: ability)
    }

    static func staminaCost(for ability: Ability) -> Int {
        guard resourceType(for: ability) == .stamina else { return 0 }
        return resourceCost(for: ability)
    }

    static func resourceType(for ability: Ability) -> AbilityResourceType {
        if ability.resourceType != .none {
            return ability.resourceType
        }
        if ability.cost?.localizedCaseInsensitiveContains("Stamina") == true { return .stamina }
        if ability.cost?.localizedCaseInsensitiveContains("Focus") == true { return .focus }
        return .none
    }

    static func resourceCost(for ability: Ability) -> Int {
        guard let cost = ability.cost else { return 0 }
        let digits = cost.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    static func availabilityText(for ability: Ability, state: CombatState?, hero: Hero) -> String {
        let cooldown = state?.abilityCooldowns[ability.id] ?? 0
        if cooldown > 0 {
            return "Cooldown: \(cooldown) turn\(cooldown == 1 ? "" : "s")"
        }
        let cost = resourceCost(for: ability)
        switch resourceType(for: ability) {
        case .stamina where hero.currentStamina < cost:
            return "Needs \(cost) Stamina"
        case .focus where hero.currentFocus < cost:
            return "Needs \(cost) Focus"
        default:
            break
        }
        let cooldownTurns = cooldownTurns(for: ability)
        if cooldownTurns > 0 {
            return "Ready • \(cooldownTurns)-turn cooldown"
        }
        return ability.cost.map { "Ready • \($0)" } ?? "Ready"
    }

    static func detailText(for ability: Ability) -> String {
        var parts = [ability.summary]
        let cooldown = cooldownTurns(for: ability)
        if cooldown > 0 {
            parts.append("Cooldown: \(cooldown) turn\(cooldown == 1 ? "" : "s").")
        } else if let useLimit = ability.useLimit {
            parts.append(useLimit)
        }
        if let cost = ability.cost {
            parts.append("Cost: \(cost).")
        }
        return parts.joined(separator: " ")
    }

    static let subpathQuickTechniqueIDs: Set<String> = [
        "shield-brace", "cracking-bash",
        "elemental-flask", "tempest-feint",
        "veil-step", "marked-in-shadow",
        "loaded-trick", "pocket-sand",
        "pack-instinct", "hamstring-call",
        "steady-aim", "pinning-threat",
        "kindled-focus", "cinder-veil",
        "starlit-ward", "fracture-pattern",
        "dawns-grace", "mercys-rebuke",
        "judgement-spark", "brand-of-doubt"
    ]

    private static let implementedCombatAbilityIDs: Set<String> = Set([
        "guarded-strike", "opening-strike", "marked-shot", "ember-bolt", "vowblade-strike",
        "cleaving-blow", "frost-snare", "mend-the-wounded",
        "tempest-step", "sure-shot", "veil-strike", "cinder-mark",
        "relentless-assault", "burning-surge", "starfall-pulse",
        "catch-breath",
        "bastion-sweep", "whirlwind-cut", "shadow-chain", "scatterknives", "pack-assault",
        "piercing-volley", "cinder-burst", "astral-cascade", "dawnwave", "radiant-judgement"
    ]).union(subpathQuickTechniqueIDs)

    private static let implementedPassiveAbilityIDs: Set<String> = []

    static let catchBreath = Ability(
        id: "catch-breath",
        name: "Catch Breath",
        summary: "Regain your footing. Restore 1 Stamina.",
        actionType: .quick,
        requiredLevel: 1,
        tags: ["Quick Action", "Recovery"],
        source: .path,
        cooldown: 4,
        targetType: .selfTarget,
        resourceType: .none,
        combatType: .utility
    )
}
