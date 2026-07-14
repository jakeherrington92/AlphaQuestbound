import Foundation

struct OriginDefinition: Identifiable, Hashable {
    let origin: Origin
    let bonuses: [AttributeType: Int]
    let feature: OriginFeature
    let recommendedPaths: [Path]

    var id: Origin { origin }
}

struct PathDefinition: Identifiable {
    let path: Path
    let role: String
    let difficulty: String
    let primaryAttributes: [AttributeType]
    let secondaryAttributes: [AttributeType]
    let usefulAttributes: [AttributeType]
    let startingSkills: [SkillType]
    let startingHPBase: Int
    let hpPerLevelBase: Int
    let focusBase: Int?
    let focusAttribute: AttributeType?
    let startingAbilities: [Ability]
    let startingGear: [String]
    let equippedItems: [EquipmentSlot: String]
    let subpaths: [Subpath]
    let recommendedBuild: [AttributeType: Int]
    let weakBuildWarning: (Attributes) -> String?

    var id: Path { path }
}

struct PortraitDefinition: Identifiable, Hashable {
    let portrait: Portrait
    let path: Path
    let subpathID: String?
    let label: String
    let isBasePortrait: Bool

    var id: Portrait { portrait }
}

enum CharacterCreationData {
    static let origins: [OriginDefinition] = [
        OriginDefinition(
            origin: .hearthborn,
            bonuses: Dictionary(uniqueKeysWithValues: AttributeType.allCases.map { ($0, 1) }),
            feature: OriginFeature(
                id: "second-chance",
                name: "Second Chance",
                summary: "Once per adventure, reroll a failed skill check. The second result must be used.",
                skillBonuses: [:]
            ),
            recommendedPaths: Path.allCases
        ),
        OriginDefinition(
            origin: .moonElf,
            bonuses: [.agility: 2, .mind: 1],
            feature: OriginFeature(
                id: "night-sight",
                name: "Night Sight",
                summary: "Advantage on Awareness checks in darkness, caves, ruins or moonlit areas.",
                skillBonuses: [:]
            ),
            recommendedPaths: [.shadowstep, .wildwarden, .embermage]
        ),
        OriginDefinition(
            origin: .stonekin,
            bonuses: [.endurance: 2, .might: 1],
            feature: OriginFeature(
                id: "stonehide",
                name: "Stonehide",
                summary: "Once per combat, reduce incoming physical damage by 1.",
                skillBonuses: [:]
            ),
            recommendedPaths: [.bladeguard, .oathkeeper]
        ),
        OriginDefinition(
            origin: .ironblood,
            bonuses: [.might: 2, .endurance: 1],
            feature: OriginFeature(
                id: "heavy-hand",
                name: "Heavy Hand",
                summary: "Once per combat, after hitting with a melee attack, deal +1 physical damage.",
                skillBonuses: [:]
            ),
            recommendedPaths: [.bladeguard, .oathkeeper]
        ),
        OriginDefinition(
            origin: .smallfolk,
            bonuses: [.agility: 2, .presence: 1],
            feature: OriginFeature(
                id: "nimble-hands",
                name: "Nimble Hands",
                summary: "Once per room, gain +2 to a Stealth or Thievery check.",
                skillBonuses: [:]
            ),
            recommendedPaths: [.shadowstep, .wildwarden]
        ),
        OriginDefinition(
            origin: .starborn,
            bonuses: [.mind: 2, .instinct: 1],
            feature: OriginFeature(
                id: "arcane-memory",
                name: "Arcane Memory",
                summary: "Once per adventure, gain +2 to a Lore or Arcana check.",
                skillBonuses: [.lore: 2, .arcana: 2]
            ),
            recommendedPaths: [.embermage, .wildwarden]
        )
    ]

    static let paths: [PathDefinition] = [
        PathDefinition(
            path: .bladeguard,
            role: "Physical melee defender",
            difficulty: "Beginner",
            primaryAttributes: [.might],
            secondaryAttributes: [.endurance],
            usefulAttributes: [.presence, .agility],
            startingSkills: [.athletics, .intimidation],
            startingHPBase: 12,
            hpPerLevelBase: 7,
            focusBase: nil,
            focusAttribute: nil,
            startingAbilities: [
                ability("guarded-strike", "Guarded Strike", "A measured melee strike that reinforces your defence.", .major, .physical),
                ability("battle-ready", "Battle Ready", "A passive stance for holding the line.", .passive, nil)
            ],
            startingGear: ["Iron Sword", "Wooden Shield", "Chain Vest", "Minor Healing Draught", "Minor Healing Draught", "Adventurer's Pack"],
            equippedItems: [.mainWeapon: "Iron Sword", .offHand: "Wooden Shield", .chest: "Chain Vest"],
            subpaths: [
                subpath("iron-vanguard", "Iron Vanguard", .bladeguard, "Defensive shield specialist, armour, blocking and damage reduction."),
                subpath("storm-duelist", "Storm Duelist", .bladeguard, "Fast melee attacker, pressure, movement and stronger weapon strikes.")
            ],
            recommendedBuild: [.might: 16, .endurance: 15, .presence: 12, .agility: 11, .instinct: 10, .mind: 8],
            weakBuildWarning: { attributes in
                attributes.might < 14 || attributes.endurance < 12 ? "Bladeguard is weak if Might is below 14 or Endurance is below 12." : nil
            }
        ),
        PathDefinition(
            path: .shadowstep,
            role: "Rogue/precision damage",
            difficulty: "Intermediate",
            primaryAttributes: [.agility],
            secondaryAttributes: [.instinct],
            usefulAttributes: [.endurance, .presence],
            startingSkills: [.stealth, .thievery],
            startingHPBase: 9,
            hpPerLevelBase: 5,
            focusBase: nil,
            focusAttribute: nil,
            startingAbilities: [
                ability("opening-strike", "Opening Strike", "A precise first attack against an exposed foe.", .major, .physical),
                ability("slip-away", "Slip Away", "A quick reposition to escape pressure.", .quick, nil)
            ],
            startingGear: ["Twin Daggers", "Leather Vest", "Thief's Tools", "Minor Healing Draught", "Minor Healing Draught", "Adventurer's Pack"],
            equippedItems: [.mainWeapon: "Twin Daggers", .chest: "Leather Vest"],
            subpaths: [
                subpath("nightblade", "Nightblade", .shadowstep, "Stealth-focused burst damage and hard opening strikes."),
                subpath("trickhand", "Trickhand", .shadowstep, "Items, traps and debuffs to weaken enemies.")
            ],
            recommendedBuild: [.agility: 16, .instinct: 14, .endurance: 13, .presence: 11, .mind: 10, .might: 8],
            weakBuildWarning: { attributes in
                attributes.agility < 14 ? "Shadowstep is weak if Agility is below 14." : nil
            }
        ),
        PathDefinition(
            path: .wildwarden,
            role: "Ranged survivalist",
            difficulty: "Beginner/intermediate",
            primaryAttributes: [.agility],
            secondaryAttributes: [.instinct],
            usefulAttributes: [.endurance, .might],
            startingSkills: [.survival, .awareness],
            startingHPBase: 10,
            hpPerLevelBase: 6,
            focusBase: nil,
            focusAttribute: nil,
            startingAbilities: [
                ability("marked-shot", "Marked Shot", "A careful shot that singles out a dangerous target.", .major, .physical),
                ability("trail-sense", "Trail Sense", "A passive knack for reading tracks and terrain.", .passive, nil)
            ],
            startingGear: ["Shortbow", "Hunting Knife", "Leather Vest", "Minor Healing Draught", "Minor Healing Draught", "Adventurer's Pack"],
            equippedItems: [.mainWeapon: "Shortbow", .offHand: "Hunting Knife", .chest: "Leather Vest"],
            subpaths: [
                subpath("beastcaller", "Beastcaller", .wildwarden, "Mark/support focus with future pet synergy."),
                subpath("deepwood-archer", "Deepwood Archer", .wildwarden, "Bow damage, accuracy and critical hits.")
            ],
            recommendedBuild: [.agility: 16, .instinct: 15, .endurance: 12, .might: 11, .presence: 10, .mind: 8],
            weakBuildWarning: { attributes in
                attributes.agility < 13 || attributes.instinct < 12 ? "Wildwarden is weak if Agility is below 13 or Instinct is below 12." : nil
            }
        ),
        PathDefinition(
            path: .embermage,
            role: "Spellcaster",
            difficulty: "Intermediate",
            primaryAttributes: [.mind],
            secondaryAttributes: [.endurance],
            usefulAttributes: [.agility, .presence],
            startingSkills: [.arcana, .lore],
            startingHPBase: 7,
            hpPerLevelBase: 4,
            focusBase: 2,
            focusAttribute: .mind,
            startingAbilities: [
                ability("ember-bolt", "Ember Bolt", "A spark of fire shaped into a simple attack spell.", .major, .fire),
                ability("inner-spark", "Inner Spark", "A passive reserve of spellcasting focus.", .passive, .arcane)
            ],
            startingGear: ["Rune Staff", "Cloth Robe", "Focus Stone", "Minor Healing Draught", "Minor Healing Draught", "Adventurer's Pack"],
            equippedItems: [.mainWeapon: "Rune Staff", .chest: "Cloth Robe", .charm1: "Focus Stone"],
            subpaths: [
                subpath("flamecaller", "Flamecaller", .embermage, "Fire affinity focused on burst damage, Burning and clearing groups of enemies."),
                // The internal starweaver ID remains unchanged for save compatibility.
                subpath("starweaver", "Voidweaver", .embermage, "Void and arcane disruption, strange wards and hostile-magic control.")
            ],
            recommendedBuild: [.mind: 16, .endurance: 14, .presence: 13, .agility: 11, .instinct: 10, .might: 8],
            weakBuildWarning: { attributes in
                attributes.mind < 14 ? "Embermage is weak if Mind is below 14." : nil
            }
        ),
        PathDefinition(
            path: .oathkeeper,
            role: "Hybrid warrior/support",
            difficulty: "Intermediate",
            primaryAttributes: [.might, .presence],
            secondaryAttributes: [.endurance],
            usefulAttributes: [.mind, .instinct],
            startingSkills: [.endurance, .persuasion],
            startingHPBase: 11,
            hpPerLevelBase: 6,
            focusBase: 1,
            focusAttribute: .presence,
            startingAbilities: [
                ability("vowblade-strike", "Vowblade Strike", "A melee attack guided by conviction.", .major, .oathfire),
                ability("sacred-challenge", "Sacred Challenge", "A challenge that draws an enemy's attention.", .quick, nil)
            ],
            startingGear: ["Vowblade", "Wooden Shield", "Chain Vest", "Minor Healing Draught", "Minor Healing Draught", "Adventurer's Pack"],
            equippedItems: [.mainWeapon: "Vowblade", .offHand: "Wooden Shield", .chest: "Chain Vest"],
            subpaths: [
                subpath("dawnshield", "Dawnshield", .oathkeeper, "Healing, defence and survival."),
                subpath("judgement-flame", "Judgement Flame", .oathkeeper, "Oathfire damage, smiting and enemy weakening.")
            ],
            recommendedBuild: [.might: 15, .presence: 15, .endurance: 14, .mind: 10, .instinct: 10, .agility: 8],
            weakBuildWarning: { attributes in
                (attributes.might < 12 && attributes.presence < 12) || attributes.endurance < 11 ? "Oathkeeper is weak if both Might and Presence are below 12, or Endurance is below 11." : nil
            }
        )
    ]

    static let basePortraits: [PortraitDefinition] = [
        PortraitDefinition(portrait: .bladeguardBaseMale, path: .bladeguard, subpathID: nil, label: "Bladeguard Base Male", isBasePortrait: true),
        PortraitDefinition(portrait: .bladeguardBaseFemale, path: .bladeguard, subpathID: nil, label: "Bladeguard Base Female", isBasePortrait: true),
        PortraitDefinition(portrait: .shadowstepBaseMale, path: .shadowstep, subpathID: nil, label: "Shadowstep Base Male", isBasePortrait: true),
        PortraitDefinition(portrait: .shadowstepBaseFemale, path: .shadowstep, subpathID: nil, label: "Shadowstep Base Female", isBasePortrait: true),
        PortraitDefinition(portrait: .wildwardenBaseMale, path: .wildwarden, subpathID: nil, label: "Wildwarden Base Male", isBasePortrait: true),
        PortraitDefinition(portrait: .wildwardenBaseFemale, path: .wildwarden, subpathID: nil, label: "Wildwarden Base Female", isBasePortrait: true),
        PortraitDefinition(portrait: .embermageBaseMale, path: .embermage, subpathID: nil, label: "Embermage Base Male", isBasePortrait: true),
        PortraitDefinition(portrait: .embermageBaseFemale, path: .embermage, subpathID: nil, label: "Embermage Base Female", isBasePortrait: true),
        PortraitDefinition(portrait: .oathkeeperBaseMale, path: .oathkeeper, subpathID: nil, label: "Oathkeeper Base Male", isBasePortrait: true),
        PortraitDefinition(portrait: .oathkeeperBaseFemale, path: .oathkeeper, subpathID: nil, label: "Oathkeeper Base Female", isBasePortrait: true)
    ]

    static let subpathPortraits: [PortraitDefinition] = [
        PortraitDefinition(portrait: .ironVanguardMale, path: .bladeguard, subpathID: "iron-vanguard", label: "Iron Vanguard Male", isBasePortrait: false),
        PortraitDefinition(portrait: .ironVanguardFemale, path: .bladeguard, subpathID: "iron-vanguard", label: "Iron Vanguard Female", isBasePortrait: false),
        PortraitDefinition(portrait: .stormDuelistMale, path: .bladeguard, subpathID: "storm-duelist", label: "Storm Duelist Male", isBasePortrait: false),
        PortraitDefinition(portrait: .stormDuelistFemale, path: .bladeguard, subpathID: "storm-duelist", label: "Storm Duelist Female", isBasePortrait: false),
        PortraitDefinition(portrait: .nightbladeMale, path: .shadowstep, subpathID: "nightblade", label: "Nightblade Male", isBasePortrait: false),
        PortraitDefinition(portrait: .nightbladeFemale, path: .shadowstep, subpathID: "nightblade", label: "Nightblade Female", isBasePortrait: false),
        PortraitDefinition(portrait: .trickhandMale, path: .shadowstep, subpathID: "trickhand", label: "Trickhand Male", isBasePortrait: false),
        PortraitDefinition(portrait: .trickhandFemale, path: .shadowstep, subpathID: "trickhand", label: "Trickhand Female", isBasePortrait: false),
        PortraitDefinition(portrait: .beastcallerMale, path: .wildwarden, subpathID: "beastcaller", label: "Beastcaller Male", isBasePortrait: false),
        PortraitDefinition(portrait: .beastcallerFemale, path: .wildwarden, subpathID: "beastcaller", label: "Beastcaller Female", isBasePortrait: false),
        PortraitDefinition(portrait: .deepwoodArcherMale, path: .wildwarden, subpathID: "deepwood-archer", label: "Deepwood Archer Male", isBasePortrait: false),
        PortraitDefinition(portrait: .deepwoodArcherFemale, path: .wildwarden, subpathID: "deepwood-archer", label: "Deepwood Archer Female", isBasePortrait: false),
        PortraitDefinition(portrait: .flamecallerMale, path: .embermage, subpathID: "flamecaller", label: "Flamecaller Male", isBasePortrait: false),
        PortraitDefinition(portrait: .flamecallerFemale, path: .embermage, subpathID: "flamecaller", label: "Flamecaller Female", isBasePortrait: false),
        PortraitDefinition(portrait: .starweaverMale, path: .embermage, subpathID: "starweaver", label: "Voidweaver Male", isBasePortrait: false),
        PortraitDefinition(portrait: .starweaverFemale, path: .embermage, subpathID: "starweaver", label: "Voidweaver Female", isBasePortrait: false),
        PortraitDefinition(portrait: .dawnshieldMale, path: .oathkeeper, subpathID: "dawnshield", label: "Dawnshield Male", isBasePortrait: false),
        PortraitDefinition(portrait: .dawnshieldFemale, path: .oathkeeper, subpathID: "dawnshield", label: "Dawnshield Female", isBasePortrait: false),
        PortraitDefinition(portrait: .judgementFlameMale, path: .oathkeeper, subpathID: "judgement-flame", label: "Judgement Flame Male", isBasePortrait: false),
        PortraitDefinition(portrait: .judgementFlameFemale, path: .oathkeeper, subpathID: "judgement-flame", label: "Judgement Flame Female", isBasePortrait: false)
    ]

    static func originDefinition(for origin: Origin) -> OriginDefinition {
        origins.first { $0.origin == origin } ?? origins[0]
    }

    static func pathDefinition(for path: Path) -> PathDefinition {
        paths.first { $0.path == path } ?? paths[0]
    }

    static func basePortraits(for path: Path) -> [PortraitDefinition] {
        basePortraits.filter { $0.path == path }
    }

    static func subpathPortraits(for subpath: Subpath) -> [PortraitDefinition] {
        subpathPortraits.filter { $0.subpathID == subpath.id }
    }

    static func firstBasePortrait(for path: Path) -> Portrait {
        basePortraits(for: path).first?.portrait ?? .bladeguardBaseMale
    }

    private static func ability(_ id: String, _ name: String, _ summary: String, _ actionType: ActionType, _ damageType: DamageType?) -> Ability {
        Ability(id: id, name: name, summary: summary, actionType: actionType, requiredLevel: 1, damageType: damageType, conditionApplied: nil)
    }

    private static func subpath(_ id: String, _ name: String, _ path: Path, _ summary: String) -> Subpath {
        Subpath(id: id, name: name, parentPath: path, summary: summary, unlockLevel: 3)
    }
}
