import Foundation

struct RewardLineItem: Codable, Equatable, Hashable, Identifiable {
    var id: String { itemName }
    var itemName: String
    var quantity: Int
    var category: ItemCategory
    var rarity: Rarity
}

struct EnemyRewardSummary: Codable, Equatable, Hashable, Identifiable {
    var id: String
    var enemyName: String
    var tier: EnemyTier
    var xp: Int
    var gold: Int
}

struct CombatReward: Codable, Equatable, Hashable, Identifiable {
    var id: UUID
    var encounterID: String
    var enemySummaries: [EnemyRewardSummary]
    var xp: Int
    var nonBossGold: Int
    var bossGold: Int
    var items: [RewardLineItem]
    var bossName: String?

    var totalGold: Int {
        nonBossGold + bossGold
    }

    var hasBossFortune: Bool {
        bossName != nil && bossGold > 0
    }

    init(
        id: UUID = UUID(),
        encounterID: String,
        enemySummaries: [EnemyRewardSummary],
        xp: Int,
        nonBossGold: Int,
        bossGold: Int,
        items: [RewardLineItem],
        bossName: String?
    ) {
        self.id = id
        self.encounterID = encounterID
        self.enemySummaries = enemySummaries
        self.xp = xp
        self.nonBossGold = nonBossGold
        self.bossGold = bossGold
        self.items = items
        self.bossName = bossName
    }
}

enum LootEngine {
    static func reward(for hero: Hero, encounterID: String, enemyIDs: [String]) -> CombatReward {
        let enemies = EnemyData.enemies(ids: enemyIDs)
        var summaries: [EnemyRewardSummary] = []
        var totalXP = 0
        var nonBossGold = 0
        var bossGold = 0
        var itemQuantities: [String: Int] = [:]
        var bossName: String?

        for enemy in enemies {
            let xp = xpReward(for: enemy)
            let gold = Int.random(in: enemy.goldRange)
            totalXP += xp

            if enemy.tier == .boss || enemy.tier == .finalBoss {
                bossGold += gold
                bossName = enemy.name
            } else {
                nonBossGold += gold
            }

            summaries.append(
                EnemyRewardSummary(
                    id: enemy.id,
                    enemyName: enemy.name,
                    tier: enemy.tier,
                    xp: xp,
                    gold: gold
                )
            )

            let drops = enemy.tier == .boss || enemy.tier == .finalBoss
                ? bossGuaranteedLoot(for: enemy, hero: hero, encounterID: encounterID)
                : rolledLoot(for: enemy, hero: hero)
            for item in drops {
                itemQuantities[item.name, default: 0] += 1
            }
        }

        if encounterID == "deep-chamber" {
            itemQuantities["Rust-marked Shield", default: 0] += 1
        }

        let items = itemQuantities
            .compactMap { itemName, quantity -> RewardLineItem? in
                guard let definition = ItemData.definition(named: itemName) else { return nil }
                return RewardLineItem(
                    itemName: itemName,
                    quantity: quantity,
                    category: definition.category,
                    rarity: definition.rarity
                )
            }
            .sorted { lhs, rhs in
                if lhs.category.rawValue == rhs.category.rawValue {
                    return lhs.itemName < rhs.itemName
                }
                return lhs.category.rawValue < rhs.category.rawValue
            }

        return CombatReward(
            encounterID: encounterID,
            enemySummaries: summaries,
            xp: totalXP,
            nonBossGold: nonBossGold,
            bossGold: bossGold,
            items: items,
            bossName: bossName
        )
    }

    static func applied(_ reward: CombatReward, to hero: Hero, finalBossGold: Int? = nil) -> Hero {
        var updated = hero
        let gold = reward.nonBossGold + (finalBossGold ?? reward.bossGold)
        updated.xp += reward.xp
        updated.gold += gold
        updated.inventory.gold = updated.gold

        for item in reward.items {
            updated.inventory.itemQuantities[item.itemName, default: 0] += item.quantity
        }

        updated.lastPlayedAt = Date()
        return updated
    }

    static func pathMatchedGear(for hero: Hero, rarity: Rarity? = nil) -> ItemDefinition? {
        let gearPool = ItemData.allItems.filter { item in
            [.weapon, .armour, .charm].contains(item.category)
                && (rarity == nil || item.rarity == rarity)
                && isLootEligible(item, hero: hero)
        }
        let weighted = gearPool.flatMap { item in
            Array(repeating: item, count: max(1, ItemData.lootWeightFor(hero: hero, item: item)))
        }
        return weighted.randomElement() ?? gearPool.randomElement()
    }

    static func fortuneTarget(for hero: Hero) -> Int {
        let equippedNames = Set(hero.equippedItems.slots.values)
        let inventoryNames = Set(hero.inventory.itemQuantities.keys)
        let names = equippedNames.union(inventoryNames)

        if names.contains("Gilded Chance Token") || names.contains("Fortune-Kissed Pendant") {
            return 13
        }
        if names.contains("Lucky Copper Charm") {
            return 14
        }
        return GameConstants.bossFortuneBaseTarget
    }

    static func hasFortuneKissedPendant(hero: Hero) -> Bool {
        hero.equippedItems.slots.values.contains("Fortune-Kissed Pendant")
            || hero.inventory.itemQuantities.keys.contains("Fortune-Kissed Pendant")
    }

    private static func xpReward(for enemy: Enemy) -> Int {
        switch enemy.tier {
        case .minor: return 25
        case .standard: return 50
        case .strong: return 100
        case .boss: return 200
        case .finalBoss: return 300
        }
    }

    private static func rolledLoot(for enemy: Enemy, hero: Hero) -> [ItemDefinition] {
        var items: [ItemDefinition] = []

        if roll(percent: potionChance(for: enemy.tier)),
           let potion = consumableDrop(for: hero) {
            items.append(potion)
        }
        if roll(percent: materialChance(for: enemy.tier)),
           let material = materialDrop(for: enemy) {
            items.append(material)
        }
        if roll(percent: miscChance(for: enemy.tier)),
           let misc = miscDrop(for: enemy) {
            items.append(misc)
        }
        if roll(percent: gearChance(for: enemy.tier)),
           let gear = gearDrop(for: enemy.tier, hero: hero) {
            items.append(gear)
        }

        return items
    }

    private static func bossGuaranteedLoot(
        for enemy: Enemy,
        hero: Hero,
        encounterID: String
    ) -> [ItemDefinition] {
        var rewards: [ItemDefinition] = []
        let weaponRarity = bossRarity(encounterID: encounterID)
        let armourRarity = bossRarity(encounterID: encounterID)

        if let weapon = bossRewardGear(
            for: hero,
            category: .weapon,
            preferredRarity: weaponRarity
        ) {
            rewards.append(weapon)
        }
        if let armour = bossRewardGear(
            for: hero,
            category: .armour,
            preferredRarity: armourRarity
        ) {
            rewards.append(armour)
        }
        if let material = bossMaterial(encounterID: encounterID, enemy: enemy) {
            rewards.append(material)
        }
        if let bonus = bossBonus(encounterID: encounterID, enemy: enemy, hero: hero) {
            rewards.append(bonus)
        }
        return rewards
    }

    private static func bossRewardGear(
        for hero: Hero,
        category: ItemCategory,
        preferredRarity: Rarity
    ) -> ItemDefinition? {
        let allowedRarities: [Rarity] = [.common, .uncommon, .rare, .epic]
        let orderedRarities = [preferredRarity] + allowedRarities.filter { $0 != preferredRarity }
        for rarity in orderedRarities {
            let pool = ItemData.allItems.filter { item in
                item.category == category
                    && item.rarity == rarity
                    && isLootEligible(item, hero: hero)
                    && [.subpath, .path, .general].contains(ItemData.buildFit(for: item, hero: hero))
            }
            guard !pool.isEmpty else { continue }

            let subpathPool = pool.filter { ItemData.buildFit(for: $0, hero: hero) == .subpath }
            let pathPool = pool.filter { ItemData.buildFit(for: $0, hero: hero) == .path }
            let generalPool = pool.filter { ItemData.buildFit(for: $0, hero: hero) == .general }
            let preferredPool = !subpathPool.isEmpty && Int.random(in: 1...100) <= 60
                ? subpathPool
                : (!pathPool.isEmpty ? pathPool : generalPool)
            let initial = preferredPool.randomElement() ?? pool.randomElement()
            guard let initial else { continue }

            let alreadyOwned = (hero.inventory.itemQuantities[initial.name] ?? 0) > 0
                || hero.equippedItems.slots.values.contains(initial.name)
            if alreadyOwned {
                return pool.filter { $0.id != initial.id }.randomElement() ?? initial
            }
            return initial
        }
        return nil
    }

    private static func bossRarity(encounterID: String) -> Rarity {
        let roll = Int.random(in: 1...100)
        if encounterID == "deep-chamber" || encounterID == "test-bristleback-brute" {
            if roll <= 55 { return .common }
            if roll <= 90 { return .uncommon }
            return .rare
        }
        if encounterID == "crypt-bell-drowned-warden" || encounterID == "test-bell-drowned-warden" {
            if roll <= 35 { return .common }
            if roll <= 80 { return .uncommon }
            if roll <= 98 { return .rare }
            return .epic
        }
        if roll <= 20 { return .common }
        if roll <= 60 { return .uncommon }
        if roll <= 90 { return .rare }
        return .epic
    }

    private static func bossMaterial(encounterID: String, enemy: Enemy) -> ItemDefinition? {
        let names: [String]
        if encounterID.contains("emberheart") || enemy.family.contains("Forge") {
            names = ["Emberheart Fragment", "Scorched Ore", "Ember Shard"]
        } else if encounterID.contains("crypt") || enemy.family.contains("Undead") {
            names = ["Relic Fragment", "Crypt Bell Shard", "Bone Splinters"]
        } else {
            names = ["Stone Shards", "Iron Ingots", "Hide Scraps"]
        }
        return names.randomElement().flatMap(ItemData.definition(named:))
    }

    private static func bossBonus(
        encounterID: String,
        enemy: Enemy,
        hero: Hero
    ) -> ItemDefinition? {
        var names: [String]
        if encounterID.contains("emberheart") || enemy.family.contains("Forge") {
            names = ["Healing Draught", "Fire Oil", "Ember Scale"]
        } else if encounterID.contains("crypt") || enemy.family.contains("Undead") {
            names = ["Old Silver Coin", "Ancient Relic Fragment", "Minor Healing Draught", "Relic Fragment"]
        } else {
            names = ["Brute Horn", "Rusted Buckle", "Minor Healing Draught", "Iron Ingots"]
        }
        if hero.level >= 3 {
            names.append("Healing Draught")
        }
        if hero.maxStamina > 0 {
            names.append(hero.level >= 3 ? "Stamina Draught" : "Minor Stamina Draught")
        }
        return names.randomElement().flatMap(ItemData.definition(named:))
    }

    private static func consumableDrop(for hero: Hero) -> ItemDefinition? {
        if hero.maxStamina > 0, Int.random(in: 1...100) <= 20 {
            let name: String
            switch hero.level {
            case 1: name = "Minor Stamina Draught"
            case 2...3: name = Int.random(in: 1...100) <= 70 ? "Minor Stamina Draught" : "Stamina Draught"
            default: name = Int.random(in: 1...100) <= 75 ? "Stamina Draught" : "Greater Stamina Draught"
            }
            return ItemData.definition(named: name)
        }
        return ItemData.definition(named: "Minor Healing Draught")
    }

    private static func roll(percent: Int) -> Bool {
        Int.random(in: 1...100) <= percent
    }

    private static func potionChance(for tier: EnemyTier) -> Int {
        switch tier {
        case .minor: return 4
        case .standard: return 8
        case .strong: return 15
        case .boss: return 30
        case .finalBoss: return 45
        }
    }

    private static func materialChance(for tier: EnemyTier) -> Int {
        switch tier {
        case .minor: return 25
        case .standard: return 35
        case .strong: return 55
        case .boss: return 85
        case .finalBoss: return 100
        }
    }

    private static func miscChance(for tier: EnemyTier) -> Int {
        switch tier {
        case .minor: return 40
        case .standard: return 50
        case .strong: return 60
        case .boss: return 75
        case .finalBoss: return 90
        }
    }

    private static func gearChance(for tier: EnemyTier) -> Int {
        switch tier {
        case .minor: return 6
        case .standard: return 12
        case .strong: return 25
        case .boss: return 65
        case .finalBoss: return 100
        }
    }

    private static func materialDrop(for enemy: Enemy) -> ItemDefinition? {
        if enemy.family.contains("Fire-touched") || enemy.family.contains("Forge") {
            let emberMaterials = enemy.tier == .boss || enemy.tier == .finalBoss
                ? ["Emberheart Fragment", "Scorched Ore", "Ember Shard"]
                : ["Ember Shard", "Scorched Ore"]
            return emberMaterials.randomElement().flatMap(ItemData.definition(named:))
        }
        if enemy.family.contains("Undead") {
            let cryptMaterials = enemy.tier == .boss || enemy.tier == .finalBoss
                ? ["Relic Fragment", "Crypt Bell Shard"]
                : ["Bone Splinters", "Relic Fragment"]
            return cryptMaterials.randomElement().flatMap(ItemData.definition(named:))
        }
        let common = ["Stone Shards", "Bone Splinters", "Hide Scraps"]
        let uncommon = ["Iron Ingots", "Ember Dust", "Moonleaf"]
        let rare = ["Bloodstone", "Star Shards", "Oathglass"]

        let pool: [String]
        switch enemy.tier {
        case .minor:
            pool = common
        case .standard:
            pool = common + uncommon
        case .strong, .boss, .finalBoss:
            pool = common + uncommon + rare
        }
        return pool.randomElement().flatMap(ItemData.definition(named:))
    }

    private static func miscDrop(for enemy: Enemy) -> ItemDefinition? {
        let names: [String]
        switch enemy.family {
        case "Vermin":
            names = ["Cracked Fang", "Strange Bone Token", "Clouded Gem Shard"]
        case "Raider":
            names = ["Torn Raider Cloth", "Rusted Buckle", "Old Silver Coin"]
        default:
            names = ["Brute Horn", "Ancient Relic Fragment", "Ember Scale", "Old Silver Coin"]
        }
        return names.randomElement().flatMap(ItemData.definition(named:))
    }

    private static func gearDrop(for tier: EnemyTier, hero: Hero) -> ItemDefinition? {
        let rarity = gearRarity(for: tier)
        let gearPool = ItemData.allItems.filter { item in
            [.weapon, .armour, .charm].contains(item.category)
                && item.rarity == rarity
                && item.rarity != .legendary
                && item.rarity != .mythic
                && isLootEligible(item, hero: hero)
        }

        let subpath = gearPool.filter { ItemData.buildFit(for: $0, hero: hero) == .subpath }
        let path = gearPool.filter { ItemData.buildFit(for: $0, hero: hero) == .path }
        let general = gearPool.filter { ItemData.buildFit(for: $0, hero: hero) == .general }
        let offPath = gearPool.filter { ItemData.buildFit(for: $0, hero: hero) == .offPath }
        let roll = Int.random(in: 1...100)

        if hero.selectedSubpath != nil {
            if roll <= 25 {
                return subpath.randomElement() ?? path.randomElement() ?? general.randomElement()
            }
            if roll <= 85 {
                return path.randomElement() ?? subpath.randomElement() ?? general.randomElement()
            }
            if roll <= 95 {
                return general.randomElement() ?? path.randomElement()
            }
            return offPath.randomElement() ?? general.randomElement() ?? path.randomElement()
        }

        if roll <= 80 {
            return path.randomElement() ?? general.randomElement()
        }
        if roll <= 95 {
            return general.randomElement() ?? path.randomElement()
        }
        return offPath.randomElement() ?? general.randomElement() ?? path.randomElement()
    }

    private static func isLootEligible(_ item: ItemDefinition, hero: Hero) -> Bool {
        guard item.rarity != .legendary, item.rarity != .mythic else { return false }
        if item.rarity == .epic, item.subpathRequirement != nil {
            return hero.level >= 3 && item.subpathRequirement == hero.subpath
        }
        return ItemData.isUsableBy(hero: hero, item: item)
    }

    private static func gearRarity(for tier: EnemyTier) -> Rarity {
        let roll = Int.random(in: 1...100)
        switch tier {
        case .minor:
            if roll <= 85 { return .common }
            if roll <= 98 { return .uncommon }
            return .rare
        case .standard:
            if roll <= 70 { return .common }
            if roll <= 95 { return .uncommon }
            return .rare
        case .strong:
            if roll <= 45 { return .common }
            if roll <= 80 { return .uncommon }
            if roll <= 98 { return .rare }
            return .epic
        case .boss:
            if roll <= 15 { return .common }
            if roll <= 60 { return .uncommon }
            if roll <= 95 { return .rare }
            return .epic
        case .finalBoss:
            if roll <= 20 { return .uncommon }
            if roll <= 80 { return .rare }
            return .epic
        }
    }
}
