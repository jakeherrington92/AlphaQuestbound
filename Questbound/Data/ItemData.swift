import Foundation

struct ItemDefinition: Identifiable, Hashable {
    let id: String
    let name: String
    let category: ItemCategory
    let rarity: Rarity
    let slots: [EquipmentSlot]
    let damage: String?
    let attackAttribute: AttributeType?
    let defenceBase: Int?
    let agilityModifierCap: Int?
    let defenceBonus: Int
    let effectText: String
    let value: Int
    let levelRequirement: Int?
    let pathRequirement: Path?
    let subpathRequirement: String?
    let description: String
    let isSellable: Bool
    let usesBothHands: Bool

    var isEquippable: Bool {
        !slots.isEmpty
    }

    var iconAssetName: String {
        switch name {
        case "Iron Sword": return "icon_weapon_iron_sword"
        case "Twin Daggers": return "icon_weapon_twin_daggers"
        case "Shortbow": return "icon_weapon_shortbow"
        case "Hunting Knife": return "icon_weapon_hunting_knife"
        case "Rune Staff": return "icon_weapon_rune_staff"
        case "Vowblade": return "icon_weapon_vowblade"
        case "Wooden Shield": return "icon_armour_wooden_shield"
        case "Rust-marked Shield": return "icon_armour_rust_marked_shield"
        case "Chain Vest": return "icon_armour_chain_vest"
        case "Leather Vest": return "icon_armour_leather_vest"
        case "Cloth Robe": return "icon_armour_cloth_robe"
        case "Minor Healing Draught": return "icon_consumable_minor_healing_draught"
        case "Stone Shards": return "icon_material_stone_shards"
        default:
            return "icon_\(category.rawValue)_\(id.replacingOccurrences(of: "-", with: "_"))"
        }
    }

    var isStackable: Bool {
        [.consumable, .material, .miscellaneous, .questItem].contains(category)
    }

    var pathTags: [Path] {
        if name.localizedCaseInsensitiveContains("Stamina Draught") {
            return [.bladeguard, .shadowstep, .wildwarden]
        }
        if let pathRequirement {
            return [pathRequirement]
        }
        if let subpathRequirement, let path = Self.pathForSubpath(subpathRequirement) {
            return [path]
        }

        let text = identityText
        var tags = Set<Path>()
        if category == .weapon {
            let weaponTags = Set(buildTags)
            let isOathWeapon = ["oath", "vow", "dawn", "sunsteel", "mercy", "verdict"]
                .contains { text.contains($0) }

            if weaponTags.contains("Bow") {
                return [.wildwarden]
            }
            if weaponTags.contains("Dagger") || name.localizedCaseInsensitiveContains("Hunting Knife") {
                return [.shadowstep]
            }
            if weaponTags.contains("Spear") {
                return [.wildwarden]
            }
            if weaponTags.contains("Staff") || weaponTags.contains("Rod") {
                return [.embermage]
            }
            if weaponTags.contains("Axe") {
                return [.bladeguard]
            }
            if isOathWeapon {
                return [.oathkeeper]
            }
            if weaponTags.contains("Sword") || weaponTags.contains("Mace") {
                return [.bladeguard, .oathkeeper]
            }
        }

        if containsAny(text, ["sword", "axe", "mace", "shield", "chain", "plate", "guard", "physical damage"]) {
            tags.insert(.bladeguard)
        }
        if containsAny(text, ["dagger", "shiv", "stealth", "poison", "venom", "exposed", "nightglass"]) {
            tags.insert(.shadowstep)
        }
        if containsAny(text, ["bow", "spear", "hunter", "survival", "awareness", "marked", "moonleaf"]) {
            tags.insert(.wildwarden)
        }
        if containsAny(text, ["staff", "rod", "robe", "focus", "spell", "arcane", "ember", "fire"]) {
            tags.insert(.embermage)
        }
        if containsAny(text, ["vow", "oath", "dawn", "sunsteel", "mercy", "healing", "presence"]) {
            tags.insert(.oathkeeper)
        }
        return Path.allCases.filter { tags.contains($0) && structurallyFits(path: $0) }
    }

    var subpathTags: [String] {
        if let subpathRequirement {
            return [subpathRequirement]
        }

        let text = identityText
        var tags = Set<String>()
        if containsAny(text, ["shield", "defending", "damage reduction", "reduce physical", "bulwark"]) {
            tags.insert("Iron Vanguard")
        }
        if containsAny(text, ["initiative", "first successful attack", "speed", "tempest", "mobility"]) {
            tags.insert("Storm Duelist")
        }
        if containsAny(text, ["opening strike", "stealth", "nightglass", "venom", "exposed"]) {
            tags.insert("Nightblade")
        }
        if containsAny(text, ["quick item", "trap", "debuff", "utility", "flash dust"]) {
            tags.insert("Trickhand")
        }
        if containsAny(text, ["packwarden", "marked enemies", "hunter's token", "spear"]) {
            tags.insert("Beastcaller")
        }
        if containsAny(text, ["marked shot", "bow", "accuracy", "thornstring"]) {
            tags.insert("Deepwood Archer")
        }
        if containsAny(text, ["fire spell", "burning", "cinder", "ember"]) {
            tags.insert("Flamecaller")
        }
        if containsAny(text, ["arcane", "ward", "star", "focus"]) {
            tags.insert("Voidweaver")
        }
        if containsAny(text, ["healing", "dawn", "mercy", "defence when defending"]) {
            tags.insert("Dawnshield")
        }
        if containsAny(text, ["oathfire", "verdict", "smite", "weaken"]) {
            tags.insert("Judgement Flame")
        }
        return tags.sorted().filter { subpath in
            guard let path = Self.pathForSubpath(subpath) else { return false }
            return structurallyFits(path: path)
        }
    }

    var gearRoleTags: [String] {
        let text = identityText
        var tags = Set<String>()
        if category == .weapon { tags.insert("Melee") }
        if containsAny(text, ["bow", "ranged"]) { tags.insert("Ranged"); tags.remove("Melee") }
        if containsAny(text, ["staff", "rod", "spell", "arcane"]) { tags.insert("Spell") }
        if slots.contains(.offHand), defenceBonus > 0 { tags.insert("Shield") }
        if category == .armour || defenceBonus > 0 { tags.insert("Defence") }
        let keywordTags: [(String, String)] = [
            ("stealth", "Stealth"), ("thievery", "Thievery"), ("awareness", "Awareness"),
            ("athletics", "Athletics"), ("poison", "Poison"), ("venom", "Poison"),
            ("fire", "Fire"), ("ember", "Fire"), ("frost", "Frost"),
            ("arcane", "Arcane"), ("oathfire", "Oathfire"), ("healing", "Healing"),
            ("focus", "Focus"), ("marked", "Marking"), ("initiative", "Mobility"),
            ("critical", "Crit"), ("survival", "Survival"), ("support", "Support"),
            ("guard", "Tank"), ("defending", "Tank"), ("burst", "Burst")
        ]
        for (keyword, tag) in keywordTags where text.contains(keyword) {
            tags.insert(tag)
        }
        return tags.sorted()
    }

    var buildTags: [String] {
        var tags = Set(gearRoleTags)
        let text = identityText
        let keywordTags: [(String, String)] = [
            ("sword", "Sword"), ("axe", "Axe"), ("mace", "Mace"),
            ("dagger", "Dagger"), ("shiv", "Dagger"), ("bow", "Bow"),
            ("spear", "Spear"), ("staff", "Staff"), ("rod", "Staff"),
            ("shield", "Shield"), ("chain", "Chain"), ("robe", "Robe"),
            ("block", "Block"), ("damage reduction", "Damage Reduction"),
            ("attack rolls", "Accuracy"), ("exposed", "Exposed"),
            ("ward", "Ward"), ("debuff", "Debuff"), ("utility", "Utility")
        ]
        for (keyword, tag) in keywordTags where text.contains(keyword) {
            tags.insert(tag)
        }
        return tags.sorted()
    }

    private var identityText: String {
        "\(name) \(description) \(effectText) \(damage ?? "")".lowercased()
    }

    private func containsAny(_ text: String, _ values: [String]) -> Bool {
        values.contains(where: text.contains)
    }

    func structurallyFits(path: Path) -> Bool {
        guard isEquippable else { return true }
        let tags = Set(buildTags)

        if category == .weapon {
            switch path {
            case .bladeguard:
                return !tags.isDisjoint(with: ["Sword", "Axe", "Mace"])
            case .shadowstep:
                return tags.contains("Dagger")
            case .wildwarden:
                return tags.contains("Bow") || tags.contains("Spear") || name == "Hunting Knife"
            case .embermage:
                return tags.contains("Staff")
            case .oathkeeper:
                return tags.contains("Sword") || tags.contains("Mace")
            }
        }

        if slots.contains(.offHand), defenceBonus > 0 {
            return path == .bladeguard || path == .oathkeeper
        }
        if slots.contains(.chest) {
            if tags.contains("Robe") { return path == .embermage }
            if tags.contains("Chain") || tags.contains("Plate") {
                return path == .bladeguard || path == .oathkeeper
            }
            if name.localizedCaseInsensitiveContains("Leather")
                || name.localizedCaseInsensitiveContains("Vest") {
                return path == .shadowstep || path == .wildwarden
                    || (path == .embermage && tags.contains("Fire"))
            }
        }
        return true
    }

    private static func pathForSubpath(_ subpath: String) -> Path? {
        switch subpath {
        case "Iron Vanguard", "Storm Duelist":
            return .bladeguard
        case "Nightblade", "Trickhand":
            return .shadowstep
        case "Beastcaller", "Deepwood Archer":
            return .wildwarden
        case "Flamecaller", "Starweaver", "Voidweaver":
            return .embermage
        case "Dawnshield", "Judgement Flame":
            return .oathkeeper
        default:
            return nil
        }
    }
}

enum ItemData {
    enum BuildFit: Int, Comparable {
        case incompatible = -1
        case offPath = 0
        case general = 1
        case path = 2
        case subpath = 3

        static func < (lhs: BuildFit, rhs: BuildFit) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    static let inventoryLimits: [ItemCategory: Int?] = [
        .weapon: 20,
        .armour: 20,
        .charm: 20,
        .consumable: 20,
        .material: nil,
        .miscellaneous: nil,
        .questItem: nil
    ]

    static let equipmentSlots: [EquipmentSlot] = [
        .mainWeapon,
        .offHand,
        .head,
        .chest,
        .hands,
        .legs,
        .feet,
        .charm1,
        .charm2
    ]

    static var allItems: [ItemDefinition] {
        startingItems + expandedItems + lootItems
    }

    static let startingItems: [ItemDefinition] = [
        ItemDefinition(
            id: "iron-sword",
            name: "Iron Sword",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon],
            damage: "1d8 physical",
            attackAttribute: .might,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Reliable melee weapon.",
            value: 35,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A plain but trustworthy sword carried by new Bladeguards.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "twin-daggers",
            name: "Twin Daggers",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon, .offHand],
            damage: "1d4 + 1d4 physical",
            attackAttribute: .agility,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Uses Main Weapon and Off-Hand.",
            value: 35,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A matched pair of quick blades for close precision work.",
            isSellable: true,
            usesBothHands: true
        ),
        ItemDefinition(
            id: "shortbow",
            name: "Shortbow",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon, .offHand],
            damage: "1d6 physical",
            attackAttribute: .agility,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Uses Main Weapon and Off-Hand.",
            value: 35,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A compact bow suited to woods, tunnels and quick travel.",
            isSellable: true,
            usesBothHands: true
        ),
        ItemDefinition(
            id: "hunting-knife",
            name: "Hunting Knife",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon, .offHand],
            damage: "1d4 physical",
            attackAttribute: .agility,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Can be held in either hand.",
            value: 10,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A practical knife for camp work, skinning and desperate fights.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "rune-staff",
            name: "Rune Staff",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon],
            damage: "1d6 physical / spell focus",
            attackAttribute: .mind,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Spell focus for Mind-based magic.",
            value: 45,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A staff marked with simple focus runes.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "vowblade",
            name: "Vowblade",
            category: .weapon,
            rarity: .common,
            slots: [.mainWeapon],
            damage: "1d8 physical",
            attackAttribute: .might,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "A simple oathbound blade.",
            value: 40,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A balanced sword used by novice Oathkeepers.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "wooden-shield",
            name: "Wooden Shield",
            category: .armour,
            rarity: .common,
            slots: [.offHand],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 2,
            effectText: "+2 Defence.",
            value: 15,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A sturdy shield of layered wood and iron binding.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "cloth-robe",
            name: "Cloth Robe",
            category: .armour,
            rarity: .common,
            slots: [.chest],
            damage: nil,
            attackAttribute: nil,
            defenceBase: 10,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Defence 10 + full Agility modifier.",
            value: 20,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "Light robes that do not restrict movement.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "leather-vest",
            name: "Leather Vest",
            category: .armour,
            rarity: .common,
            slots: [.chest],
            damage: nil,
            attackAttribute: nil,
            defenceBase: 11,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Defence 11 + full Agility modifier.",
            value: 35,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "Flexible protection for scouts and quick fighters.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "chain-vest",
            name: "Chain Vest",
            category: .armour,
            rarity: .common,
            slots: [.chest],
            damage: nil,
            attackAttribute: nil,
            defenceBase: 13,
            agilityModifierCap: 2,
            defenceBonus: 0,
            effectText: "Defence 13 + Agility modifier, maximum +2.",
            value: 60,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A short chain vest that favours protection over grace.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "minor-healing-draught",
            name: "Minor Healing Draught",
            category: .consumable,
            rarity: .common,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Restores 1d8 + 2 HP.",
            value: 15,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A bitter red draught for emergency healing.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "adventurers-pack",
            name: "Adventurer's Pack",
            category: .miscellaneous,
            rarity: .common,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Basic utility supplies.",
            value: 5,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "Rope, chalk, rations and other humble necessities.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "thiefs-tools",
            name: "Thief's Tools",
            category: .miscellaneous,
            rarity: .common,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Useful for locks and delicate work.",
            value: 15,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "Small picks, hooks and tension tools in a folded wrap.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "focus-stone",
            name: "Focus Stone",
            category: .charm,
            rarity: .common,
            slots: [.charm1, .charm2],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Simple focus utility item.",
            value: 15,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A smooth stone that helps anchor focus exercises.",
            isSellable: true,
            usesBothHands: false
        ),
        ItemDefinition(
            id: "rust-marked-shield",
            name: "Rust-marked Shield",
            category: .armour,
            rarity: .uncommon,
            slots: [.offHand],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 2,
            effectText: "+2 Defence. A battered shield marked with a rust-red symbol.",
            value: 90,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "A battered shield marked with a rust-red symbol. It feels heavier than it should.",
            isSellable: true,
            usesBothHands: false
        )
    ]

    static let lootItems: [ItemDefinition] = [
        material("Stone Shards", rarity: .common, value: 1, description: "Sharp chips of mine stone with faint mineral flecks."),
        material("Bone Splinters", rarity: .common, value: 1, description: "Small fragments of pale bone used by hedge-workers and trinket makers."),
        material("Hide Scraps", rarity: .common, value: 1, description: "Rough scraps that still have a little practical worth."),
        material("Iron Ingots", rarity: .uncommon, value: 5, description: "Simple bars of workable iron."),
        material("Ember Dust", rarity: .uncommon, value: 5, description: "Warm red grit prized by fire-touched crafters."),
        material("Moonleaf", rarity: .uncommon, value: 5, description: "A silver-green leaf that keeps its sheen after drying."),
        material("Bloodstone", rarity: .rare, value: 15, description: "A dark red stone with a glassy inner gleam."),
        material("Star Shards", rarity: .rare, value: 15, description: "Tiny bright fragments said to come from fallen sky-rock."),
        material("Oathglass", rarity: .rare, value: 15, description: "Clear glassy mineral used in vowcraft and reliquaries."),
        material("Relic Fragment", rarity: .uncommon, value: 8, description: "A carved piece of funerary stone carrying traces of old warding."),
        material("Crypt Bell Shard", rarity: .rare, value: 20, description: "A blue-black splinter from an ancient bell beneath the marsh."),
        material("Ember Shard", rarity: .common, value: 3, description: "A warm crystal shard from Ember Cave. No crafting use in Version 1."),
        material("Scorched Ore", rarity: .uncommon, value: 10, description: "Dark ore veined with old heat. No crafting use in Version 1."),
        material("Emberheart Fragment", rarity: .rare, value: 30, description: "A fragment of unstable emberstone from the Emberheart Golem. No crafting use in Version 1."),
        misc("Cracked Fang", value: 2, description: "A broken fang with just enough curiosity value to sell."),
        misc("Torn Raider Cloth", value: 3, description: "Identifiable cloth from a raider sash or banner."),
        misc("Rusted Buckle", value: 4, description: "A sturdy buckle with rust in the hinge."),
        misc("Old Silver Coin", value: 8, description: "A worn coin from an older Greywick mint."),
        misc("Clouded Gem Shard", value: 10, description: "A cloudy gem fragment, pretty but flawed."),
        misc("Strange Bone Token", value: 15, description: "A carved token with uncertain meaning."),
        misc("Brute Horn", value: 25, description: "A heavy horn taken from a dangerous brute."),
        misc("Ancient Relic Fragment", value: 40, description: "A fragment of some older worked object."),
        misc("Ember Scale", value: 50, description: "A warm scale with a red-orange sheen.")
    ]

    static let expandedItems: [ItemDefinition] = [
        weapon("Rusted Sword", type: "Sword", rarity: .common, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "Worn but usable.", value: 10),
        weapon("Hand Axe", type: "Axe", rarity: .common, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "Simple chopping weapon.", value: 25),
        weapon("Wooden Mace", type: "Mace", rarity: .common, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "Plain blunt weapon.", value: 20),
        weapon("Simple Dagger", type: "Dagger", rarity: .common, slots: [.mainWeapon], damage: "1d4 physical", attribute: .agility, effect: "Light and easy to conceal.", value: 10),
        weapon("Hunting Spear", type: "Spear", rarity: .common, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "Reach weapon for hunters and guards.", value: 30),
        weapon("Wooden Staff", type: "Staff", rarity: .common, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "Simple walking staff pressed into combat.", value: 15),

        weapon("Balanced Sword", type: "Sword", rarity: .uncommon, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "+1 to attack rolls.", value: 110),
        weapon("Heavy Axe", type: "Axe", rarity: .uncommon, slots: [.mainWeapon], damage: "1d10 physical", attribute: .might, effect: "-1 initiative.", value: 120),
        weapon("Guard Mace", type: "Mace", rarity: .uncommon, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "+1 Defence when Defending.", value: 130),
        weapon("Silent Fang", type: "Dagger", rarity: .uncommon, slots: [.mainWeapon], damage: "1d4 + 1 physical", attribute: .agility, effect: "+1 Stealth.", value: 100),
        weapon("Hunter's Bow", type: "Bow", rarity: .uncommon, slots: [.mainWeapon, .offHand], damage: "1d8 physical", attribute: .agility, effect: "Uses Main Weapon and Off-Hand.", value: 100, usesBothHands: true),
        weapon("Barbed Spear", type: "Spear", rarity: .uncommon, slots: [.mainWeapon], damage: "1d6 physical", attribute: .might, effect: "+1 damage vs Marked enemies.", value: 120),
        weapon("Focus Staff", type: "Staff", rarity: .uncommon, slots: [.mainWeapon], damage: "1d6 physical / spell focus", attribute: .mind, effect: "+1 spell attack.", value: 140),
        weapon("Oathbound Blade", type: "Sword", rarity: .uncommon, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "+1 Presence checks.", value: 140),

        weapon("Emberforged Sword", type: "Sword", rarity: .rare, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "Once per combat, add +1d4 fire damage.", value: 260),
        weapon("Ironbite Axe", type: "Axe", rarity: .rare, slots: [.mainWeapon], damage: "1d10 physical", attribute: .might, effect: "Critical hits apply Bleeding.", value: 280),
        weapon("Dawnhammer", type: "Mace", rarity: .rare, slots: [.mainWeapon], damage: "1d10 physical", attribute: .might, effect: "Once per combat, add +1d4 Oathfire.", value: 300),
        weapon("Venomfang Dagger", type: "Dagger", rarity: .rare, slots: [.mainWeapon], damage: "1d4 physical", attribute: .agility, effect: "Once per combat, add +1d6 poison.", value: 260),
        weapon("Ashpiercer Bow", type: "Bow", rarity: .rare, slots: [.mainWeapon, .offHand], damage: "1d8 physical", attribute: .agility, effect: "Once per combat, add +1d4 fire.", value: 280, usesBothHands: true),
        weapon("Moonhook Spear", type: "Spear", rarity: .rare, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "+1 Awareness.", value: 250),
        weapon("Starwood Staff", type: "Staff", rarity: .rare, slots: [.mainWeapon], damage: "1d6 physical / spell focus", attribute: .mind, effect: "+1 max Focus.", value: 310),
        weapon("Sunsteel Blade", type: "Sword", rarity: .rare, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "Oathfire damage +1.", value: 320),

        weapon("Bastion Edge", type: "Sword", rarity: .epic, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "When Defending, gain +1 extra Defence.", value: 800, level: 3, subpath: "Iron Vanguard"),
        weapon("Tempest Sabre", type: "Sword", rarity: .epic, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "First successful attack each combat deals +2 damage.", value: 800, level: 3, subpath: "Storm Duelist"),
        weapon("Gloamfang Dagger", type: "Dagger", rarity: .epic, slots: [.mainWeapon], damage: "1d4 physical", attribute: .agility, effect: "Opening Strike deals +2 damage.", value: 780, level: 3, subpath: "Nightblade"),
        weapon("Tinker's Shiv", type: "Dagger", rarity: .epic, slots: [.mainWeapon], damage: "1d4 physical", attribute: .agility, effect: "After using a quick item, next attack deals +2 damage once per combat.", value: 760, level: 3, subpath: "Trickhand"),
        weapon("Packwarden Spear", type: "Spear", rarity: .epic, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "Marked enemies take +2 damage from the next attack.", value: 800, level: 3, subpath: "Beastcaller"),
        weapon("Thornstring Bow", type: "Bow", rarity: .epic, slots: [.mainWeapon, .offHand], damage: "1d8 physical", attribute: .agility, effect: "Marked Shot gains +1 to hit and +1 damage.", value: 820, level: 3, subpath: "Deepwood Archer", usesBothHands: true),
        weapon("Cinderheart Staff", type: "Staff", rarity: .epic, slots: [.mainWeapon], damage: "1d6 physical / spell focus", attribute: .mind, effect: "Fire spells deal +2 damage.", value: 850, level: 3, subpath: "Flamecaller"),
        weapon("Astral Rod", type: "Rod/Staff", rarity: .epic, slots: [.mainWeapon], damage: "1d6 physical / spell focus", attribute: .mind, effect: "Void Ward reduces +2 extra damage. Focus for void and arcane disruption.", value: 840, level: 3, subpath: "Voidweaver"),
        weapon("Mercybrand Mace", type: "Mace", rarity: .epic, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "Healing abilities restore +2 HP.", value: 820, level: 3, subpath: "Dawnshield"),
        weapon("Verdict Blade", type: "Sword", rarity: .epic, slots: [.mainWeapon], damage: "1d8 physical", attribute: .might, effect: "Oathfire damage +2.", value: 850, level: 3, subpath: "Judgement Flame"),

        armour("Simple Hood", rarity: .common, slots: [.head], effect: "+1 Stealth in darkness.", value: 20),
        armour("Leather Gloves", rarity: .common, slots: [.hands], effect: "+1 Thievery.", value: 15),
        armour("Traveller's Trousers", rarity: .common, slots: [.legs], effect: "+1 Survival.", value: 15),
        armour(
            "Worn Boots",
            rarity: .common,
            slots: [.feet],
            effect: "+1 Initiative.",
            value: 15,
            description: "Scuffed but sturdy boots. They help you move a little faster."
        ),
        armour("Reinforced Leather", rarity: .uncommon, slots: [.chest], defenceBase: 11, effect: "Defence 11 + full Agility modifier. +1 max HP.", value: 110),
        armour("Guard Chain", rarity: .uncommon, slots: [.chest], defenceBase: 13, agilityCap: 2, effect: "Defence 13 + Agility modifier, maximum +2. +1 Defence when Defending.", value: 150),
        armour("Focus Robe", rarity: .uncommon, slots: [.chest], defenceBase: 10, effect: "Defence 10 + full Agility modifier. +1 Focus.", value: 140),
        armour("Watcher's Hood", rarity: .uncommon, slots: [.head], defenceBonus: 1, effect: "+1 Awareness.", value: 90),
        armour("Gripwrap Gloves", rarity: .uncommon, slots: [.hands], effect: "+1 Athletics.", value: 80),
        armour("Silent Boots", rarity: .uncommon, slots: [.feet], effect: "+1 Stealth.", value: 100),
        armour("Runner's Boots", rarity: .uncommon, slots: [.feet], effect: "+1 Initiative. +1 to Flee checks.", value: 110),
        armour("Emberhide Vest", rarity: .rare, slots: [.chest], defenceBase: 11, effect: "Defence 11 + full Agility modifier. Fire Resistance 2.", value: 260),
        armour("Moonthread Robe", rarity: .rare, slots: [.chest], defenceBase: 10, effect: "Defence 10 + full Agility modifier. +1 Focus, +1 Arcana.", value: 280),
        armour("Ironwall Chain", rarity: .rare, slots: [.chest], defenceBase: 13, agilityCap: 2, effect: "Defence 13 + Agility modifier, maximum +2. Once per combat reduce physical damage by 2.", value: 320),
        armour("Dawnbound Helm", rarity: .rare, slots: [.head], defenceBonus: 1, effect: "+1 Presence checks, resist fear.", value: 240),
        armour("Venomguard Gloves", rarity: .rare, slots: [.hands], defenceBonus: 1, effect: "Poison Resistance 2.", value: 220),
        armour("Stonewalker Greaves", rarity: .rare, slots: [.legs], defenceBonus: 1, effect: "Resist Knocked Down once per combat.", value: 260),
        armour("Shadowstep Boots", rarity: .rare, slots: [.feet], defenceBonus: 1, effect: "+1 Agility checks for Stealth or Flee.", value: 280),
        armour("Stormguard Plate", rarity: .epic, slots: [.chest], defenceBase: 16, agilityCap: 0, effect: "Defence 16. Shock Resistance 3.", value: 750),
        armour("Robe of Falling Stars", rarity: .epic, slots: [.chest], defenceBase: 10, effect: "Defence 10 + full Agility modifier. +2 Focus, Arcane Ward +1 reduction.", value: 760),
        armour("Nightglass Vest", rarity: .epic, slots: [.chest], defenceBase: 11, effect: "Defence 11 + full Agility modifier. First turn +1 Defence and +1 attack.", value: 740),
        armour("Bulwark Chain", rarity: .epic, slots: [.chest], defenceBase: 13, agilityCap: 2, effect: "Defence 13 + Agility modifier, maximum +2. Once per combat reduce physical damage by 1d6.", value: 780),
        armour("Embercrown Circlet", rarity: .epic, slots: [.head], defenceBonus: 1, effect: "Fire spells +1 damage.", value: 620),
        armour("Dawnforged Gauntlets", rarity: .epic, slots: [.hands], defenceBonus: 1, effect: "Healing +1 HP.", value: 650),
        armour("Windstep Boots", rarity: .epic, slots: [.feet], defenceBonus: 1, effect: "+2 initiative, once per combat reroll Flee check.", value: 620),

        charm("Cracked Luck Token", rarity: .common, effect: "Once/adventure reroll d100 loot roll under 10.", value: 60),
        charm("Copper Ring", rarity: .common, effect: "+1 max HP.", value: 50),
        charm("Ember Chip", rarity: .common, effect: "Fire Resistance 1.", value: 70),
        charm("Bone Charm", rarity: .common, effect: "+1 Endurance vs poison.", value: 60),
        charm("Traveller's Coin", rarity: .common, effect: "+1 gold from minor enemies.", value: 70),
        charm("Lucky Copper Charm", rarity: .uncommon, effect: "Boss Fortune succeeds on 14+.", value: 160),
        charm("Minor Focus Charm", rarity: .uncommon, effect: "+1 max Focus.", value: 160),
        charm("Hunter's Token", rarity: .uncommon, effect: "+1 damage vs Marked once/combat.", value: 150),
        charm("Guard Stone", rarity: .uncommon, effect: "Once/combat +1 Defence after hit.", value: 170),
        charm("Swift Thread", rarity: .uncommon, effect: "+1 initiative.", value: 150),
        charm("Gilded Chance Token", rarity: .rare, effect: "Boss Fortune succeeds on 13+.", value: 340),
        charm("Bloodstone Pendant", rarity: .rare, effect: "Once/combat below half HP, next attack +2 damage.", value: 360),
        charm("Moonlit Loop", rarity: .rare, effect: "Advantage on one Awareness check/adventure.", value: 300),
        charm("Ember Charm", rarity: .rare, effect: "Fire spells/attacks +1 once/combat.", value: 340),
        charm("Oathglass Token", rarity: .rare, effect: "Oathfire +1 once/combat.", value: 360),
        charm("Fortune-Kissed Pendant", rarity: .epic, effect: "Boss Fortune succeeds on 13+. On failure, the boss gold penalty is reduced to 15%.", value: 800),
        charm("Charm of the Last Breath", rarity: .epic, effect: "Once/adventure reduced to 0 HP, stay at 1 HP.", value: 900),
        charm("Stormheart Charm", rarity: .epic, effect: "Once/combat +1d6 shock to attack.", value: 850),
        charm("Starward Seal", rarity: .epic, effect: "Once/combat reduce incoming magic by 1d6.", value: 820),
        charm("Bloodfire Charm", rarity: .epic, effect: "Burning/Bleeding you apply +1 damage.", value: 830),

        consumable("Healing Draught", rarity: .uncommon, effect: "Restores 2d8 + 3 HP.", value: 45),
        consumable("Greater Healing Draught", rarity: .rare, effect: "Restores 3d8 + 5 HP.", value: 110),
        consumable("Hero's Healing Draught", rarity: .epic, effect: "Restores 4d8 + 8 HP.", value: 220),
        consumable(
            "Minor Stamina Draught",
            rarity: .common,
            effect: "Restore 1 Stamina.",
            value: 35,
            level: 1,
            description: "A sharp herbal draught that helps tired muscles recover. Restores 1 Stamina."
        ),
        consumable(
            "Stamina Draught",
            rarity: .uncommon,
            effect: "Restore 2 Stamina.",
            value: 75,
            level: 2,
            description: "A stronger draught used by fighters, scouts and hunters. Restores 2 Stamina."
        ),
        consumable(
            "Greater Stamina Draught",
            rarity: .rare,
            effect: "Restore 3 Stamina.",
            value: 140,
            level: 3,
            description: "A powerful recovery draught for exhausting techniques. Restores 3 Stamina."
        ),
        consumable(
            "Hero's Stamina Draught",
            rarity: .epic,
            effect: "Restore Stamina to full.",
            value: 260,
            level: 5,
            description: "A rare draught said to return strength to even the most exhausted hero. Restores Stamina to full."
        ),
        consumable("Smoke Powder", rarity: .common, effect: "+2 next Flee/Stealth.", value: 25),
        consumable("Fire Oil", rarity: .uncommon, effect: "Next weapon hit +1d4 fire.", value: 60),
        consumable("Antivenom", rarity: .common, effect: "Remove Poisoned.", value: 30),
        consumable("Stone Salve", rarity: .uncommon, effect: "Remove Knocked Down and +1 Defence until next turn.", value: 45),
        consumable("Flash Dust", rarity: .rare, effect: "Apply Exposed one turn.", value: 100),
        consumable("Focus Tonic", rarity: .rare, effect: "Restore 1 Focus.", value: 120),
        consumable("Wardstone Shard", rarity: .epic, effect: "Reduce next damage by 1d8.", value: 180)
    ]

    static func definition(named name: String) -> ItemDefinition? {
        allItems.first { $0.name == name }
    }

    static func itemNames(in hero: Hero, category: ItemCategory) -> [String] {
        hero.inventory.itemQuantities.keys
            .filter { definition(named: $0)?.category == category }
            .sorted()
    }

    static func isEquipped(_ itemName: String, hero: Hero) -> Bool {
        hero.equippedItems.slots.values.contains(itemName)
    }

    static func equippedQuantity(_ itemName: String, hero: Hero) -> Int {
        guard isEquipped(itemName, hero: hero) else { return 0 }
        if definition(named: itemName)?.usesBothHands == true {
            return 1
        }
        return hero.equippedItems.slots.values.filter { $0 == itemName }.count
    }

    static func backpackQuantity(_ itemName: String, hero: Hero) -> Int {
        let ownedQuantity = hero.inventory.itemQuantities[itemName] ?? 0
        guard definition(named: itemName)?.isEquippable == true else {
            return ownedQuantity
        }
        return max(ownedQuantity - equippedQuantity(itemName, hero: hero), 0)
    }

    static func backpackItemNames(in hero: Hero, category: ItemCategory) -> [String] {
        itemNames(in: hero, category: category)
            .filter { backpackQuantity($0, hero: hero) > 0 }
    }

    static func bestEmptySlot(for item: ItemDefinition, hero: Hero) -> EquipmentSlot? {
        item.slots.first { slot in
            isCompatible(item, with: slot, hero: hero) && hero.equippedItems.slots[slot] == nil
        }
    }

    static func upgradePromptSlot(for item: ItemDefinition, hero: Hero) -> EquipmentSlot? {
        bestEmptySlot(for: item, hero: hero)
            ?? item.slots.first { isCompatible(item, with: $0, hero: hero) }
    }

    static func isCompatible(_ item: ItemDefinition, with slot: EquipmentSlot, hero: Hero) -> Bool {
        requirementIssue(for: item, hero: hero) == nil && item.slots.contains(slot)
    }

    static func requirementIssue(for item: ItemDefinition, hero: Hero) -> String? {
        if let levelRequirement = item.levelRequirement, hero.level < levelRequirement {
            return "Requires Level \(levelRequirement)."
        }
        if let pathRequirement = item.pathRequirement, hero.path != pathRequirement {
            return "Requires \(pathRequirement.rawValue)."
        }
        if let subpathRequirement = item.subpathRequirement, hero.subpath != subpathRequirement {
            return "Requires \(subpathRequirement)."
        }
        return nil
    }

    static func isUsableBy(hero: Hero, item: ItemDefinition) -> Bool {
        requirementIssue(for: item, hero: hero) == nil
    }

    static func isSubpathSpecialityFor(hero: Hero, item: ItemDefinition) -> Bool {
        guard hero.level >= 3, let subpath = hero.subpath else { return false }
        return item.subpathTags.contains(subpath)
    }

    static func buildFit(for item: ItemDefinition, hero: Hero) -> BuildFit {
        guard isUsableBy(hero: hero, item: item) else { return .incompatible }
        guard item.structurallyFits(path: hero.path) else { return .offPath }
        if isSubpathSpecialityFor(hero: hero, item: item) {
            return .subpath
        }
        if item.pathTags.contains(hero.path) {
            return .path
        }
        if item.pathTags.isEmpty {
            return .general
        }
        return .offPath
    }

    static func isRecommendedFor(hero: Hero, item: ItemDefinition) -> Bool {
        let fit = buildFit(for: item, hero: hero)
        if !item.isEquippable {
            if staminaDraughtNames.contains(item.name) {
                return hero.maxStamina > 0
            }
            if item.name == "Focus Tonic" {
                return hero.maxFocus > 0
            }
            return fit != .incompatible
        }
        return fit == .path || fit == .subpath || fit == .general
    }

    static func pathMatchScore(hero: Hero, item: ItemDefinition) -> Int {
        switch buildFit(for: item, hero: hero) {
        case .subpath: return 100
        case .path: return 70
        case .general: return 35
        case .offPath: return 10
        case .incompatible: return -100
        }
    }

    static func lootWeightFor(hero: Hero, item: ItemDefinition) -> Int {
        let base = pathMatchScore(hero: hero, item: item)
        guard base >= 0 else { return 0 }
        return base + (item.rarity == .epic && isSubpathSpecialityFor(hero: hero, item: item) ? 50 : 0)
    }

    static func buildFitSummary(for item: ItemDefinition, hero: Hero) -> String {
        switch buildFit(for: item, hero: hero) {
        case .subpath: return "Subpath speciality gear."
        case .path: return "Recommended for your Path."
        case .general: return "Usable by any hero."
        case .offPath: return "Usable, but not ideal for your current Path."
        case .incompatible: return "Not compatible with your current hero."
        }
    }

    static func recommendedForText(for item: ItemDefinition) -> String {
        let paths = item.pathTags.filter { item.structurallyFits(path: $0) }
        return paths.isEmpty ? "Any hero" : paths.map(\.rawValue).joined(separator: ", ")
    }

    static func buildStyleText(for item: ItemDefinition) -> String {
        let tags = item.buildTags
        return tags.isEmpty ? "General" : tags.prefix(5).joined(separator: ", ")
    }

    static func pathAffinityScore(for item: ItemDefinition, hero: Hero) -> Int {
        switch buildFit(for: item, hero: hero) {
        case .subpath: return 4
        case .path: return 3
        case .general: return 1
        case .offPath: return 0
        case .incompatible: return -1
        }
    }

    static func estimatedSellValue(for item: ItemDefinition) -> String {
        guard item.isSellable else { return "Cannot sell" }
        switch item.category {
        case .weapon, .armour, .charm, .consumable:
            return "\(item.value * GameConstants.baseGearSellPercent / 100) gold"
        case .material, .miscellaneous:
            return "\(item.value) gold"
        case .questItem:
            return "Cannot sell"
        }
    }

    static func craftingUseText(for item: ItemDefinition) -> String {
        switch item.name {
        case "Stone Shards":
            return "Upgrade weapon or armour from Level 0 to Level 1."
        case "Bone Splinters":
            return "Low-tier weapon, charm or armour reinforcement material."
        case "Hide Scraps":
            return "Light armour and leather gear upgrades."
        case "Iron Ingots":
            return "Upgrade weapon or armour from Level 1 to Level 2."
        case "Ember Dust":
            return "Fire-related weapon, spell focus or charm upgrades."
        case "Moonleaf":
            return "Survival, healing or ranger-style upgrades."
        case "Bloodstone":
            return "Rare weapon, armour or charm upgrade material."
        case "Star Shards":
            return "Void, arcane and Voidweaver-style upgrades."
        case "Oathglass":
            return "Oathkeeper and Oathfire-related upgrades."
        case "Relic Fragment":
            return "Future relic, ward and crypt-themed crafting."
        case "Crypt Bell Shard":
            return "Future rare ward, weapon and resonance upgrades."
        case "Ember Shard", "Scorched Ore", "Emberheart Fragment":
            return "A future Ember Cave crafting and upgrade material. No crafting use in Version 1."
        default:
            if item.category == .miscellaneous {
                return "This is mainly used for selling."
            }
            if item.category == .material {
                return "Used in future crafting/upgrades."
            }
            return "No crafting use in Version 1."
        }
    }

    static let staminaDraughtNames = [
        "Minor Stamina Draught",
        "Stamina Draught",
        "Greater Stamina Draught",
        "Hero's Stamina Draught"
    ]

    static func defence(for hero: Hero) -> Int {
        let agilityModifier = hero.attributes.modifier(for: .agility)
        let chestName = hero.equippedItems.slots[.chest]
        let chest = chestName.flatMap { definition(named: $0) }

        let baseDefence = chest?.defenceBase ?? 10
        let agilityDefence = min(agilityModifier, chest?.agilityModifierCap ?? agilityModifier)
        let shieldAndBonuses = hero.equippedItems.slots.values
            .compactMap { definition(named: $0)?.defenceBonus }
            .reduce(0, +)

        return baseDefence + agilityDefence + shieldAndBonuses
    }

    static func initiativeBonus(for hero: Hero) -> Int {
        uniqueEquippedItems(for: hero).reduce(0) { total, item in
            let text = item.effectText.lowercased()
            if text.contains("+2 initiative") { return total + 2 }
            if text.contains("+1 initiative") { return total + 1 }
            if text.contains("-1 initiative") { return total - 1 }
            return total
        }
    }

    static func skillBonus(for skill: SkillType, hero: Hero) -> Int {
        uniqueEquippedItems(for: hero).reduce(0) { total, item in
            let text = item.effectText.lowercased()
            let directPhrase = "+1 \(skill.displayName.lowercased())"
            guard text.contains(directPhrase) else { return total }
            if skill == .stealth, text.contains("in darkness") {
                return total
            }
            return total + 1
        }
    }

    static func fleeBonus(for hero: Hero) -> Int {
        uniqueEquippedItems(for: hero).reduce(0) { total, item in
            let text = item.effectText.lowercased()
            if text.contains("+1 to flee checks") || text.contains("stealth or flee") {
                return total + 1
            }
            return total
        }
    }

    private static func uniqueEquippedItems(for hero: Hero) -> [ItemDefinition] {
        Set(hero.equippedItems.slots.values).compactMap(definition(named:))
    }

    static func equippedHero(_ hero: Hero, with item: ItemDefinition, in slot: EquipmentSlot) -> Hero {
        var updatedHero = hero
        var slots = updatedHero.equippedItems.slots

        if item.usesBothHands {
            slots[.mainWeapon] = item.name
            slots[.offHand] = item.name
        } else {
            if slot == .offHand, slots[.mainWeapon].flatMap({ definition(named: $0)?.usesBothHands }) == true {
                slots[.mainWeapon] = replacementMainWeapon(for: hero, preferredItem: item)?.name
            }
            if slot == .mainWeapon, slots[.offHand].flatMap({ definition(named: $0)?.usesBothHands }) == true {
                slots[.offHand] = nil
            }
            slots[slot] = item.name
        }

        updatedHero.equippedItems = EquippedItems(slots: slots)
        return updatedHero
    }

    static func unequippedHero(_ hero: Hero, slot: EquipmentSlot) -> Hero {
        var updatedHero = hero
        var slots = updatedHero.equippedItems.slots
        let currentItem = slots[slot]

        if slot == .mainWeapon, hasAnyWeapon(hero) {
            return hero
        }

        slots[slot] = nil
        if let currentItem,
           definition(named: currentItem)?.usesBothHands == true {
            slots[.mainWeapon] = nil
            slots[.offHand] = nil
        }

        updatedHero.equippedItems = EquippedItems(slots: slots)
        return updatedHero
    }

    private static func hasAnyWeapon(_ hero: Hero) -> Bool {
        hero.inventory.itemQuantities.keys.contains { definition(named: $0)?.category == .weapon }
    }

    private static func replacementMainWeapon(for hero: Hero, preferredItem: ItemDefinition) -> ItemDefinition? {
        if preferredItem.category == .weapon,
           preferredItem.slots.contains(.mainWeapon),
           !preferredItem.usesBothHands {
            return preferredItem
        }

        return hero.inventory.itemQuantities.keys
            .compactMap(definition(named:))
            .first { item in
                item.category == .weapon && item.slots.contains(.mainWeapon) && !item.usesBothHands
            }
    }

    private static func material(_ name: String, rarity: Rarity, value: Int, description: String) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: name,
            category: .material,
            rarity: rarity,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Crafting material. Sell value \(value)g.",
            value: value,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: description,
            isSellable: true,
            usesBothHands: false
        )
    }

    private static func misc(_ name: String, value: Int, description: String) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
            name: name,
            category: .miscellaneous,
            rarity: .common,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: "Sell item. Value \(value)g.",
            value: value,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: description,
            isSellable: true,
            usesBothHands: false
        )
    }

    private static func weapon(
        _ name: String,
        type: String,
        rarity: Rarity,
        slots: [EquipmentSlot],
        damage: String,
        attribute: AttributeType,
        effect: String,
        value: Int,
        level: Int? = nil,
        path: Path? = nil,
        subpath: String? = nil,
        usesBothHands: Bool = false
    ) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: ""),
            name: name,
            category: .weapon,
            rarity: rarity,
            slots: slots,
            damage: damage,
            attackAttribute: attribute,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: effect,
            value: value,
            levelRequirement: level,
            pathRequirement: path,
            subpathRequirement: subpath,
            description: "\(rarity.rawValue.capitalized) \(type.lowercased()) from the Version 1 item pool.",
            isSellable: true,
            usesBothHands: usesBothHands
        )
    }

    private static func armour(
        _ name: String,
        rarity: Rarity,
        slots: [EquipmentSlot],
        defenceBase: Int? = nil,
        agilityCap: Int? = nil,
        defenceBonus: Int = 0,
        effect: String,
        value: Int,
        description: String? = nil
    ) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: ""),
            name: name,
            category: .armour,
            rarity: rarity,
            slots: slots,
            damage: nil,
            attackAttribute: nil,
            defenceBase: defenceBase,
            agilityModifierCap: agilityCap,
            defenceBonus: defenceBonus,
            effectText: effect,
            value: value,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: description ?? "\(rarity.rawValue.capitalized) armour from the Version 1 item pool.",
            isSellable: true,
            usesBothHands: false
        )
    }

    private static func charm(_ name: String, rarity: Rarity, effect: String, value: Int) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: ""),
            name: name,
            category: .charm,
            rarity: rarity,
            slots: [.charm1, .charm2],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: effect,
            value: value,
            levelRequirement: nil,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: "\(rarity.rawValue.capitalized) charm from the Version 1 item pool.",
            isSellable: true,
            usesBothHands: false
        )
    }

    private static func consumable(
        _ name: String,
        rarity: Rarity,
        effect: String,
        value: Int,
        level: Int? = nil,
        description: String? = nil
    ) -> ItemDefinition {
        ItemDefinition(
            id: name.lowercased().replacingOccurrences(of: " ", with: "-").replacingOccurrences(of: "'", with: ""),
            name: name,
            category: .consumable,
            rarity: rarity,
            slots: [],
            damage: nil,
            attackAttribute: nil,
            defenceBase: nil,
            agilityModifierCap: nil,
            defenceBonus: 0,
            effectText: effect,
            value: value,
            levelRequirement: level,
            pathRequirement: nil,
            subpathRequirement: nil,
            description: description ?? "\(rarity.rawValue.capitalized) consumable from the Version 1 item pool.",
            isSellable: true,
            usesBothHands: false
        )
    }
}

extension EquipmentSlot {
    var displayName: String {
        switch self {
        case .mainWeapon: return "Main Weapon"
        case .offHand: return "Off-Hand"
        case .head: return "Head"
        case .chest: return "Chest"
        case .hands: return "Hands"
        case .legs: return "Legs"
        case .feet: return "Feet"
        case .charm1: return "Charm 1"
        case .charm2: return "Charm 2"
        }
    }
}

extension ItemCategory {
    var displayName: String {
        switch self {
        case .weapon: return "Weapons"
        case .armour: return "Armour"
        case .charm: return "Charms"
        case .consumable: return "Consumables"
        case .material: return "Materials"
        case .miscellaneous: return "Miscellaneous"
        case .questItem: return "Quest Items"
        }
    }
}

extension Rarity {
    var displayName: String {
        rawValue.capitalized
    }
}
