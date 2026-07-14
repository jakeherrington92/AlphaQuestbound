import Foundation

enum AttributeType: String, CaseIterable, Codable, Hashable, Identifiable {
    case might
    case agility
    case endurance
    case mind
    case instinct
    case presence

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .might: return "Might"
        case .agility: return "Agility"
        case .endurance: return "Endurance"
        case .mind: return "Mind"
        case .instinct: return "Instinct"
        case .presence: return "Presence"
        }
    }

    var usageDescription: String {
        switch self {
        case .might:
            return "Melee attacks, melee damage, lifting, breaking, forcing doors and resisting knockback."
        case .agility:
            return "Ranged attacks, dagger attacks, stealth, thievery, initiative, dodging and some escape checks."
        case .endurance:
            return "HP, poison resistance, harsh conditions and physical strain."
        case .mind:
            return "Lore, puzzles, relics, arcana and most spell attacks."
        case .instinct:
            return "Awareness, survival, tracking, detecting danger and reading enemies."
        case .presence:
            return "Persuasion, intimidation, willpower, resisting fear and oath-based magic."
        }
    }
}

enum SkillType: String, CaseIterable, Codable, Hashable, Identifiable {
    case athletics
    case stealth
    case thievery
    case survival
    case awareness
    case lore
    case arcana
    case persuasion
    case intimidation
    case endurance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .athletics: return "Athletics"
        case .stealth: return "Stealth"
        case .thievery: return "Thievery"
        case .survival: return "Survival"
        case .awareness: return "Awareness"
        case .lore: return "Lore"
        case .arcana: return "Arcana"
        case .persuasion: return "Persuasion"
        case .intimidation: return "Intimidation"
        case .endurance: return "Endurance"
        }
    }

    var linkedAttribute: AttributeType {
        switch self {
        case .athletics:
            return .might
        case .stealth, .thievery:
            return .agility
        case .survival, .awareness:
            return .instinct
        case .lore, .arcana:
            return .mind
        case .persuasion, .intimidation:
            return .presence
        case .endurance:
            return .endurance
        }
    }

    var usageDescription: String {
        switch self {
        case .athletics:
            return "Climbing, jumping, swimming, grappling, breaking obstacles and feats of raw physical force."
        case .stealth:
            return "Moving quietly, hiding, stalking enemies and slipping past danger without drawing notice."
        case .thievery:
            return "Picking locks, disabling simple mechanisms, sleight of hand and delicate tool work."
        case .survival:
            return "Tracking, foraging, navigating wild places and enduring the hazards of road and ruin."
        case .awareness:
            return "Spotting ambushes, hearing movement, reading rooms and noticing hidden details."
        case .lore:
            return "History, customs, legends, monsters, relics and remembered scraps of useful knowledge."
        case .arcana:
            return "Magic, runes, spellcraft, enchanted objects and unstable supernatural phenomena."
        case .persuasion:
            return "Swaying others with honesty, charm, diplomacy, bargains and calm reasoning."
        case .intimidation:
            return "Pressuring others through threat, presence, reputation and forceful command."
        case .endurance:
            return "Resisting poison, exhaustion, hunger, harsh weather and other physical strain."
        }
    }
}

enum Rarity: String, CaseIterable, Codable, Hashable, Identifiable {
    case common
    case uncommon
    case rare
    case epic
    case legendary
    case mythic

    var id: String { rawValue }
}

enum ItemCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case weapon
    case armour
    case charm
    case consumable
    case material
    case miscellaneous
    case questItem

    var id: String { rawValue }
}

enum ActionType: String, CaseIterable, Codable, Hashable, Identifiable {
    case quick
    case major
    case passive

    var id: String { rawValue }
}

enum DamageType: String, CaseIterable, Codable, Hashable, Identifiable {
    case physical
    case fire
    case frost
    case poison
    case shock
    case shadow
    case oathfire
    case arcane

    var id: String { rawValue }
}

enum ConditionType: String, CaseIterable, Codable, Hashable, Identifiable {
    case bleeding
    case burning
    case poisoned
    case slowed
    case stunned
    case guarded
    case marked
    case weakened
    case exposed
    case knockedDown

    var id: String { rawValue }
}

enum EnemyTier: String, CaseIterable, Codable, Hashable, Identifiable {
    case minor
    case standard
    case strong
    case boss
    case finalBoss

    var id: String { rawValue }
}

enum EquipmentSlot: String, CaseIterable, Codable, Hashable, Identifiable {
    case mainWeapon
    case offHand
    case head
    case chest
    case hands
    case legs
    case feet
    case charm1
    case charm2

    var id: String { rawValue }
}

enum Origin: String, CaseIterable, Codable, Hashable, Identifiable {
    case hearthborn = "Hearthborn"
    case moonElf = "Moon Elf"
    case stonekin = "Stonekin"
    case ironblood = "Ironblood"
    case smallfolk = "Smallfolk"
    case starborn = "Starborn"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .hearthborn:
            return "Steady folk whose courage is kindled by home, kin and stubborn hope."
        case .moonElf:
            return "Keen-eyed wanderers at ease under moonlight, ruins and shadowed stone."
        case .stonekin:
            return "Enduring people shaped by deep halls, old mountains and patient strength."
        case .ironblood:
            return "Hard-driving survivors who answer danger with force and grit."
        case .smallfolk:
            return "Quick-handed, quick-witted people who thrive where others overlook them."
        case .starborn:
            return "Stargazing wanderers with sharp memories for old magic, signs and sky-lore."
        }
    }
}

struct OriginFeature: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var skillBonuses: [SkillType: Int]
}

enum Path: String, CaseIterable, Codable, Hashable, Identifiable {
    case bladeguard = "Bladeguard"
    case shadowstep = "Shadowstep"
    case wildwarden = "Wildwarden"
    case embermage = "Embermage"
    case oathkeeper = "Oathkeeper"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .bladeguard:
            return "Physical melee defender."
        case .shadowstep:
            return "Rogue and precision damage."
        case .wildwarden:
            return "Ranged survivalist."
        case .embermage:
            return "Spellcaster."
        case .oathkeeper:
            return "Hybrid warrior and support."
        }
    }
}

typealias HeroPath = Path

struct Subpath: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var parentPath: Path
    var summary: String
    var unlockLevel: Int
}

enum TechniqueType: String, Codable, Hashable {
    case buff
    case debuff
}

enum AbilitySource: String, Codable, Hashable {
    case path
    case subpath
}

enum AbilityTargetType: String, Codable, Hashable {
    case selfTarget
    case enemy
    case allyFuture
}

enum AbilityTargetPattern: String, Codable, Hashable {
    case singleEnemy
    case allEnemies
    case twoEnemies
    case primaryPlusSplash

    var displayName: String {
        switch self {
        case .singleEnemy: return "One Enemy"
        case .allEnemies: return "All Enemies"
        case .twoEnemies: return "Up to 2 Enemies"
        case .primaryPlusSplash: return "Primary + Splash"
        }
    }
}

enum AbilityResourceType: String, Codable, Hashable {
    case none
    case stamina
    case focus
}

enum AbilityCombatType: String, Codable, Hashable {
    case physicalMelee
    case physicalRanged
    case spell
    case oath
    case utility
}

enum ElementalFlaskElement: String, Codable, Hashable {
    case fire
    case waterIce
    case wind
    case earth

    var displayName: String {
        switch self {
        case .fire: return "Fire"
        case .waterIce: return "Water/Ice"
        case .wind: return "Wind"
        case .earth: return "Earth"
        }
    }

    var damageType: DamageType {
        switch self {
        case .fire: return .fire
        case .waterIce: return .frost
        case .wind: return .shock
        case .earth: return .physical
        }
    }
}

struct Ability: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var actionType: ActionType
    var requiredLevel: Int
    var damageType: DamageType?
    var conditionApplied: ConditionType?
    var cost: String?
    var useLimit: String?
    var tags: [String]
    var techniqueType: TechniqueType?
    var source: AbilitySource
    var cooldown: Int?
    var targetType: AbilityTargetType?
    var targetPattern: AbilityTargetPattern?
    var durationTurns: Int?
    var combatLogText: String?
    var resourceType: AbilityResourceType
    var combatType: AbilityCombatType

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case summary
        case actionType
        case requiredLevel
        case damageType
        case conditionApplied
        case cost
        case useLimit
        case tags
        case techniqueType
        case source
        case cooldown
        case targetType
        case targetPattern
        case durationTurns
        case combatLogText
        case resourceType
        case combatType
    }

    init(
        id: String,
        name: String,
        summary: String,
        actionType: ActionType,
        requiredLevel: Int,
        damageType: DamageType? = nil,
        conditionApplied: ConditionType? = nil,
        cost: String? = nil,
        useLimit: String? = nil,
        tags: [String] = [],
        techniqueType: TechniqueType? = nil,
        source: AbilitySource = .path,
        cooldown: Int? = nil,
        targetType: AbilityTargetType? = nil,
        targetPattern: AbilityTargetPattern? = nil,
        durationTurns: Int? = nil,
        combatLogText: String? = nil,
        resourceType: AbilityResourceType = .none,
        combatType: AbilityCombatType = .utility
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.actionType = actionType
        self.requiredLevel = requiredLevel
        self.damageType = damageType
        self.conditionApplied = conditionApplied
        self.cost = cost
        self.useLimit = useLimit
        self.tags = tags
        self.techniqueType = techniqueType
        self.source = source
        self.cooldown = cooldown
        self.targetType = targetType
        self.targetPattern = targetPattern
        self.durationTurns = durationTurns
        self.combatLogText = combatLogText
        self.resourceType = resourceType
        self.combatType = combatType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        actionType = try container.decode(ActionType.self, forKey: .actionType)
        requiredLevel = try container.decode(Int.self, forKey: .requiredLevel)
        damageType = try container.decodeIfPresent(DamageType.self, forKey: .damageType)
        conditionApplied = try container.decodeIfPresent(ConditionType.self, forKey: .conditionApplied)
        cost = try container.decodeIfPresent(String.self, forKey: .cost)
        useLimit = try container.decodeIfPresent(String.self, forKey: .useLimit)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        techniqueType = try container.decodeIfPresent(TechniqueType.self, forKey: .techniqueType)
        source = try container.decodeIfPresent(AbilitySource.self, forKey: .source) ?? .path
        cooldown = try container.decodeIfPresent(Int.self, forKey: .cooldown)
        targetType = try container.decodeIfPresent(AbilityTargetType.self, forKey: .targetType)
        targetPattern = try container.decodeIfPresent(AbilityTargetPattern.self, forKey: .targetPattern)
        durationTurns = try container.decodeIfPresent(Int.self, forKey: .durationTurns)
        combatLogText = try container.decodeIfPresent(String.self, forKey: .combatLogText)
        resourceType = try container.decodeIfPresent(AbilityResourceType.self, forKey: .resourceType)
            ?? (cost?.localizedCaseInsensitiveContains("Focus") == true ? .focus
                : cost?.localizedCaseInsensitiveContains("Stamina") == true ? .stamina : .none)
        combatType = try container.decodeIfPresent(AbilityCombatType.self, forKey: .combatType) ?? .utility
    }
}

enum Portrait: String, CaseIterable, Codable, Hashable, Identifiable {
    case bladeguardBaseMale = "Bladeguard Base Male"
    case bladeguardBaseFemale = "Bladeguard Base Female"
    case shadowstepBaseMale = "Shadowstep Base Male"
    case shadowstepBaseFemale = "Shadowstep Base Female"
    case wildwardenBaseMale = "Wildwarden Base Male"
    case wildwardenBaseFemale = "Wildwarden Base Female"
    case embermageBaseMale = "Embermage Base Male"
    case embermageBaseFemale = "Embermage Base Female"
    case oathkeeperBaseMale = "Oathkeeper Base Male"
    case oathkeeperBaseFemale = "Oathkeeper Base Female"
    case ironVanguardMale = "Iron Vanguard Male"
    case ironVanguardFemale = "Iron Vanguard Female"
    case stormDuelistMale = "Storm Duelist Male"
    case stormDuelistFemale = "Storm Duelist Female"
    case nightbladeMale = "Nightblade Male"
    case nightbladeFemale = "Nightblade Female"
    case trickhandMale = "Trickhand Male"
    case trickhandFemale = "Trickhand Female"
    case beastcallerMale = "Beastcaller Male"
    case beastcallerFemale = "Beastcaller Female"
    case deepwoodArcherMale = "Deepwood Archer Male"
    case deepwoodArcherFemale = "Deepwood Archer Female"
    case flamecallerMale = "Flamecaller Male"
    case flamecallerFemale = "Flamecaller Female"
    case starweaverMale = "Starweaver Male"
    case starweaverFemale = "Starweaver Female"
    case dawnshieldMale = "Dawnshield Male"
    case dawnshieldFemale = "Dawnshield Female"
    case judgementFlameMale = "Judgement Flame Male"
    case judgementFlameFemale = "Judgement Flame Female"

    var id: String { rawValue }

    var initials: String {
        rawValue.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }
}

typealias PortraitOption = Portrait

struct ArtAsset: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var assetName: String
    var placeholderColorHex: String?
}

struct Attributes: Codable, Equatable, Hashable {
    var might: Int
    var agility: Int
    var endurance: Int
    var mind: Int
    var instinct: Int
    var presence: Int

    init(
        might: Int = 8,
        agility: Int = 8,
        endurance: Int = 8,
        mind: Int = 8,
        instinct: Int = 8,
        presence: Int = 8
    ) {
        self.might = might
        self.agility = agility
        self.endurance = endurance
        self.mind = mind
        self.instinct = instinct
        self.presence = presence
    }

    var total: Int {
        might + agility + endurance + mind + instinct + presence
    }

    func score(for type: AttributeType) -> Int {
        switch type {
        case .might:
            return might
        case .agility:
            return agility
        case .endurance:
            return endurance
        case .mind:
            return mind
        case .instinct:
            return instinct
        case .presence:
            return presence
        }
    }

    func modifier(for type: AttributeType) -> Int {
        Self.modifier(forScore: score(for: type))
    }

    static func modifier(forScore score: Int) -> Int {
        Int(floor(Double(score - 10) / 2.0))
    }
}

typealias AttributeSet = Attributes

struct Item: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var category: ItemCategory
    var rarity: Rarity
    var value: Int
    var stackLimit: Int
}

struct Weapon: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var damageType: DamageType
    var baseDamageDice: String
    var handsRequired: Int
}

struct Armour: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var equipmentSlot: EquipmentSlot
    var armourBonus: Int
}

struct Charm: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var effectSummary: String
}

struct Consumable: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var useSummary: String
    var charges: Int
}

struct Material: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var sourceSummary: String
}

struct MiscItem: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
}

struct QuestItem: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var item: Item
    var questID: String
}

struct Inventory: Codable, Equatable, Hashable {
    var itemQuantities: [String: Int]
    var gold: Int

    init(itemQuantities: [String: Int] = [:], gold: Int = 0) {
        self.itemQuantities = itemQuantities
        self.gold = gold
    }
}

struct EquippedItems: Codable, Equatable, Hashable {
    var slots: [EquipmentSlot: String]

    init(slots: [EquipmentSlot: String] = [:]) {
        self.slots = slots
    }
}

struct Condition: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var type: ConditionType
    var remainingTurns: Int?
    var strength: Int

    init(id: UUID = UUID(), type: ConditionType, remainingTurns: Int? = nil, strength: Int = 1) {
        self.id = id
        self.type = type
        self.remainingTurns = remainingTurns
        self.strength = strength
    }
}

extension ConditionType {
    var displayName: String {
        switch self {
        case .bleeding: return "Bleeding"
        case .burning: return "Burning"
        case .poisoned: return "Poisoned"
        case .slowed: return "Slowed"
        case .stunned: return "Stunned"
        case .guarded: return "Guarded"
        case .marked: return "Marked"
        case .weakened: return "Weakened"
        case .exposed: return "Exposed"
        case .knockedDown: return "Knocked Down"
        }
    }

    var effectDescription: String {
        switch self {
        case .bleeding:
            return "Takes physical damage at the start of its turn."
        case .burning:
            return "Takes fire damage at the start of its turn."
        case .poisoned:
            return "Attacks or checks may be hindered while poisoned."
        case .slowed:
            return "Movement and timing are hindered. May reduce initiative, agility-based effects or the next action depending on the ability."
        case .stunned:
            return "Loses its next action."
        case .guarded:
            return "Defence is increased while guarded."
        case .marked:
            return "Target is marked for follow-up abilities and effects."
        case .weakened:
            return "Next attack or damage is reduced, depending on the effect."
        case .exposed:
            return "Defence reduced by 1 until the condition expires."
        case .knockedDown:
            return "Defence and Agility are reduced until recovered."
        }
    }
}

struct EnemyAbility: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var summary: String
    var actionType: ActionType
    var damageType: DamageType?
}

struct Enemy: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var tier: EnemyTier
    var family: String
    var level: Int
    var maxHealth: Int
    var defence: Int
    var initiativeBonus: Int
    var attackBonus: Int
    var damageExpression: String
    var damageType: DamageType
    var resistances: [DamageType: Int]
    var weaknesses: [DamageType: Int]
    var abilities: [EnemyAbility]
    var immunities: [ConditionType]
    var xp: Int
    var goldRange: ClosedRange<Int>
    var summary: String
}

struct SkillCheck: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var skill: SkillType
    var targetNumber: Int
    var successText: String
    var failureText: String
}

struct Trap: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var detectionCheck: SkillCheck?
    var disarmCheck: SkillCheck?
    var damageType: DamageType?
    var damageDice: String?
}

struct Choice: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var text: String
    var nextRoomID: String?
    var skillCheck: SkillCheck?
    var rewardID: String?
}

struct Room: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var title: String
    var narrative: String
    var choices: [Choice]
    var enemyIDs: [String]
    var trap: Trap?
    var lootTableID: String?
}

struct Adventure: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var title: String
    var summary: String
    var recommendedLevel: Int
    var startRoomID: String
    var rooms: [Room]
}

struct LootTable: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var name: String
    var entries: [LootEntry]
}

struct LootEntry: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var itemID: String
    var weight: Int
    var quantityRange: ClosedRange<Int>
}

struct Reward: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var xp: Int
    var gold: Int
    var itemIDs: [String]
}

struct ShopEvent: Codable, Equatable, Hashable, Identifiable {
    enum EventType: String, Codable, Hashable {
        case sale
        case merchantDemand
    }

    var id: String
    var name: String
    var summary: String
    var type: EventType
    var discountPercent: Int?
    var sellPercentOverride: Int?

    static let sale25 = ShopEvent(
        id: "sale-25",
        name: "Sale: 25% Off",
        summary: "Greywick merchants are discounting all shop stock by 25%.",
        type: .sale,
        discountPercent: 25,
        sellPercentOverride: nil
    )

    static let sale35 = ShopEvent(
        id: "sale-35",
        name: "Sale: 35% Off",
        summary: "Greywick merchants are discounting all shop stock by 35%.",
        type: .sale,
        discountPercent: 35,
        sellPercentOverride: nil
    )

    static let sale50 = ShopEvent(
        id: "sale-50",
        name: "Sale: 50% Off",
        summary: "Greywick merchants are discounting all shop stock by 50%.",
        type: .sale,
        discountPercent: 50,
        sellPercentOverride: nil
    )

    static let merchantDemand = ShopEvent(
        id: "merchant-demand",
        name: "Merchant Demand",
        summary: "Merchants are paying 80% value for gear.",
        type: .merchantDemand,
        discountPercent: nil,
        sellPercentOverride: GameConstants.merchantDemandSellPercent
    )
}

struct ShopState: Codable, Equatable, Hashable {
    var shopID: String
    var stockItemIDs: [String]
    var manualRestocksUsed: Int
    var activeEvent: ShopEvent?

    static let greywickDefault = ShopState(
        shopID: "greywick-general-store",
        stockItemIDs: [],
        manualRestocksUsed: 0,
        activeEvent: nil
    )
}

struct CurrentAdventureState: Codable, Equatable, Hashable {
    var adventureID: String?
    var currentRoomID: String?
    var currentRoomIndex: Int
    var visitedRoomIDs: Set<String>
    var completedRoomIDs: Set<String>
    var completedAdventureIDs: Set<String>
    var collectedRewardIDs: Set<String>
    var defeatedEnemyIDs: Set<String>
    var activeConditions: [Condition]
    var temporaryBonuses: [String: Int]
    var adventureLog: [String]
    var currentCombatState: CombatState?
    var shortRestUsed: Bool
    var staminaDraughtUses: Int
    var elementalFlaskUses: Int
    var startedAt: Date?
    var lastSavedAt: Date?

    var isActive: Bool {
        adventureID != nil
    }

    init(
        adventureID: String? = nil,
        currentRoomID: String? = nil,
        currentRoomIndex: Int = 0,
        visitedRoomIDs: Set<String> = [],
        completedRoomIDs: Set<String> = [],
        completedAdventureIDs: Set<String> = [],
        collectedRewardIDs: Set<String> = [],
        defeatedEnemyIDs: Set<String> = [],
        activeConditions: [Condition] = [],
        temporaryBonuses: [String: Int] = [:],
        adventureLog: [String] = [],
        currentCombatState: CombatState? = nil,
        shortRestUsed: Bool = false,
        staminaDraughtUses: Int = 0,
        elementalFlaskUses: Int = 0,
        startedAt: Date? = nil,
        lastSavedAt: Date? = nil
    ) {
        self.adventureID = adventureID
        self.currentRoomID = currentRoomID
        self.currentRoomIndex = currentRoomIndex
        self.visitedRoomIDs = visitedRoomIDs
        self.completedRoomIDs = completedRoomIDs
        self.completedAdventureIDs = completedAdventureIDs
        self.collectedRewardIDs = collectedRewardIDs
        self.defeatedEnemyIDs = defeatedEnemyIDs
        self.activeConditions = activeConditions
        self.temporaryBonuses = temporaryBonuses
        self.adventureLog = adventureLog
        self.currentCombatState = currentCombatState
        self.shortRestUsed = shortRestUsed
        self.staminaDraughtUses = staminaDraughtUses
        self.elementalFlaskUses = elementalFlaskUses
        self.startedAt = startedAt
        self.lastSavedAt = lastSavedAt
    }

    private enum CodingKeys: String, CodingKey {
        case adventureID
        case currentRoomID
        case currentRoomIndex
        case visitedRoomIDs
        case completedRoomIDs
        case completedAdventureIDs
        case collectedRewardIDs
        case defeatedEnemyIDs
        case activeConditions
        case temporaryBonuses
        case adventureLog
        case currentCombatState
        case shortRestUsed
        case staminaDraughtUses
        case elementalFlaskUses
        case startedAt
        case lastSavedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        adventureID = try container.decodeIfPresent(String.self, forKey: .adventureID)
        currentRoomID = try container.decodeIfPresent(String.self, forKey: .currentRoomID)
        currentRoomIndex = try container.decodeIfPresent(Int.self, forKey: .currentRoomIndex) ?? 0
        visitedRoomIDs = try container.decodeIfPresent(Set<String>.self, forKey: .visitedRoomIDs) ?? []
        completedRoomIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedRoomIDs) ?? []
        completedAdventureIDs = try container.decodeIfPresent(Set<String>.self, forKey: .completedAdventureIDs) ?? []
        collectedRewardIDs = try container.decodeIfPresent(Set<String>.self, forKey: .collectedRewardIDs) ?? []
        defeatedEnemyIDs = try container.decodeIfPresent(Set<String>.self, forKey: .defeatedEnemyIDs) ?? []
        activeConditions = try container.decodeIfPresent([Condition].self, forKey: .activeConditions) ?? []
        temporaryBonuses = try container.decodeIfPresent([String: Int].self, forKey: .temporaryBonuses) ?? [:]
        adventureLog = try container.decodeIfPresent([String].self, forKey: .adventureLog) ?? []
        currentCombatState = try container.decodeIfPresent(CombatState.self, forKey: .currentCombatState)
        shortRestUsed = try container.decodeIfPresent(Bool.self, forKey: .shortRestUsed) ?? false
        staminaDraughtUses = try container.decodeIfPresent(Int.self, forKey: .staminaDraughtUses) ?? 0
        elementalFlaskUses = try container.decodeIfPresent(Int.self, forKey: .elementalFlaskUses) ?? 0
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        lastSavedAt = try container.decodeIfPresent(Date.self, forKey: .lastSavedAt)
    }
}

enum CombatPhase: String, Codable, Hashable {
    case heroTurn
    case enemyTurn
    case victory
    case defeated
    case escaped
}

struct CombatEnemyState: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var enemyID: String
    var currentHealth: Int
    var conditions: [Condition]
    var hasUsedSpecial: Bool
    var firstAttackPending: Bool
    var nextAttackPenalty: Int
    var cinderMarkPending: Bool
    var cinderMarkRemainingTurns: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case enemyID
        case currentHealth
        case conditions
        case hasUsedSpecial
        case firstAttackPending
        case nextAttackPenalty
        case cinderMarkPending
        case cinderMarkRemainingTurns
    }

    init(
        id: UUID = UUID(),
        enemyID: String,
        currentHealth: Int,
        conditions: [Condition] = [],
        hasUsedSpecial: Bool = false,
        firstAttackPending: Bool = true,
        nextAttackPenalty: Int = 0,
        cinderMarkPending: Bool = false,
        cinderMarkRemainingTurns: Int = 0
    ) {
        self.id = id
        self.enemyID = enemyID
        self.currentHealth = currentHealth
        self.conditions = conditions
        self.hasUsedSpecial = hasUsedSpecial
        self.firstAttackPending = firstAttackPending
        self.nextAttackPenalty = nextAttackPenalty
        self.cinderMarkPending = cinderMarkPending
        self.cinderMarkRemainingTurns = cinderMarkRemainingTurns
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        enemyID = try container.decode(String.self, forKey: .enemyID)
        currentHealth = try container.decode(Int.self, forKey: .currentHealth)
        conditions = try container.decodeIfPresent([Condition].self, forKey: .conditions) ?? []
        hasUsedSpecial = try container.decodeIfPresent(Bool.self, forKey: .hasUsedSpecial) ?? false
        firstAttackPending = try container.decodeIfPresent(Bool.self, forKey: .firstAttackPending) ?? true
        nextAttackPenalty = try container.decodeIfPresent(Int.self, forKey: .nextAttackPenalty) ?? 0
        cinderMarkPending = try container.decodeIfPresent(Bool.self, forKey: .cinderMarkPending) ?? false
        cinderMarkRemainingTurns = try container.decodeIfPresent(Int.self, forKey: .cinderMarkRemainingTurns)
            ?? (cinderMarkPending ? 2 : 0)
    }
}

struct CombatState: Codable, Equatable, Hashable {
    var encounterID: String
    var enemyIDs: [String]
    var enemies: [CombatEnemyState]
    var roundNumber: Int
    var heroInitiative: Int
    var enemyInitiatives: [UUID: Int]
    var activeConditions: [Condition]
    var hasUsedQuickAction: Bool
    var hasUsedMajorAction: Bool
    var hasUsedConsumable: Bool
    var usedAbilityIDs: Set<String>
    var abilityCooldowns: [String: Int]
    var pendingAttackBonus: Int
    var pendingDamageBonus: Int
    var temporaryDefenceBonus: Int
    var quickDefenceBonus: Int
    var pendingDamageReductionDie: Int
    var nextPhysicalDamageReduction: Int
    var pendingFireOilBonus: Bool
    var pendingElementalFlask: ElementalFlaskElement?
    var pendingKindledFireSpell: Bool
    var phase: CombatPhase
    var combatLog: [String]
    var isActive: Bool

    private enum CodingKeys: String, CodingKey {
        case encounterID
        case enemyIDs
        case enemies
        case roundNumber
        case heroInitiative
        case enemyInitiatives
        case activeConditions
        case hasUsedQuickAction
        case hasUsedMajorAction
        case hasUsedConsumable
        case usedAbilityIDs
        case abilityCooldowns
        case pendingAttackBonus
        case pendingDamageBonus
        case temporaryDefenceBonus
        case quickDefenceBonus
        case pendingDamageReductionDie
        case nextPhysicalDamageReduction
        case pendingFireOilBonus
        case pendingElementalFlask
        case pendingKindledFireSpell
        case phase
        case combatLog
        case isActive
    }

    init(
        encounterID: String = "test-combat",
        enemyIDs: [String] = [],
        enemies: [CombatEnemyState] = [],
        roundNumber: Int = 1,
        heroInitiative: Int = 0,
        enemyInitiatives: [UUID: Int] = [:],
        activeConditions: [Condition] = [],
        hasUsedQuickAction: Bool = false,
        hasUsedMajorAction: Bool = false,
        hasUsedConsumable: Bool = false,
        usedAbilityIDs: Set<String> = [],
        abilityCooldowns: [String: Int] = [:],
        pendingAttackBonus: Int = 0,
        pendingDamageBonus: Int = 0,
        temporaryDefenceBonus: Int = 0,
        quickDefenceBonus: Int = 0,
        pendingDamageReductionDie: Int = 0,
        nextPhysicalDamageReduction: Int = 0,
        pendingFireOilBonus: Bool = false,
        pendingElementalFlask: ElementalFlaskElement? = nil,
        pendingKindledFireSpell: Bool = false,
        phase: CombatPhase = .heroTurn,
        combatLog: [String] = [],
        isActive: Bool = false
    ) {
        self.encounterID = encounterID
        self.enemyIDs = enemyIDs
        self.enemies = enemies
        self.roundNumber = roundNumber
        self.heroInitiative = heroInitiative
        self.enemyInitiatives = enemyInitiatives
        self.activeConditions = activeConditions
        self.hasUsedQuickAction = hasUsedQuickAction
        self.hasUsedMajorAction = hasUsedMajorAction
        self.hasUsedConsumable = hasUsedConsumable
        self.usedAbilityIDs = usedAbilityIDs
        self.abilityCooldowns = abilityCooldowns
        self.pendingAttackBonus = pendingAttackBonus
        self.pendingDamageBonus = pendingDamageBonus
        self.temporaryDefenceBonus = temporaryDefenceBonus
        self.quickDefenceBonus = quickDefenceBonus
        self.pendingDamageReductionDie = pendingDamageReductionDie
        self.nextPhysicalDamageReduction = nextPhysicalDamageReduction
        self.pendingFireOilBonus = pendingFireOilBonus
        self.pendingElementalFlask = pendingElementalFlask
        self.pendingKindledFireSpell = pendingKindledFireSpell
        self.phase = phase
        self.combatLog = combatLog
        self.isActive = isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        encounterID = try container.decodeIfPresent(String.self, forKey: .encounterID) ?? "test-combat"
        enemyIDs = try container.decodeIfPresent([String].self, forKey: .enemyIDs) ?? []
        enemies = try container.decodeIfPresent([CombatEnemyState].self, forKey: .enemies) ?? []
        roundNumber = try container.decodeIfPresent(Int.self, forKey: .roundNumber) ?? 1
        heroInitiative = try container.decodeIfPresent(Int.self, forKey: .heroInitiative) ?? 0
        enemyInitiatives = try container.decodeIfPresent([UUID: Int].self, forKey: .enemyInitiatives) ?? [:]
        activeConditions = try container.decodeIfPresent([Condition].self, forKey: .activeConditions) ?? []
        hasUsedQuickAction = try container.decodeIfPresent(Bool.self, forKey: .hasUsedQuickAction) ?? false
        hasUsedMajorAction = try container.decodeIfPresent(Bool.self, forKey: .hasUsedMajorAction) ?? false
        hasUsedConsumable = try container.decodeIfPresent(Bool.self, forKey: .hasUsedConsumable) ?? false
        usedAbilityIDs = try container.decodeIfPresent(Set<String>.self, forKey: .usedAbilityIDs) ?? []
        abilityCooldowns = try container.decodeIfPresent([String: Int].self, forKey: .abilityCooldowns) ?? [:]
        pendingAttackBonus = try container.decodeIfPresent(Int.self, forKey: .pendingAttackBonus) ?? 0
        pendingDamageBonus = try container.decodeIfPresent(Int.self, forKey: .pendingDamageBonus) ?? 0
        temporaryDefenceBonus = try container.decodeIfPresent(Int.self, forKey: .temporaryDefenceBonus) ?? 0
        quickDefenceBonus = try container.decodeIfPresent(Int.self, forKey: .quickDefenceBonus) ?? 0
        pendingDamageReductionDie = try container.decodeIfPresent(Int.self, forKey: .pendingDamageReductionDie) ?? 0
        nextPhysicalDamageReduction = try container.decodeIfPresent(Int.self, forKey: .nextPhysicalDamageReduction) ?? 0
        pendingFireOilBonus = try container.decodeIfPresent(Bool.self, forKey: .pendingFireOilBonus) ?? false
        pendingElementalFlask = try container.decodeIfPresent(ElementalFlaskElement.self, forKey: .pendingElementalFlask)
        pendingKindledFireSpell = try container.decodeIfPresent(Bool.self, forKey: .pendingKindledFireSpell) ?? false
        phase = try container.decodeIfPresent(CombatPhase.self, forKey: .phase) ?? .heroTurn
        combatLog = try container.decodeIfPresent([String].self, forKey: .combatLog) ?? []
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
    }
}

struct ProgressionRules: Codable, Equatable, Hashable {
    var xpByLevel: [Int: Int]
    var trainingBonusByLevel: [Int: Int]
    var attributeIncreaseLevels: [Int]
    var attributeCap: Int

    static let versionOne = ProgressionRules(
        xpByLevel: [
            1: 0,
            2: 300,
            3: 900,
            4: 2400,
            5: 5500
        ],
        trainingBonusByLevel: [
            1: 2,
            2: 2,
            3: 3,
            4: 3,
            5: 4
        ],
        attributeIncreaseLevels: [2, 4, 5],
        attributeCap: GameConstants.versionOneAttributeCap
    )

    func xpRequired(for level: Int) -> Int? {
        xpByLevel[level]
    }

    func trainingBonus(for level: Int) -> Int? {
        trainingBonusByLevel[level]
    }
}

enum QuestboundTextSize: String, CaseIterable, Codable, Hashable, Identifiable {
    case small
    case standard
    case large

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Standard"
        case .large: return "Large"
        }
    }
}

struct Settings: Codable, Equatable, Hashable {
    var textSpeed: Double
    var reduceMotion: Bool
    var hapticsEnabled: Bool
    var soundEnabled: Bool
    var musicEnabled: Bool
    var textSize: QuestboundTextSize
    var confirmRareEpicSales: Bool
    var skipNormalSellConfirmation: Bool
    var dismissedTutorialTips: Set<String>
    var developerModeEnabled: Bool

    static let defaults = Settings(
        textSpeed: 1.0,
        reduceMotion: false,
        hapticsEnabled: true,
        soundEnabled: true,
        musicEnabled: true,
        textSize: .standard,
        confirmRareEpicSales: true,
        skipNormalSellConfirmation: false,
        dismissedTutorialTips: [],
        developerModeEnabled: false
    )

    private enum CodingKeys: String, CodingKey {
        case textSpeed
        case reduceMotion
        case hapticsEnabled
        case soundEnabled
        case musicEnabled
        case textSize
        case confirmRareEpicSales
        case skipNormalSellConfirmation
        case dismissedTutorialTips
        case developerModeEnabled
    }

    init(
        textSpeed: Double,
        reduceMotion: Bool,
        hapticsEnabled: Bool,
        soundEnabled: Bool,
        musicEnabled: Bool,
        textSize: QuestboundTextSize,
        confirmRareEpicSales: Bool,
        skipNormalSellConfirmation: Bool,
        dismissedTutorialTips: Set<String>,
        developerModeEnabled: Bool = false
    ) {
        self.textSpeed = textSpeed
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
        self.soundEnabled = soundEnabled
        self.musicEnabled = musicEnabled
        self.textSize = textSize
        self.confirmRareEpicSales = confirmRareEpicSales
        self.skipNormalSellConfirmation = skipNormalSellConfirmation
        self.dismissedTutorialTips = dismissedTutorialTips
        self.developerModeEnabled = developerModeEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings.defaults
        textSpeed = try container.decodeIfPresent(Double.self, forKey: .textSpeed) ?? defaults.textSpeed
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? defaults.reduceMotion
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        musicEnabled = try container.decodeIfPresent(Bool.self, forKey: .musicEnabled) ?? defaults.musicEnabled
        textSize = try container.decodeIfPresent(QuestboundTextSize.self, forKey: .textSize) ?? defaults.textSize
        confirmRareEpicSales = try container.decodeIfPresent(Bool.self, forKey: .confirmRareEpicSales) ?? defaults.confirmRareEpicSales
        skipNormalSellConfirmation = try container.decodeIfPresent(Bool.self, forKey: .skipNormalSellConfirmation) ?? defaults.skipNormalSellConfirmation
        dismissedTutorialTips = try container.decodeIfPresent(Set<String>.self, forKey: .dismissedTutorialTips) ?? defaults.dismissedTutorialTips
        developerModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .developerModeEnabled) ?? defaults.developerModeEnabled
    }
}

struct Hero: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var origin: Origin
    var originFeature: OriginFeature?
    var path: Path
    var subpath: String?
    var selectedSubpath: Subpath?
    var portrait: Portrait
    var attributes: Attributes
    var trainedSkills: [SkillType]
    var abilities: [Ability]
    var inventory: Inventory
    var equippedItems: EquippedItems
    var level: Int
    var xp: Int
    var maxHealth: Int
    var currentHealth: Int
    var focus: Int
    var maxFocus: Int
    var currentFocus: Int
    var maxStamina: Int
    var currentStamina: Int
    var gold: Int
    var currentLocation: String
    var currentAdventureState: CurrentAdventureState
    var combatState: CombatState?
    var lastPlayedAt: Date
    var createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case origin
        case originFeature
        case path
        case subpath
        case selectedSubpath
        case portrait
        case attributes
        case trainedSkills
        case abilities
        case inventory
        case equippedItems
        case level
        case xp
        case maxHealth
        case currentHealth
        case focus
        case maxFocus
        case currentFocus
        case maxStamina
        case currentStamina
        case gold
        case currentLocation
        case currentAdventureState
        case combatState
        case lastPlayedAt
        case createdAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        origin: Origin,
        originFeature: OriginFeature? = nil,
        path: Path,
        subpath: String? = nil,
        selectedSubpath: Subpath? = nil,
        portrait: Portrait,
        attributes: Attributes,
        trainedSkills: [SkillType] = [],
        abilities: [Ability] = [],
        inventory: Inventory = Inventory(gold: 25),
        equippedItems: EquippedItems = EquippedItems(),
        level: Int = 1,
        xp: Int = 0,
        maxHealth: Int = 1,
        currentHealth: Int? = nil,
        focus: Int = 0,
        maxFocus: Int? = nil,
        currentFocus: Int? = nil,
        maxStamina: Int? = nil,
        currentStamina: Int? = nil,
        gold: Int = 25,
        currentLocation: String = "Greywick",
        currentAdventureState: CurrentAdventureState = CurrentAdventureState(),
        combatState: CombatState? = nil,
        lastPlayedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.origin = origin
        self.originFeature = originFeature
        self.path = path
        self.subpath = subpath
        self.selectedSubpath = selectedSubpath
        self.portrait = portrait
        self.attributes = attributes
        self.trainedSkills = trainedSkills
        self.abilities = abilities
        self.inventory = inventory
        self.equippedItems = equippedItems
        self.level = min(level, GameConstants.versionOneLevelCap)
        self.xp = xp
        self.maxHealth = maxHealth
        self.currentHealth = currentHealth ?? maxHealth
        self.focus = focus
        self.maxFocus = maxFocus ?? focus
        self.currentFocus = currentFocus ?? (maxFocus ?? focus)
        let staminaMaximum = maxStamina ?? Hero.staminaMaximum(path: path, level: level)
        self.maxStamina = staminaMaximum
        self.currentStamina = currentStamina ?? staminaMaximum
        self.gold = gold
        self.currentLocation = currentLocation
        self.currentAdventureState = currentAdventureState
        self.combatState = combatState
        self.lastPlayedAt = lastPlayedAt
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        origin = try container.decode(Origin.self, forKey: .origin)
        originFeature = try container.decodeIfPresent(OriginFeature.self, forKey: .originFeature)
        path = try container.decode(Path.self, forKey: .path)
        subpath = try container.decodeIfPresent(String.self, forKey: .subpath)
        selectedSubpath = try container.decodeIfPresent(Subpath.self, forKey: .selectedSubpath)
        portrait = try container.decode(Portrait.self, forKey: .portrait)
        attributes = try container.decode(Attributes.self, forKey: .attributes)
        trainedSkills = try container.decodeIfPresent([SkillType].self, forKey: .trainedSkills) ?? []
        abilities = try container.decodeIfPresent([Ability].self, forKey: .abilities) ?? []
        inventory = try container.decodeIfPresent(Inventory.self, forKey: .inventory) ?? Inventory(gold: 25)
        equippedItems = try container.decodeIfPresent(EquippedItems.self, forKey: .equippedItems) ?? EquippedItems()
        level = min(try container.decodeIfPresent(Int.self, forKey: .level) ?? 1, GameConstants.versionOneLevelCap)
        xp = try container.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        maxHealth = try container.decodeIfPresent(Int.self, forKey: .maxHealth) ?? 1
        currentHealth = try container.decodeIfPresent(Int.self, forKey: .currentHealth) ?? maxHealth
        focus = try container.decodeIfPresent(Int.self, forKey: .focus) ?? 0
        maxFocus = try container.decodeIfPresent(Int.self, forKey: .maxFocus) ?? focus
        currentFocus = try container.decodeIfPresent(Int.self, forKey: .currentFocus) ?? maxFocus
        maxStamina = try container.decodeIfPresent(Int.self, forKey: .maxStamina)
            ?? Hero.staminaMaximum(path: path, level: level)
        currentStamina = try container.decodeIfPresent(Int.self, forKey: .currentStamina) ?? maxStamina
        gold = try container.decodeIfPresent(Int.self, forKey: .gold) ?? inventory.gold
        currentLocation = try container.decodeIfPresent(String.self, forKey: .currentLocation) ?? "Greywick"
        currentAdventureState = try container.decodeIfPresent(CurrentAdventureState.self, forKey: .currentAdventureState) ?? CurrentAdventureState()
        combatState = try container.decodeIfPresent(CombatState.self, forKey: .combatState)
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt) ?? Date()
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    static func staminaMaximum(path: Path, level: Int) -> Int {
        guard path == .bladeguard || path == .shadowstep || path == .wildwarden else { return 0 }
        if level >= 5 { return 4 }
        if level >= 3 { return 3 }
        return 2
    }
}

typealias HeroProfile = Hero

struct HeroSlot: Codable, Equatable, Hashable, Identifiable {
    let id: Int
    var hero: Hero?

    var title: String {
        hero?.name ?? "Empty Slot"
    }
}

typealias SaveSlot = HeroSlot

struct QuestboundSaveFile: Codable, Equatable {
    var saveVersion: Int
    var gameVersion: String
    var slots: [HeroSlot]
    var settings: Settings
    var shopState: ShopState

    private enum CodingKeys: String, CodingKey {
        case saveVersion
        case gameVersion
        case slots
        case settings
        case shopState
    }

    init(
        saveVersion: Int,
        gameVersion: String,
        slots: [HeroSlot],
        settings: Settings = .defaults,
        shopState: ShopState = .greywickDefault
    ) {
        self.saveVersion = saveVersion
        self.gameVersion = gameVersion
        self.slots = slots
        self.settings = settings
        self.shopState = shopState
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        saveVersion = try container.decode(Int.self, forKey: .saveVersion)
        gameVersion = try container.decode(String.self, forKey: .gameVersion)
        slots = try container.decode([HeroSlot].self, forKey: .slots)
        settings = try container.decodeIfPresent(Settings.self, forKey: .settings) ?? .defaults
        shopState = try container.decodeIfPresent(ShopState.self, forKey: .shopState) ?? .greywickDefault
    }
}
