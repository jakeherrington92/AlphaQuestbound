import Foundation

@MainActor
final class SaveStore: ObservableObject {
    @Published private(set) var slots: [SaveSlot]
    @Published private(set) var shopState: ShopState
    @Published private(set) var settings: Settings

    let saveVersion = 1
    let gameVersion = "0.1.0"

    private let storageKey = "questbound.localSaveFile.v1"
    private let legacyStorageKey = "questbound.localSaveSlots.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saveFile = try? decoder.decode(QuestboundSaveFile.self, from: data) {
            slots = Self.normalizedSlots(from: saveFile.slots)
            shopState = Self.normalizedShopState(saveFile.shopState)
            settings = saveFile.settings
        } else if let data = UserDefaults.standard.data(forKey: legacyStorageKey) {
            let legacyDecoder = JSONDecoder()
            if let decodedSlots = try? legacyDecoder.decode([SaveSlot].self, from: data) {
                slots = Self.normalizedSlots(from: decodedSlots)
                shopState = Self.normalizedShopState(.greywickDefault)
                settings = .defaults
                persist()
            } else {
                slots = Self.emptySlots()
                shopState = Self.normalizedShopState(.greywickDefault)
                settings = .defaults
            }
        } else {
            slots = Self.emptySlots()
            shopState = Self.normalizedShopState(.greywickDefault)
            settings = .defaults
        }
#if DEBUG
        print("[Questbound] SaveStore loaded: \(slots.compactMap(\.hero).count) hero(s)")
#endif
    }

    func createHero(_ hero: HeroProfile, in slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        var savedHero = hero
        savedHero.lastPlayedAt = Date()
        slots[index].hero = savedHero
        persist()
    }

    func markPlayed(slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
    }

    func updateHero(_ hero: Hero, in slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        var updatedHero = hero
        updatedHero.lastPlayedAt = Date()
        slots[index].hero = updatedHero
        persist()
    }

    func startAdventure(_ adventure: AdventureDefinition, in slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              let hero = slots[index].hero else { return }
        updateHero(AdventureEngine.startAdventure(adventure, hero: hero), in: slotID)
    }

    func saveAdventureProgress(slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              let hero = slots[index].hero else { return }
        updateHero(AdventureEngine.saveAdventure(hero: hero), in: slotID)
    }

    func abandonAdventure(slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              let hero = slots[index].hero else { return }
        updateHero(AdventureEngine.abandonAdventure(hero: hero), in: slotID)
    }

    func developerClearActiveAdventure(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.currentAdventureState = CurrentAdventureState()
        hero.combatState = nil
        hero.currentLocation = "Greywick"
        slots[index].hero = hero
        persist()
        return "Active adventure and pending completion state cleared."
    }

    func developerClearPendingCompletion(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        guard AdventureEngine.hasPendingAdventureCompletion(hero) else {
            return "No pending adventure completion found."
        }
        hero.currentAdventureState = CurrentAdventureState()
        hero.combatState = nil
        hero.currentLocation = "Greywick"
        slots[index].hero = hero
        persist()
        return "Pending completion cleared. No completion rewards were awarded."
    }

    func developerReturnHeroToGreywick(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.currentLocation = "Greywick"
        hero.combatState = nil
        hero.currentAdventureState.currentCombatState = nil
        hero.currentAdventureState.lastSavedAt = Date()
        slots[index].hero = hero
        persist()
        return hero.currentAdventureState.isActive
            ? "Hero returned to Greywick. Active adventure remains available to resume."
            : "Hero returned to Greywick."
    }

    func applyAdventureDefeat(slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              let hero = slots[index].hero else { return }
        updateHero(AdventureEngine.applyDefeat(hero: hero), in: slotID)
    }

    func completeAdventure(_ adventure: AdventureDefinition, slotID: Int) -> AdventureCompletionReward? {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              let hero = slots[index].hero else { return nil }
        let result = AdventureEngine.completeAdventure(hero: hero, adventure: adventure)
        var completedHero = result.0
        completedHero.lastPlayedAt = Date()
        slots[index].hero = completedHero
        shopState.manualRestocksUsed = 0
        shopState.stockItemIDs = Self.generatedStockNames(heroLevel: completedHero.level, restockSeed: 0, hero: completedHero)
        shopState.activeEvent = Self.rolledShopEvent()
        persist()
        return result.1
    }

    func markFinalBossRewardsClaimed(slotID: Int, encounterID: String) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero,
              hero.currentAdventureState.isActive,
              let room = AdventureEngine.currentRoom(for: hero),
              room.id == encounterID,
              AdventureEngine.isFinalBossRoom(room) else { return }
        hero.currentAdventureState.defeatedEnemyIDs.insert(room.id)
        hero.combatState = nil
        hero.currentAdventureState.currentCombatState = nil
        hero.currentAdventureState.adventureLog.append("Final boss rewards claimed. Adventure completion pending.")
        hero.currentAdventureState.lastSavedAt = Date()
        slots[index].hero = hero
        persist()
    }

    func completeFinalBossAdventure(
        slotID: Int,
        encounterID: String? = nil
    ) -> (AdventureDefinition, AdventureCompletionReward)? {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero,
              hero.currentAdventureState.isActive,
              let adventureID = hero.currentAdventureState.adventureID,
              let adventure = AdventureEngine.adventure(id: adventureID),
              let room = AdventureEngine.currentRoom(for: hero),
              AdventureEngine.isFinalBossRoom(room),
              encounterID == nil || encounterID == room.id,
              hero.currentAdventureState.defeatedEnemyIDs.contains(room.id)
                || hero.currentAdventureState.completedRoomIDs.contains(room.id)
                || hero.combatState?.phase == .victory
                || hero.currentAdventureState.currentCombatState?.phase == .victory
        else { return nil }

        hero.currentAdventureState.defeatedEnemyIDs.insert(room.id)
        hero.currentAdventureState.completedRoomIDs.insert(room.id)
        hero.combatState = nil
        hero.currentAdventureState.currentCombatState = nil
        if adventure.id == "the-sunken-crypt" {
            hero = AdventureEngine.applyRoomReward(
                hero: hero,
                rewardID: "crypt-boss-fixed-reward",
                items: ["Crypt Bell Shard": 1]
            )
        } else if adventure.id == "the-ember-cave" {
            hero = AdventureEngine.applyRoomReward(
                hero: hero,
                rewardID: "emberheart-fixed-material",
                items: ["Emberheart Fragment": 1]
            )
        }
        slots[index].hero = hero

        guard let reward = completeAdventure(adventure, slotID: slotID) else { return nil }
        return (adventure, reward)
    }

    func buyItem(_ item: ItemDefinition, for slotID: Int) -> String? {
        buyItem(item, quantity: 1, for: slotID)
    }

    func buyItem(_ item: ItemDefinition, quantity: Int, for slotID: Int) -> String? {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let quantity = max(1, quantity)
        guard item.isStackable || quantity == 1 else { return "Gear can only be bought one at a time." }

        let price = buyPrice(for: item) * quantity
        guard hero.gold >= price else { return "Not enough gold." }

        hero.gold -= price
        hero.inventory.gold = hero.gold
        hero.inventory.itemQuantities[item.name, default: 0] += quantity
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return nil
    }

    func sellItem(_ item: ItemDefinition, quantity: Int, from slotID: Int) -> String? {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        guard item.isSellable, item.category != .questItem else { return "Quest items cannot be sold." }
        let backpackQuantity = ItemData.backpackQuantity(item.name, hero: hero)
        guard backpackQuantity > 0 else { return "This equipped copy is protected. Spare copies appear in Backpack and can be sold." }
        guard quantity <= backpackQuantity else { return "Only \(backpackQuantity) unequipped \(item.name) available to sell." }
        guard let owned = hero.inventory.itemQuantities[item.name], owned >= quantity else { return "Item not available." }

        let sellValue = sellValue(for: item) * quantity
        let remaining = owned - quantity
        if remaining > 0 {
            hero.inventory.itemQuantities[item.name] = remaining
        } else {
            hero.inventory.itemQuantities[item.name] = nil
        }
        hero.gold += sellValue
        hero.inventory.gold = hero.gold
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return nil
    }

    func restockShop(for slotID: Int, heroLevel: Int) -> String? {
        guard shopState.manualRestocksUsed < GameConstants.maxManualRestocks else {
            return "Manual restocks are spent until an adventure is completed."
        }

        let cost = nextRestockCost
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        guard hero.gold >= cost else { return "Not enough gold to restock." }

        hero.gold -= cost
        hero.inventory.gold = hero.gold
        slots[index].hero = hero
        shopState.manualRestocksUsed += 1
        shopState.stockItemIDs = Self.generatedStockNames(heroLevel: heroLevel, restockSeed: shopState.manualRestocksUsed, hero: hero)
        persist()
        return nil
    }

    func refreshShopStock(heroLevel: Int) {
        shopState.stockItemIDs = Self.generatedStockNames(heroLevel: heroLevel, restockSeed: shopState.manualRestocksUsed)
        persist()
    }

    func setShopEvent(_ event: ShopEvent?) {
        shopState.activeEvent = event
        persist()
    }

    func updateSettings(_ updatedSettings: Settings) {
        settings = updatedSettings
        persist()
    }

    func dismissTutorialTip(_ tipID: String) {
        settings.dismissedTutorialTips.insert(tipID)
        persist()
    }

    func resetTutorialTips() {
        settings.dismissedTutorialTips.removeAll()
        persist()
    }

    func deleteAllSaveData() {
        slots = Self.emptySlots()
        shopState = Self.normalizedShopState(.greywickDefault)
        settings = .defaults
        UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        persist()
    }

    func applyDeveloperCode(_ code: String, to slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        switch code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "RICHVALE":
            hero.gold = 999_999
            hero.inventory.gold = hero.gold
        case "MAXVALE":
            hero.xp = max(hero.xp, ProgressionRules.versionOne.xpRequired(for: GameConstants.versionOneLevelCap) ?? 5_500)
        case "SKILLVALE":
            hero.attributes = Attributes(
                might: GameConstants.versionOneAttributeCap,
                agility: GameConstants.versionOneAttributeCap,
                endurance: GameConstants.versionOneAttributeCap,
                mind: GameConstants.versionOneAttributeCap,
                instinct: GameConstants.versionOneAttributeCap,
                presence: GameConstants.versionOneAttributeCap
            )
            hero.maxFocus = LevelUpEngine.maxFocus(for: hero.path, attributes: hero.attributes, level: hero.level)
            hero.focus = hero.maxFocus
            hero.currentFocus = min(hero.currentFocus, hero.maxFocus)
            hero.maxStamina = LevelUpEngine.maxStamina(for: hero.path, level: hero.level)
            hero.currentStamina = min(hero.currentStamina, hero.maxStamina)
        default:
            return "Unknown developer code."
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Developer code \(code.uppercased()) applied."
    }

    func setDeveloperXPForLevel(_ level: Int, slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let targetLevel = min(max(1, level), GameConstants.versionOneLevelCap)
        hero.xp = ProgressionRules.versionOne.xpRequired(for: targetLevel) ?? 0
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return targetLevel > hero.level
            ? "XP set for Level \(targetLevel). Level Up is available from Greywick or Character Sheet."
            : "XP set to the Level \(targetLevel) threshold."
    }

    func forceDeveloperLevel(_ level: Int, slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let targetLevel = min(max(1, level), GameConstants.versionOneLevelCap)
        hero.level = targetLevel
        hero.xp = max(hero.xp, ProgressionRules.versionOne.xpRequired(for: targetLevel) ?? 0)
        hero = Self.rebuiltDeveloperHero(hero, restoreFull: true)
        slots[index].hero = hero
        persist()
        if targetLevel >= 3, hero.selectedSubpath == nil {
            return "Hero force-set to Level \(targetLevel). Choose a Subpath from Greywick or Character Sheet."
        }
        return "Hero force-set to Level \(targetLevel)."
    }

    func addDeveloperXP(_ amount: Int, slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.xp += amount
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return LevelUpEngine.pendingNextLevel(for: hero) == nil
            ? "+\(amount) XP added."
            : "XP added. Level Up is available from Greywick or Character Sheet."
    }

    func selectDeveloperSubpath(_ subpath: Subpath, portrait: Portrait, slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        guard hero.level >= 3 else { return "Subpaths unlock at Level 3." }
        guard hero.selectedSubpath == nil else { return "Subpath is already selected." }
        let validSubpaths = CharacterCreationData.pathDefinition(for: hero.path).subpaths
        guard validSubpaths.contains(where: { $0.id == subpath.id }) else {
            return "That Subpath does not match this hero's Path."
        }
        hero.selectedSubpath = subpath
        hero.subpath = subpath.name
        hero.portrait = portrait
        hero = Self.rebuiltDeveloperHero(hero, restoreFull: false)
        slots[index].hero = hero
        persist()
        return "\(subpath.name) selected. Level-appropriate Subpath abilities unlocked."
    }

    func updateDeveloperAttributes(_ attributes: Attributes, slotID: Int, restoreFull: Bool) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.attributes = attributes
        hero = Self.rebuiltDeveloperHero(hero, restoreFull: restoreFull)
        slots[index].hero = hero
        persist()
        return "Attributes updated."
    }

    func developerFullRestore(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.currentHealth = hero.maxHealth
        hero.currentFocus = hero.maxFocus
        hero.currentStamina = hero.maxStamina
        if var combatState = hero.combatState {
            combatState.activeConditions = []
            hero.combatState = combatState
        }
        hero.currentAdventureState.activeConditions = []
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Full restore applied."
    }

    func developerUnlockEmberCave(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        hero.currentAdventureState.completedAdventureIDs.insert("the-sunken-crypt")
        slots[index].hero = hero
        persist()
        return "Ember Cave unlocked. The Sunken Crypt is marked complete for this test hero."
    }

    func giveEmberCaveTestSupplies(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let supplies = ["Healing Draught", "Fire Oil", "Antivenom"]
        for name in supplies where ItemData.definition(named: name) != nil {
            hero.inventory.itemQuantities[name, default: 0] += 2
        }
        let resource = hero.maxStamina > 0 ? "Stamina Draught" : "Focus Tonic"
        if ItemData.definition(named: resource) != nil {
            hero.inventory.itemQuantities[resource, default: 0] += 2
        }
        slots[index].hero = hero
        persist()
        return "Ember Cave test supplies added."
    }

    func giveDeveloperGearTestSet(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let names = Self.fullEquipmentSlotTestSetNames(for: hero)
        for name in names where ItemData.definition(named: name) != nil {
            hero.inventory.itemQuantities[name, default: 0] += name == "Copper Ring" ? 2 : 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Full equipment slot test set added to Backpack."
    }

    func giveAllVersionOneGear(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let names = Self.versionOneGearNames()
        for name in names {
            hero.inventory.itemQuantities[name, default: 0] += 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Added \(names.count) Version 1 gear item(s) to Backpack."
    }

    func giveAllGearForMyPath(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let names = Self.pathGearNames(for: hero)
        for name in names {
            hero.inventory.itemQuantities[name, default: 0] += 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Added \(names.count) path-recommended gear item(s) to Backpack."
    }

    func giveAllGearForMySubpath(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        guard hero.selectedSubpath != nil else { return "Choose a Subpath first." }
        let names = Self.versionOneGearNames()
            .compactMap(ItemData.definition(named:))
            .filter { ItemData.isSubpathSpecialityFor(hero: hero, item: $0) }
            .map(\.name)
            .sorted()
        for name in names {
            hero.inventory.itemQuantities[name, default: 0] += 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Added \(names.count) item(s) for \(hero.subpath ?? "current Subpath") to Backpack."
    }

    func giveAllEpicSubpathWeapons(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        let names = ItemData.allItems
            .filter { $0.category == .weapon && $0.rarity == .epic && $0.subpathRequirement != nil }
            .map(\.name)
            .sorted()
        for name in names {
            hero.inventory.itemQuantities[name, default: 0] += 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return "Added all \(names.count) Epic Subpath weapons to Backpack."
    }

    func giveRecommendedShopStock(slotID: Int) -> String {
        guard let hero = slots.first(where: { $0.id == slotID })?.hero else { return "No hero found." }
        let items = ItemData.allItems
            .filter { item in
                item.isSellable
                    && item.category != .questItem
                    && item.category != .miscellaneous
                    && item.rarity != .legendary
                    && item.rarity != .mythic
                    && (item.levelRequirement ?? 1) <= hero.level
                    && ItemData.isRecommendedFor(hero: hero, item: item)
                    && (item.subpathRequirement == nil || item.subpathRequirement == hero.subpath)
            }
            .sorted {
                let lhs = ItemData.pathMatchScore(hero: hero, item: $0)
                let rhs = ItemData.pathMatchScore(hero: hero, item: $1)
                return lhs == rhs ? $0.value < $1.value : lhs > rhs
            }
        shopState.stockItemIDs = Array(items.prefix(20)).map(\.name)
        persist()
        return "Recommended shop stock generated for \(hero.name)."
    }

    func equipDeveloperEmptySlots(slotID: Int) -> String {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return "No hero found." }
        var equippedCount = 0
        for slot in ItemData.equipmentSlots where hero.equippedItems.slots[slot] == nil {
            let candidates = hero.inventory.itemQuantities.keys
                .compactMap(ItemData.definition(named:))
                .filter { item in
                    ItemData.backpackQuantity(item.name, hero: hero) > 0
                        && ItemData.isCompatible(item, with: slot, hero: hero)
                }
                .sorted { lhs, rhs in
                    let lhsScore = Self.developerGearScore(lhs, hero: hero)
                    let rhsScore = Self.developerGearScore(rhs, hero: hero)
                    if lhsScore != rhsScore { return lhsScore > rhsScore }
                    return lhs.value > rhs.value
                }
            guard let item = candidates.first else { continue }
            hero = ItemData.equippedHero(hero, with: item, in: slot)
            equippedCount += 1
        }
        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return equippedCount == 0 ? "No empty compatible slots found." : "Equipped \(equippedCount) empty slot(s)."
    }

    var restocksRemaining: Int {
        max(0, GameConstants.maxManualRestocks - shopState.manualRestocksUsed)
    }

    var nextRestockCost: Int {
        guard shopState.manualRestocksUsed < GameConstants.manualRestockCosts.count else { return 0 }
        return GameConstants.manualRestockCosts[shopState.manualRestocksUsed]
    }

    func buyPrice(for item: ItemDefinition) -> Int {
        guard let discount = shopState.activeEvent?.discountPercent else { return item.value }
        return max(1, item.value * (100 - discount) / 100)
    }

    func sellValue(for item: ItemDefinition) -> Int {
        guard item.isSellable, item.category != .questItem else { return 0 }
        switch item.category {
        case .weapon, .armour, .charm:
            let percent = max(GameConstants.baseGearSellPercent, shopState.activeEvent?.sellPercentOverride ?? 0)
            return item.value * percent / 100
        case .consumable:
            return item.value * GameConstants.baseGearSellPercent / 100
        case .material, .miscellaneous:
            return item.value
        case .questItem:
            return 0
        }
    }

    func longRest(slotID: Int) -> Bool {
        guard let index = slots.firstIndex(where: { $0.id == slotID }),
              var hero = slots[index].hero else { return false }

        let wasFullyRested = hero.currentHealth >= hero.maxHealth
            && hero.currentFocus >= hero.maxFocus
            && hero.currentStamina >= hero.maxStamina
        hero.currentHealth = hero.maxHealth
        hero.currentFocus = hero.maxFocus
        hero.currentStamina = hero.maxStamina

        if var combatState = hero.combatState {
            combatState.activeConditions = []
            hero.combatState = combatState
        }

        hero.lastPlayedAt = Date()
        slots[index].hero = hero
        persist()
        return wasFullyRested
    }

    func clearSlot(_ slotID: Int) {
        guard let index = slots.firstIndex(where: { $0.id == slotID }) else { return }
        slots[index].hero = nil
        persist()
    }

    var mostRecentlyPlayedSlot: SaveSlot? {
        slots
            .filter { $0.hero != nil }
            .max { lhs, rhs in
                (lhs.hero?.lastPlayedAt ?? .distantPast) < (rhs.hero?.lastPlayedAt ?? .distantPast)
            }
    }

    var firstEmptySlotID: Int? {
        slots.first(where: { $0.hero == nil })?.id
    }

    private func persist() {
        let saveFile = QuestboundSaveFile(
            saveVersion: saveVersion,
            gameVersion: gameVersion,
            slots: slots,
            settings: settings,
            shopState: shopState
        )
        guard let data = try? encoder.encode(saveFile) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func rebuiltDeveloperHero(_ hero: Hero, restoreFull: Bool) -> Hero {
        var updated = hero
        updated.maxHealth = recalculatedMaxHealth(for: updated)
        updated.maxFocus = LevelUpEngine.maxFocus(for: updated.path, attributes: updated.attributes, level: updated.level)
        updated.focus = updated.maxFocus
        updated.maxStamina = LevelUpEngine.maxStamina(for: updated.path, level: updated.level)
        if restoreFull {
            updated.currentHealth = updated.maxHealth
            updated.currentFocus = updated.maxFocus
            updated.currentStamina = updated.maxStamina
        } else {
            updated.currentHealth = min(updated.currentHealth, updated.maxHealth)
            updated.currentFocus = min(updated.currentFocus, updated.maxFocus)
            updated.currentStamina = min(updated.currentStamina, updated.maxStamina)
        }
        updated.abilities = rebuiltAbilities(for: updated)
        updated.lastPlayedAt = Date()
        return updated
    }

    private static func recalculatedMaxHealth(for hero: Hero) -> Int {
        guard let pathDefinition = CharacterCreationData.paths.first(where: { $0.path == hero.path }) else {
            return hero.maxHealth
        }
        let enduranceModifier = hero.attributes.modifier(for: .endurance)
        let startingHP = max(1, pathDefinition.startingHPBase + enduranceModifier)
        guard hero.level > 1 else { return startingHP }
        let perLevel = max(1, pathDefinition.hpPerLevelBase + enduranceModifier)
        return startingHP + perLevel * (hero.level - 1)
    }

    private static func rebuiltAbilities(for hero: Hero) -> [Ability] {
        var abilities = CharacterCreationData.paths.first(where: { $0.path == hero.path })?.startingAbilities ?? []
        guard hero.level >= 2 else { return abilities }
        for level in 2...hero.level {
            for ability in LevelUpEngine.abilitiesUnlocked(path: hero.path, subpathID: hero.selectedSubpath?.id, level: level) where !abilities.contains(where: { $0.id == ability.id }) {
                abilities.append(ability)
            }
        }
        return abilities
    }

    private static func versionOneGearNames() -> [String] {
        let activeRarities: Set<Rarity> = [.common, .uncommon, .rare, .epic]
        return ItemData.allItems
            .filter { [.weapon, .armour, .charm].contains($0.category) && activeRarities.contains($0.rarity) }
            .map(\.name)
            .sorted()
    }

    private static func pathGearNames(for hero: Hero) -> [String] {
        versionOneGearNames()
            .compactMap(ItemData.definition(named:))
            .filter { item in
                let fit = ItemData.buildFit(for: item, hero: hero)
                return fit == .path || fit == .subpath
            }
            .map(\.name)
            .sorted()
    }

    private static func fullEquipmentSlotTestSetNames(for hero: Hero) -> [String] {
        let mainWeapon: String
        let chest: String
        switch hero.path {
        case .bladeguard:
            mainWeapon = "Balanced Sword"
            chest = "Guard Chain"
        case .shadowstep:
            mainWeapon = "Silent Fang"
            chest = "Reinforced Leather"
        case .wildwarden:
            mainWeapon = "Hunter's Bow"
            chest = "Reinforced Leather"
        case .embermage:
            mainWeapon = "Focus Staff"
            chest = "Focus Robe"
        case .oathkeeper:
            mainWeapon = "Oathbound Blade"
            chest = "Guard Chain"
        }

        return [
            mainWeapon,
            "Wooden Shield",
            "Watcher's Hood",
            chest,
            "Gripwrap Gloves",
            "Stonewalker Greaves",
            "Runner's Boots",
            "Copper Ring",
            "Minor Focus Charm"
        ]
    }

    private static func developerGearScore(_ item: ItemDefinition, hero: Hero) -> Int {
        let rarityScore: Int
        switch item.rarity {
        case .epic: rarityScore = 400
        case .rare: rarityScore = 300
        case .uncommon: rarityScore = 200
        case .common: rarityScore = 100
        case .legendary, .mythic: rarityScore = 0
        }
        return rarityScore + max(ItemData.pathAffinityScore(for: item, hero: hero), 0) * 10 + item.defenceBonus
    }

    private static func emptySlots() -> [SaveSlot] {
        (1...GameConstants.maxHeroSlots).map { SaveSlot(id: $0, hero: nil) }
    }

    private static func normalizedSlots(from savedSlots: [SaveSlot]) -> [SaveSlot] {
        (1...GameConstants.maxHeroSlots).map { slotID in
            var slot = savedSlots.first(where: { $0.id == slotID }) ?? SaveSlot(id: slotID, hero: nil)
            if var hero = slot.hero, hero.level >= 2 {
                if hero.selectedSubpath?.id == "starweaver" {
                    hero.subpath = "Voidweaver"
                    hero.selectedSubpath?.name = "Voidweaver"
                    hero.selectedSubpath?.summary = "Void and arcane disruption, strange wards and hostile-magic control."
                }
                let expectedStamina = LevelUpEngine.maxStamina(for: hero.path, level: hero.level)
                if hero.maxStamina != expectedStamina {
                    let wasMissingStamina = hero.maxStamina == 0 && expectedStamina > 0
                    hero.maxStamina = expectedStamina
                    hero.currentStamina = wasMissingStamina
                        ? expectedStamina
                        : min(hero.currentStamina, expectedStamina)
                }
                if hero.level >= 5 {
                    let capstoneIDs: Set<String> = [
                        "bastion-sweep", "whirlwind-cut", "shadow-chain", "scatterknives", "pack-assault",
                        "piercing-volley", "cinder-burst", "astral-cascade", "dawnwave", "radiant-judgement"
                    ]
                    hero.abilities.removeAll { capstoneIDs.contains($0.id) }
                }
                if hero.selectedSubpath?.id == "flamecaller" {
                    // Refresh the saved definition from the former attack version to the Quick setup version.
                    hero.abilities.removeAll { $0.id == "cinder-mark" }
                }
                // Retire Duelist's Tempo and refresh player-facing Voidweaver ability names.
                hero.abilities.removeAll {
                    $0.id == "duelists-tempo"
                        || (hero.selectedSubpath?.id == "starweaver"
                            && ["starlit-ward", "arcane-ward", "starfall-pulse"].contains($0.id))
                }
                let resourceUpdatedAbilityIDs: Set<String> = [
                    "relentless-assault", "shadow-flurry", "veil-strike",
                    "packwarden-strike", "hunters-volley", "sure-shot"
                ]
                hero.abilities.removeAll { resourceUpdatedAbilityIDs.contains($0.id) }
                for level in 2...hero.level {
                    let unlocked = LevelUpEngine.abilitiesUnlocked(
                        path: hero.path,
                        subpathID: hero.selectedSubpath?.id,
                        level: level
                    )
                    for ability in unlocked where !hero.abilities.contains(where: { $0.id == ability.id }) {
                        hero.abilities.append(ability)
                    }
                }
                slot.hero = hero
            }
            return slot
        }
    }

    private static func normalizedShopState(_ savedState: ShopState) -> ShopState {
        var state = savedState
        if state.stockItemIDs.isEmpty {
            state.stockItemIDs = generatedStockNames(heroLevel: 1, restockSeed: state.manualRestocksUsed)
        }
        return state
    }

    private static func generatedStockNames(heroLevel: Int, restockSeed: Int, hero: Hero? = nil) -> [String] {
        var stock: [String] = []
        let guaranteedBasics = ["Minor Healing Draught", "Antivenom", "Iron Sword", "Leather Vest", "Wooden Shield"]
        stock.append(contentsOf: guaranteedBasics.filter { ItemData.definition(named: $0) != nil })
        appendHealingStock(heroLevel: heroLevel, to: &stock)
        appendStaminaStock(heroLevel: heroLevel, hero: hero, to: &stock)

        let desiredCount = 16
        var attempts = 0
        while stock.count < desiredCount, attempts < desiredCount * 12 {
            attempts += 1
            let rarity = shopRarity(heroLevel: heroLevel)
            let pool = ItemData.allItems.filter { item in
                item.isSellable
                    && item.category != .questItem
                    && item.category != .miscellaneous
                    && item.rarity == rarity
                    && item.levelRequirement ?? 1 <= min(heroLevel, GameConstants.versionOneLevelCap)
                    && (item.subpathRequirement == nil || item.subpathRequirement == hero?.subpath)
                    && (!ItemData.staminaDraughtNames.contains(item.name) || hero?.maxStamina ?? 0 > 0)
            }
            if let item = pool.randomElement(), !stock.contains(item.name) {
                stock.append(item.name)
            }
        }

        let fallback = ItemData.allItems
            .filter {
                $0.isSellable
                    && $0.category != .questItem
                    && $0.category != .miscellaneous
                    && $0.rarity != .legendary
                    && $0.rarity != .mythic
                    && ($0.subpathRequirement == nil || $0.subpathRequirement == hero?.subpath)
                    && (!ItemData.staminaDraughtNames.contains($0.name) || hero?.maxStamina ?? 0 > 0)
            }
            .map(\.name)
        for item in fallback where stock.count < desiredCount && !stock.contains(item) {
            stock.append(item)
        }

        guard !stock.isEmpty else { return ItemData.startingItems.map(\.name) }
        let splitIndex = stock.isEmpty ? 0 : restockSeed % stock.count
        return Array(stock[splitIndex...]) + Array(stock[..<splitIndex])
    }

    private static func appendHealingStock(heroLevel: Int, to stock: inout [String]) {
        let level = min(max(heroLevel, 1), GameConstants.versionOneLevelCap)
        let chances: [(name: String, chance: Int)]
        switch level {
        case 1:
            chances = [("Healing Draught", 15)]
        case 2:
            chances = [("Healing Draught", 65), ("Greater Healing Draught", 10)]
        case 3:
            chances = [("Healing Draught", 75), ("Greater Healing Draught", 30)]
        case 4:
            chances = [("Healing Draught", 70), ("Greater Healing Draught", 45), ("Hero's Healing Draught", 10)]
        default:
            chances = [("Healing Draught", 65), ("Greater Healing Draught", 50), ("Hero's Healing Draught", 15)]
        }

        for entry in chances
        where Int.random(in: 1...100) <= entry.chance
            && ItemData.definition(named: entry.name) != nil
            && !stock.contains(entry.name) {
            stock.append(entry.name)
        }
    }

    private static func appendStaminaStock(heroLevel: Int, hero: Hero?, to stock: inout [String]) {
        guard hero?.maxStamina ?? 0 > 0 else { return }
        let level = min(max(heroLevel, 1), GameConstants.versionOneLevelCap)
        let chances: [(name: String, chance: Int)]
        switch level {
        case 1:
            chances = [("Minor Stamina Draught", 65)]
        case 2:
            chances = [("Minor Stamina Draught", 55), ("Stamina Draught", 40)]
        case 3:
            chances = [("Stamina Draught", 55), ("Greater Stamina Draught", 20)]
        case 4:
            chances = [("Stamina Draught", 45), ("Greater Stamina Draught", 35)]
        default:
            chances = [("Greater Stamina Draught", 45), ("Hero's Stamina Draught", 12)]
        }

        for entry in chances
        where Int.random(in: 1...100) <= entry.chance
            && ItemData.definition(named: entry.name) != nil
            && !stock.contains(entry.name) {
            stock.append(entry.name)
        }
    }

    private static func shopRarity(heroLevel: Int) -> Rarity {
        let roll = Int.random(in: 1...100)
        switch heroLevel {
        case 1:
            return roll <= 90 ? .common : .uncommon
        case 2:
            return roll <= 65 ? .common : .uncommon
        case 3:
            if roll <= 30 { return .common }
            if roll <= 85 { return .uncommon }
            return .rare
        case 4:
            if roll <= 15 { return .common }
            if roll <= 60 { return .uncommon }
            if roll <= 98 { return .rare }
            return .epic
        default:
            if roll <= 5 { return .common }
            if roll <= 30 { return .uncommon }
            if roll <= 90 { return .rare }
            return .epic
        }
    }

    private static func rolledShopEvent() -> ShopEvent? {
        let roll = Int.random(in: 1...100)
        if roll <= 75 {
            return nil
        }
        if roll <= 90 {
            return [ShopEvent.sale25, .sale35, .sale50].randomElement()
        }
        return .merchantDemand
    }
}
