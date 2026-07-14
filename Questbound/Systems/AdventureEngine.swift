import Foundation

enum AdventureRoomType: String, CaseIterable, Codable, Hashable, Identifiable {
    case story
    case skillCheck
    case trap
    case combat
    case treasure
    case choice
    case rest
    case boss
    case exit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .story: return "Story Room"
        case .skillCheck: return "Skill Check Room"
        case .trap: return "Trap Room"
        case .combat: return "Combat Room"
        case .treasure: return "Treasure Room"
        case .choice: return "Choice Room"
        case .rest: return "Rest Room"
        case .boss: return "Boss Room"
        case .exit: return "Exit Room"
        }
    }
}

struct AdventureDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let recommendedLevel: Int
    let difficulty: String
    let theme: String
    let hook: String
    let rewardPreview: String
    let unlockSummary: String
    let rooms: [AdventureRoomDefinition]
}

struct AdventureRoomDefinition: Identifiable, Hashable {
    let id: String
    let title: String
    let type: AdventureRoomType
    let description: String
    let choices: [AdventureChoiceDefinition]
    let skillChecks: [AdventureSkillCheckDefinition]
    let enemyIDs: [String]
    let treasurePreview: String?
    let nextRoomID: String?
}

struct AdventureChoiceDefinition: Identifiable, Hashable {
    let id: String
    let text: String
    let nextRoomID: String
}

struct AdventureSkillCheckDefinition: Identifiable, Hashable {
    let id: String
    let skill: SkillType
    let difficulty: SkillDifficulty
    let successText: String
    let failureText: String
    let successNextRoomID: String
    let failureNextRoomID: String
}

struct AdventureCompletionReward: Equatable {
    let xp: Int
    let gold: Int
    let items: [RewardLineItem]
    let isFirstCompletion: Bool
}

enum AdventureEngine {
    static let plannedAdventures: [AdventureDefinition] = [
        AdventureDefinition(
            id: "the-hollow-mine",
            title: "The Hollow Mine",
            recommendedLevel: 1,
            difficulty: "Beginner",
            theme: "Raiders, rats and broken mine tunnels",
            hook: "Greywick's old mine road has gone quiet, and smoke curls from the lower shaft.",
            rewardPreview: "XP, gold, gear, materials",
            unlockSummary: "Available from start",
            rooms: hollowMineRooms
        ),
        AdventureDefinition(
            id: "the-sunken-crypt",
            title: "The Sunken Crypt",
            recommendedLevel: 2,
            difficulty: "Novice to Intermediate",
            theme: "Undead, flooding and ancient burial halls",
            hook: "An ancient burial crypt has risen from the marsh. Blue lights flicker below the flooded steps, and something beneath the water rings an old funeral bell.",
            rewardPreview: "Gold, path-aware gear, relic fragments, rare chance",
            unlockSummary: "Complete The Hollow Mine",
            rooms: sunkenCryptRooms
        ),
        AdventureDefinition(
            id: "the-ember-cave",
            title: "Ember Cave",
            recommendedLevel: 3,
            difficulty: "Moderate to Challenging",
            theme: "Fire-touched beasts, volcanic hazards and an ancient forge",
            hook: "Smoke rises from a cracked cave beyond the marsh road. Inside, old forge-stones glow red, and something beneath the mountain stirs the embers.",
            rewardPreview: "Path-aware weapon, armour, ember materials, gold, rare chance",
            unlockSummary: "Complete The Sunken Crypt",
            rooms: emberCaveRooms
        ),
        AdventureDefinition(
            id: "the-thornwood-hunt",
            title: "The Thornwood Hunt",
            recommendedLevel: 4,
            difficulty: "Challenging",
            theme: "Forest beasts and briar magic",
            hook: "Hunters return with thorn-scratched armour and stories of moving trees.",
            rewardPreview: "XP, gold, rare gear, epic chance",
            unlockSummary: "Reach Level 4",
            rooms: []
        ),
        AdventureDefinition(
            id: "the-watchtower-below",
            title: "The Watchtower Below",
            recommendedLevel: 5,
            difficulty: "Dangerous",
            theme: "Constructs, undead and old relic power",
            hook: "An impossible stair has been found beneath a collapsed watchtower.",
            rewardPreview: "XP, gold, epic chance, final threat",
            unlockSummary: "Reach Level 5",
            rooms: []
        )
    ]

    static func adventure(id: String) -> AdventureDefinition? {
        plannedAdventures.first { $0.id == id }
    }

    static func currentRoom(for hero: Hero) -> AdventureRoomDefinition? {
        guard let adventureID = hero.currentAdventureState.adventureID,
              let adventure = adventure(id: adventureID) else { return nil }
        if let roomID = hero.currentAdventureState.currentRoomID,
           let room = adventure.rooms.first(where: { $0.id == roomID }) {
            return room
        }
        return adventure.rooms.first
    }

    static func isFinalBossRoom(_ room: AdventureRoomDefinition) -> Bool {
        room.type == .boss && room.nextRoomID == nil
    }

    static func hasPendingAdventureCompletion(_ hero: Hero) -> Bool {
        guard hero.currentAdventureState.isActive,
              let room = currentRoom(for: hero),
              isFinalBossRoom(room) else { return false }
        if hero.currentAdventureState.defeatedEnemyIDs.contains(room.id)
            || hero.currentAdventureState.completedRoomIDs.contains(room.id) {
            return true
        }
        return hero.combatState?.encounterID == room.id && hero.combatState?.phase == .victory
            || hero.currentAdventureState.currentCombatState?.encounterID == room.id
                && hero.currentAdventureState.currentCombatState?.phase == .victory
    }

    static func isUnlocked(_ adventure: AdventureDefinition, hero: Hero) -> Bool {
        switch adventure.id {
        case "the-hollow-mine":
            return true
        case "the-sunken-crypt":
            return hero.currentAdventureState.completedAdventureIDs.contains("the-hollow-mine")
        case "the-ember-cave":
            return hero.currentAdventureState.completedAdventureIDs.contains("the-sunken-crypt")
        case "the-thornwood-hunt":
            return hero.level >= 4
        case "the-watchtower-below":
            return hero.level >= 5
        default:
            return false
        }
    }

    static func startAdventure(_ adventure: AdventureDefinition, hero: Hero) -> Hero {
        var updated = hero
        let firstRoom = adventure.rooms.first
        let now = Date()
        updated.currentLocation = adventure.title
        updated.currentAdventureState = CurrentAdventureState(
            adventureID: adventure.id,
            currentRoomID: firstRoom?.id,
            currentRoomIndex: 0,
            visitedRoomIDs: Set(firstRoom.map { [$0.id] } ?? []),
            completedAdventureIDs: hero.currentAdventureState.completedAdventureIDs,
            adventureLog: ["Started \(adventure.title).", firstRoom.map { "Entered \($0.title)." }].compactMap { $0 },
            startedAt: now,
            lastSavedAt: now
        )
        return updated
    }

    static func markRoomComplete(hero: Hero, roomID: String, nextRoomID: String?) -> Hero {
        var updated = hero
        var state = updated.currentAdventureState
        state.completedRoomIDs.insert(roomID)
        if let nextRoomID {
            state.currentRoomID = nextRoomID
            state.visitedRoomIDs.insert(nextRoomID)
            if let adventureID = state.adventureID,
               let adventure = adventure(id: adventureID),
               let index = adventure.rooms.firstIndex(where: { $0.id == nextRoomID }) {
                state.currentRoomIndex = index
                state.adventureLog.append("Entered \(adventure.rooms[index].title).")
            }
        }
        state.adventureLog.append("Completed \(roomID).")
        state.lastSavedAt = Date()
        updated.currentAdventureState = state
        return updated
    }

    static func shortRest(hero: Hero) -> Hero {
        var updated = hero
        guard !updated.currentAdventureState.shortRestUsed else { return updated }
        updated.currentHealth = min(updated.maxHealth, updated.currentHealth + updated.maxHealth / 2)
        if updated.maxFocus > 0 {
            updated.currentFocus = min(updated.maxFocus, updated.currentFocus + updated.maxFocus / 2)
        }
        if updated.maxStamina > 0 {
            updated.currentStamina = min(updated.maxStamina, updated.currentStamina + updated.maxStamina / 2)
        }
        updated.currentAdventureState.shortRestUsed = true
        updated.currentAdventureState.lastSavedAt = Date()
        return updated
    }

    static func appendLog(hero: Hero, _ entry: String) -> Hero {
        var updated = hero
        updated.currentAdventureState.adventureLog.append(entry)
        updated.currentAdventureState.lastSavedAt = Date()
        return updated
    }

    static func saveAdventure(hero: Hero) -> Hero {
        var updated = hero
        updated.currentAdventureState.lastSavedAt = Date()
        return updated
    }

    static func abandonAdventure(hero: Hero) -> Hero {
        var updated = hero
        let completed = updated.currentAdventureState.completedAdventureIDs
        updated.currentAdventureState = CurrentAdventureState(completedAdventureIDs: completed)
        updated.currentLocation = "Greywick"
        updated.combatState = nil
        return updated
    }

    static func applyDefeat(hero: Hero) -> Hero {
        var updated = abandonAdventure(hero: hero)
        let lostGold = updated.gold / 5
        updated.gold -= lostGold
        updated.inventory.gold = updated.gold
        updated.currentHealth = 1
        return updated
    }

    static func completeAdventure(hero: Hero, adventure: AdventureDefinition) -> (Hero, AdventureCompletionReward) {
        var updated = hero
        let wasCompleted = updated.currentAdventureState.completedAdventureIDs.contains(adventure.id)
        let items: [RewardLineItem]
        if adventure.id == "the-hollow-mine" {
            if wasCompleted {
                items = [
                    rewardItem("Stone Shards", quantity: 2),
                    rewardItem("Bone Splinters", quantity: 2)
                ].compactMap { $0 }
            } else {
                let gear = LootEngine.pathMatchedGear(for: hero, rarity: .uncommon)
                    ?? LootEngine.pathMatchedGear(for: hero)
                items = [
                    rewardItem("Minor Healing Draught", quantity: 1),
                    gear.flatMap { rewardItem($0.name, quantity: 1) }
                ].compactMap { $0 }
            }
        } else if adventure.id == "the-sunken-crypt" {
            let gearRarity: Rarity = hero.level >= 3 ? .rare : .uncommon
            let gear = LootEngine.pathMatchedGear(for: hero, rarity: gearRarity)
                ?? LootEngine.pathMatchedGear(for: hero, rarity: .uncommon)
            if wasCompleted {
                items = [
                    rewardItem("Relic Fragment", quantity: 1),
                    rewardItem("Crypt Bell Shard", quantity: 1)
                ].compactMap { $0 }
            } else {
                items = [
                    rewardItem("Relic Fragment", quantity: 2),
                    rewardItem("Crypt Bell Shard", quantity: 1),
                    gear.flatMap { rewardItem($0.name, quantity: 1) }
                ].compactMap { $0 }
            }
        } else if adventure.id == "the-ember-cave" {
            let gear = LootEngine.pathMatchedGear(for: hero, rarity: .rare)
                ?? LootEngine.pathMatchedGear(for: hero, rarity: .uncommon)
            if wasCompleted {
                items = [
                    rewardItem("Ember Shard", quantity: 2),
                    rewardItem("Scorched Ore", quantity: 1)
                ].compactMap { $0 }
            } else {
                items = [
                    rewardItem("Ember Shard", quantity: 3),
                    rewardItem("Scorched Ore", quantity: 1),
                    gear.flatMap { rewardItem($0.name, quantity: 1) }
                ].compactMap { $0 }
            }
        } else {
            items = []
        }
        let baseXP: Int
        let baseGold: Int
        switch adventure.id {
        case "the-sunken-crypt":
            baseXP = 250
            baseGold = 80
        case "the-ember-cave":
            baseXP = 400
            baseGold = 120
        default:
            baseXP = 150
            baseGold = 50
        }
        let reward = AdventureCompletionReward(
            xp: wasCompleted ? baseXP / 2 : baseXP,
            gold: wasCompleted ? baseGold / 2 : baseGold,
            items: items,
            isFirstCompletion: !wasCompleted
        )
        updated.xp += reward.xp
        updated.gold += reward.gold
        updated.inventory.gold = updated.gold
        for item in reward.items {
            updated.inventory.itemQuantities[item.itemName, default: 0] += item.quantity
        }
        updated.currentHealth = updated.maxHealth
        updated.currentFocus = updated.maxFocus
        updated.currentStamina = updated.maxStamina
        var completed = updated.currentAdventureState.completedAdventureIDs
        completed.insert(adventure.id)
        updated.currentAdventureState = CurrentAdventureState(completedAdventureIDs: completed)
        updated.currentLocation = "Greywick"
        updated.combatState = nil
        return (updated, reward)
    }

    static func applyRoomReward(hero: Hero, rewardID: String, gold: Int = 0, items: [String: Int] = [:]) -> Hero {
        guard !hero.currentAdventureState.collectedRewardIDs.contains(rewardID) else { return hero }
        var updated = hero
        updated.gold += gold
        updated.inventory.gold = updated.gold
        for (itemName, quantity) in items {
            updated.inventory.itemQuantities[itemName, default: 0] += quantity
        }
        updated.currentAdventureState.collectedRewardIDs.insert(rewardID)
        updated.currentAdventureState.lastSavedAt = Date()
        return updated
    }

    private static func rewardItem(_ itemName: String, quantity: Int) -> RewardLineItem? {
        guard let definition = ItemData.definition(named: itemName) else { return nil }
        return RewardLineItem(
            itemName: itemName,
            quantity: quantity,
            category: definition.category,
            rarity: definition.rarity
        )
    }

    private static let hollowMineRooms: [AdventureRoomDefinition] = [
        AdventureRoomDefinition(
            id: "mine-entrance",
            title: "Mine Entrance",
            type: .choice,
            description: "The old ridge tunnel yawns open beneath a sagging timber frame. Cold air leaks from below, carrying the smell of damp stone and old smoke. Scratches mark the ground near the entrance, and a broken lantern lies half-buried in mud.",
            choices: [
                AdventureChoiceDefinition(id: "march-in", text: "March straight in", nextRoomID: "broken-cart")
            ],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "search-tracks-awareness", skill: .awareness, difficulty: .standard, successText: "You learn that raiders entered the mine and something heavy was dragged inside.", failureText: "You learn only that the mine has seen recent movement.", successNextRoomID: "broken-cart", failureNextRoomID: "broken-cart"),
                AdventureSkillCheckDefinition(id: "search-tracks-survival", skill: .survival, difficulty: .standard, successText: "You learn that raiders entered the mine and something heavy was dragged inside.", failureText: "You learn only that the mine has seen recent movement.", successNextRoomID: "broken-cart", failureNextRoomID: "broken-cart"),
                AdventureSkillCheckDefinition(id: "enter-quietly", skill: .stealth, difficulty: .standard, successText: "You enter quietly and prepare for the first fight.", failureText: "Loose stone skitters into the dark.", successNextRoomID: "broken-cart", failureNextRoomID: "broken-cart")
            ],
            enemyIDs: [],
            treasurePreview: nil,
            nextRoomID: "broken-cart"
        ),
        AdventureRoomDefinition(
            id: "broken-cart",
            title: "Broken Cart",
            type: .skillCheck,
            description: "A shattered ore cart blocks part of the tunnel. Splintered wood, rusted tools and spilled stone cover the ground. A small lockbox sits beneath the cart's broken axle.",
            choices: [
                AdventureChoiceDefinition(id: "leave-cart", text: "Leave it", nextRoomID: "rat-nest")
            ],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "search-wreckage", skill: .awareness, difficulty: .standard, successText: "You find useful supplies under the broken boards.", failureText: "You find only a few coins in the mud.", successNextRoomID: "rat-nest", failureNextRoomID: "rat-nest"),
                AdventureSkillCheckDefinition(id: "open-lockbox", skill: .thievery, difficulty: .standard, successText: "The lock clicks open.", failureText: "A rusted spike snaps out from the cart frame.", successNextRoomID: "rat-nest", failureNextRoomID: "rat-nest"),
                AdventureSkillCheckDefinition(id: "smash-lockbox", skill: .athletics, difficulty: .standard, successText: "The lockbox breaks open.", failureText: "The box cracks, but most of its contents scatter into the stones.", successNextRoomID: "rat-nest", failureNextRoomID: "rat-nest")
            ],
            enemyIDs: [],
            treasurePreview: "Small treasure, gold, or a trap.",
            nextRoomID: "rat-nest"
        ),
        AdventureRoomDefinition(
            id: "rat-nest",
            title: "Rat Nest",
            type: .combat,
            description: "The tunnel bends into a low chamber filled with torn sacks and gnawed bones. Red eyes glint from cracks in the stone.",
            choices: [],
            skillChecks: [],
            enemyIDs: ["cave-rat", "cave-rat"],
            treasurePreview: "After combat, search the nest for scraps.",
            nextRoomID: "split-tunnel"
        ),
        AdventureRoomDefinition(
            id: "split-tunnel",
            title: "Split Tunnel",
            type: .choice,
            description: "The mine splits into two unstable passages. One tunnel is narrow and partly collapsed. The other slopes downward, smoky and warm. Old support beams creak overhead.",
            choices: [
                AdventureChoiceDefinition(id: "smoky-tunnel", text: "Take the smoky tunnel", nextRoomID: "raider-camp")
            ],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "narrow-tunnel-agility", skill: .stealth, difficulty: .standard, successText: "You slip through the narrow tunnel and gain position for the next fight.", failureText: "Loose stone scrapes you as you crawl through.", successNextRoomID: "raider-camp", failureNextRoomID: "raider-camp"),
                AdventureSkillCheckDefinition(id: "narrow-tunnel-athletics", skill: .athletics, difficulty: .standard, successText: "You push through the narrow tunnel and gain position for the next fight.", failureText: "Loose stone scrapes you as you crawl through.", successNextRoomID: "raider-camp", failureNextRoomID: "raider-camp"),
                AdventureSkillCheckDefinition(id: "study-supports-lore", skill: .lore, difficulty: .standard, successText: "You find the safest route and pry loose useful stone.", failureText: "The supports tell you little.", successNextRoomID: "raider-camp", failureNextRoomID: "raider-camp"),
                AdventureSkillCheckDefinition(id: "study-supports-survival", skill: .survival, difficulty: .standard, successText: "You find the safest route and pry loose useful stone.", failureText: "The supports tell you little.", successNextRoomID: "raider-camp", failureNextRoomID: "raider-camp")
            ],
            enemyIDs: [],
            treasurePreview: nil,
            nextRoomID: "raider-camp"
        ),
        AdventureRoomDefinition(
            id: "raider-camp",
            title: "Raider Camp",
            type: .combat,
            description: "Lanterns flicker around a rough camp built beside a collapsed mine wall. Stolen tools, blankets and food scraps litter the floor. A raider sharpens a rusted blade while a lookout watches the dark.",
            choices: [],
            skillChecks: [],
            enemyIDs: ["greywick-raider", "raider-lookout"],
            treasurePreview: "Camp loot after combat.",
            nextRoomID: "locked-store-room"
        ),
        AdventureRoomDefinition(
            id: "locked-store-room",
            title: "Locked Store Room",
            type: .treasure,
            description: "A reinforced store room door stands half-hidden behind stacked timber. Rusted chains hang from the handle, and faint scrape marks show that someone has been dragging supplies in and out.",
            choices: [
                AdventureChoiceDefinition(id: "leave-store-room", text: "Leave it", nextRoomID: "deep-chamber")
            ],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "pick-store-lock", skill: .thievery, difficulty: .difficult, successText: "The lock opens safely.", failureText: "The lock jams loudly.", successNextRoomID: "deep-chamber", failureNextRoomID: "deep-chamber"),
                AdventureSkillCheckDefinition(id: "force-store-door", skill: .athletics, difficulty: .difficult, successText: "The door gives way.", failureText: "The door holds, and the effort hurts.", successNextRoomID: "deep-chamber", failureNextRoomID: "deep-chamber"),
                AdventureSkillCheckDefinition(id: "search-side-panel-awareness", skill: .awareness, difficulty: .standard, successText: "You find a side panel and slip inside.", failureText: "You find no way through.", successNextRoomID: "deep-chamber", failureNextRoomID: "deep-chamber"),
                AdventureSkillCheckDefinition(id: "search-side-panel-survival", skill: .survival, difficulty: .standard, successText: "You find a side panel and slip inside.", failureText: "You find no way through.", successNextRoomID: "deep-chamber", failureNextRoomID: "deep-chamber")
            ],
            enemyIDs: [],
            treasurePreview: "25 gold, a draught, Iron Ingot, and gear if opened.",
            nextRoomID: "deep-chamber"
        ),
        AdventureRoomDefinition(
            id: "deep-chamber",
            title: "Deep Chamber",
            type: .boss,
            description: "The mine opens into a deep chamber lit by a dying fire. Broken picks and torn packs lie scattered around the floor. At the far end, a huge brute rises from beside a stolen supply pile, dragging a heavy club across the stone.",
            choices: [],
            skillChecks: [],
            enemyIDs: ["bristleback-brute"],
            treasurePreview: "Boss reward and adventure completion.",
            nextRoomID: nil
        )
    ]

    private static let sunkenCryptRooms: [AdventureRoomDefinition] = [
        AdventureRoomDefinition(
            id: "crypt-marsh-gate", title: "Marsh Gate", type: .choice,
            description: "A half-sunken stone gate leans over flooded steps. Marsh water runs down into darkness while pale blue light stirs below.",
            choices: [AdventureChoiceDefinition(id: "crypt-bold-entry", text: "Light a torch and enter boldly", nextRoomID: "crypt-flooded-antechamber")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-inspect-awareness", skill: .awareness, difficulty: .standard, successText: "You identify safe footing through the flooded entrance.", failureText: "The footing remains uncertain.", successNextRoomID: "crypt-flooded-antechamber", failureNextRoomID: "crypt-flooded-antechamber"),
                AdventureSkillCheckDefinition(id: "crypt-inspect-survival", skill: .survival, difficulty: .standard, successText: "You read the water flow and identify safe footing.", failureText: "The water conceals the safest route.", successNextRoomID: "crypt-flooded-antechamber", failureNextRoomID: "crypt-flooded-antechamber"),
                AdventureSkillCheckDefinition(id: "crypt-quiet-entry", skill: .stealth, difficulty: .testing, successText: "You slip into the crypt without stirring the dead.", failureText: "Water splashes against the old stone.", successNextRoomID: "crypt-flooded-antechamber", failureNextRoomID: "crypt-flooded-antechamber")
            ], enemyIDs: [], treasurePreview: nil, nextRoomID: "crypt-flooded-antechamber"
        ),
        AdventureRoomDefinition(
            id: "crypt-flooded-antechamber", title: "Flooded Antechamber", type: .skillCheck,
            description: "Dark water covers the floor. Broken pillars rise above the surface, and something glints beneath the ripples.",
            choices: [],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-wade", skill: .endurance, difficulty: .standard, successText: "You cross safely through the cold water.", failureText: "Hidden stone tears at your legs.", successNextRoomID: "crypt-restless-dead", failureNextRoomID: "crypt-restless-dead"),
                AdventureSkillCheckDefinition(id: "crypt-search-water", skill: .awareness, difficulty: .testing, successText: "You recover coins and supplies beneath the water.", failureText: "Leeches stir in the mud.", successNextRoomID: "crypt-restless-dead", failureNextRoomID: "crypt-restless-dead"),
                AdventureSkillCheckDefinition(id: "crypt-pillars-athletics", skill: .athletics, difficulty: .challenging, successText: "You cross by the broken pillars and keep dry.", failureText: "A pillar shifts and drops you into the water.", successNextRoomID: "crypt-restless-dead", failureNextRoomID: "crypt-restless-dead"),
                AdventureSkillCheckDefinition(id: "crypt-pillars-agility", skill: .stealth, difficulty: .challenging, successText: "You balance across the broken pillars.", failureText: "You slip into the flooded chamber.", successNextRoomID: "crypt-restless-dead", failureNextRoomID: "crypt-restless-dead")
            ], enemyIDs: [], treasurePreview: "Coins and a minor supply may lie beneath the water.", nextRoomID: "crypt-restless-dead"
        ),
        AdventureRoomDefinition(
            id: "crypt-restless-dead", title: "Restless Dead", type: .combat,
            description: "Sodden burial cloth shifts in the blue light. Dead hands rise while a chittering mass of bone scraps pours from a wall niche.",
            choices: [], skillChecks: [], enemyIDs: ["crypt-shambler", "crypt-shambler", "bone-rat-swarm"],
            treasurePreview: "Small path-aware combat cache.", nextRoomID: "crypt-bell-chain"
        ),
        AdventureRoomDefinition(
            id: "crypt-bell-chain", title: "The Bell Chain", type: .choice,
            description: "A rusted bell chain hangs into a black pool. Somewhere below, a funeral bell answers every movement.",
            choices: [
                AdventureChoiceDefinition(id: "crypt-pull-chain", text: "Pull the chain", nextRoomID: "crypt-forked-passage"),
                AdventureChoiceDefinition(id: "crypt-ignore-chain", text: "Leave it alone", nextRoomID: "crypt-forked-passage")
            ],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-jam-chain-thievery", skill: .thievery, difficulty: .challenging, successText: "You jam the mechanism without sounding the bell.", failureText: "The chain snaps loudly.", successNextRoomID: "crypt-forked-passage", failureNextRoomID: "crypt-forked-passage"),
                AdventureSkillCheckDefinition(id: "crypt-jam-chain-athletics", skill: .athletics, difficulty: .challenging, successText: "You wrench the chain tight and silence it.", failureText: "The chain breaks with a thunderous clang.", successNextRoomID: "crypt-forked-passage", failureNextRoomID: "crypt-forked-passage")
            ], enemyIDs: [], treasurePreview: "The bell may conceal a niche, or warn the dead.", nextRoomID: "crypt-forked-passage"
        ),
        AdventureRoomDefinition(
            id: "crypt-forked-passage", title: "Forked Passage", type: .choice,
            description: "The crypt divides. Carved names line a dry upper hall, while a lower stair vanishes beneath rising black water.",
            choices: [
                AdventureChoiceDefinition(id: "crypt-route-hall", text: "Take the Hall of Names", nextRoomID: "crypt-hall-of-names"),
                AdventureChoiceDefinition(id: "crypt-route-floodway", text: "Enter the Lower Floodway", nextRoomID: "crypt-lower-floodway")
            ], skillChecks: [], enemyIDs: [], treasurePreview: nil, nextRoomID: nil
        ),
        AdventureRoomDefinition(
            id: "crypt-hall-of-names", title: "Hall of Names", type: .skillCheck,
            description: "Thousands of names cover the dry stone. Some letters glow faintly when spoken aloud.",
            choices: [],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-read-names-lore", skill: .lore, difficulty: .testing, successText: "The honoured dead grant a Graveward Blessing.", failureText: "The names remain silent.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch"),
                AdventureSkillCheckDefinition(id: "crypt-read-names-presence", skill: .persuasion, difficulty: .testing, successText: "Your respectful words earn a Graveward Blessing.", failureText: "No answer comes.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch"),
                AdventureSkillCheckDefinition(id: "crypt-search-plaques", skill: .awareness, difficulty: .challenging, successText: "You find a relic fragment behind a cracked plaque.", failureText: "Old bones shift beneath your hand.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch"),
                AdventureSkillCheckDefinition(id: "crypt-mark-wall", skill: .intimidation, difficulty: .difficult, successText: "Your defiance steels you against the dead.", failureText: "The dead mark you in return.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch")
            ], enemyIDs: [], treasurePreview: "A blessing or hidden relic.", nextRoomID: "crypt-bone-watch"
        ),
        AdventureRoomDefinition(
            id: "crypt-lower-floodway", title: "Lower Floodway", type: .skillCheck,
            description: "Cold water reaches your waist. A stone shelf and a submerged chest are barely visible ahead.",
            choices: [AdventureChoiceDefinition(id: "crypt-turn-back", text: "Turn back to safer stones", nextRoomID: "crypt-bone-watch")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-push-floodway", skill: .endurance, difficulty: .challenging, successText: "You force through the current and reach the treasure shelf.", failureText: "The current batters you against the stone.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch"),
                AdventureSkillCheckDefinition(id: "crypt-dive-chest", skill: .athletics, difficulty: .difficult, successText: "You drag the submerged chest into the air.", failureText: "The chest catches and the water closes over you.", successNextRoomID: "crypt-bone-watch", failureNextRoomID: "crypt-bone-watch")
            ], enemyIDs: [], treasurePreview: "Riskier path-aware treasure.", nextRoomID: "crypt-bone-watch"
        ),
        AdventureRoomDefinition(
            id: "crypt-bone-watch", title: "Bone Watch", type: .combat,
            description: "Armoured dead stand watch where the passages meet. The bell chain's fate has changed their readiness.",
            choices: [], skillChecks: [], enemyIDs: ["drowned-skeleton", "crypt-shambler", "crypt-shambler"],
            treasurePreview: "Path-aware loot and gold.", nextRoomID: "crypt-sealed-reliquary"
        ),
        AdventureRoomDefinition(
            id: "crypt-sealed-reliquary", title: "Sealed Reliquary", type: .treasure,
            description: "A stone reliquary is sealed by three rotating symbols: Flame, Wave and Bone.",
            choices: [AdventureChoiceDefinition(id: "crypt-leave-reliquary", text: "Leave it sealed", nextRoomID: "crypt-bell-chamber")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-study-symbols-lore", skill: .lore, difficulty: .challenging, successText: "The symbols align and the reliquary opens safely.", failureText: "The symbols refuse to align.", successNextRoomID: "crypt-bell-chamber", failureNextRoomID: "crypt-bell-chamber"),
                AdventureSkillCheckDefinition(id: "crypt-study-symbols-arcana", skill: .arcana, difficulty: .challenging, successText: "You unwind the old ward and open the reliquary.", failureText: "The old ward holds.", successNextRoomID: "crypt-bell-chamber", failureNextRoomID: "crypt-bell-chamber"),
                AdventureSkillCheckDefinition(id: "crypt-pick-reliquary", skill: .thievery, difficulty: .difficult, successText: "The hidden catch opens.", failureText: "A bone needle snaps from the seal.", successNextRoomID: "crypt-bell-chamber", failureNextRoomID: "crypt-bell-chamber"),
                AdventureSkillCheckDefinition(id: "crypt-force-reliquary", skill: .athletics, difficulty: .difficult, successText: "The lid grinds open.", failureText: "The stone crushes your fingers.", successNextRoomID: "crypt-bell-chamber", failureNextRoomID: "crypt-bell-chamber")
            ], enemyIDs: [], treasurePreview: "Relic Fragment, gold and a rare gear chance.", nextRoomID: "crypt-bell-chamber"
        ),
        AdventureRoomDefinition(
            id: "crypt-bell-chamber", title: "The Drowned Bell Chamber", type: .choice,
            description: "A funeral bell hangs above a black pool. The drowned guardian waits below, listening.",
            choices: [AdventureChoiceDefinition(id: "crypt-bind-wounds", text: "Take a moment to bind wounds", nextRoomID: "crypt-bell-drowned-warden")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "crypt-study-chamber-awareness", skill: .awareness, difficulty: .challenging, successText: "You identify a weakness in the guardian's position.", failureText: "The water conceals the guardian.", successNextRoomID: "crypt-bell-drowned-warden", failureNextRoomID: "crypt-bell-drowned-warden"),
                AdventureSkillCheckDefinition(id: "crypt-study-chamber-lore", skill: .lore, difficulty: .challenging, successText: "Old burial lore reveals the guardian's weakness.", failureText: "The bell's history offers no immediate advantage.", successNextRoomID: "crypt-bell-drowned-warden", failureNextRoomID: "crypt-bell-drowned-warden"),
                AdventureSkillCheckDefinition(id: "crypt-challenge", skill: .intimidation, difficulty: .challenging, successText: "The guardian rises into your challenge, leaving itself open.", failureText: "Its gaze fixes upon you.", successNextRoomID: "crypt-bell-drowned-warden", failureNextRoomID: "crypt-bell-drowned-warden"),
                AdventureSkillCheckDefinition(id: "crypt-enter-silently", skill: .stealth, difficulty: .difficult, successText: "You gain the first strike.", failureText: "The guardian hears you approach.", successNextRoomID: "crypt-bell-drowned-warden", failureNextRoomID: "crypt-bell-drowned-warden")
            ], enemyIDs: [], treasurePreview: nil, nextRoomID: "crypt-bell-drowned-warden"
        ),
        AdventureRoomDefinition(
            id: "crypt-bell-drowned-warden", title: "The Bell-Drowned Warden", type: .boss,
            description: "A drowned guardian rises in cracked burial armour, dragging a rusted bell hammer through the water.",
            choices: [], skillChecks: [], enemyIDs: ["bell-drowned-warden"],
            treasurePreview: "Boss Fortune, path-aware gear and Crypt Bell Shards.", nextRoomID: nil
        )
    ]

    private static let emberCaveRooms: [AdventureRoomDefinition] = [
        AdventureRoomDefinition(
            id: "ember-smoking-entrance", title: "Smoking Entrance", type: .skillCheck,
            description: "The cave mouth breathes warm smoke. Old ash shifts across stone that glows faintly beneath your boots.",
            choices: [], skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-study-smoke-awareness", skill: .awareness, difficulty: .testing, successText: "You read a safe path through the smoke and prepare for the next hazard.", failureText: "The smoke patterns remain uncertain.", successNextRoomID: "ember-ash-beetle-nest", failureNextRoomID: "ember-ash-beetle-nest"),
                AdventureSkillCheckDefinition(id: "ember-study-smoke-survival", skill: .survival, difficulty: .testing, successText: "You read a safe path through the smoke and prepare for the next hazard.", failureText: "The smoke patterns remain uncertain.", successNextRoomID: "ember-ash-beetle-nest", failureNextRoomID: "ember-ash-beetle-nest"),
                AdventureSkillCheckDefinition(id: "ember-push-smoke", skill: .endurance, difficulty: .testing, successText: "You cover your mouth and push through safely.", failureText: "The smoke catches in your lungs.", successNextRoomID: "ember-ash-beetle-nest", failureNextRoomID: "ember-ash-beetle-nest"),
                AdventureSkillCheckDefinition(id: "ember-rush-smoke", skill: .stealth, difficulty: .challenging, successText: "You cross the choking entrance quickly and gain an early advantage.", failureText: "Loose ash sends you stumbling.", successNextRoomID: "ember-ash-beetle-nest", failureNextRoomID: "ember-ash-beetle-nest")
            ], enemyIDs: [], treasurePreview: nil, nextRoomID: "ember-ash-beetle-nest"
        ),
        AdventureRoomDefinition(
            id: "ember-ash-beetle-nest", title: "Ash Beetle Nest", type: .combat,
            description: "Shells scrape beneath the ash. Two fire-touched beetles close in while an ember skitter drops from the heated wall.",
            choices: [], skillChecks: [], enemyIDs: ["ash-beetle", "ash-beetle", "ember-skitter"],
            treasurePreview: "Gold, supplies and a chance of ember material.", nextRoomID: "ember-heat-cracked-bridge"
        ),
        AdventureRoomDefinition(
            id: "ember-heat-cracked-bridge", title: "Heat-Cracked Bridge", type: .skillCheck,
            description: "A cracked stone bridge spans a glowing fissure. Heat rises through every broken seam.",
            choices: [], skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-cross-bridge-agility", skill: .stealth, difficulty: .challenging, successText: "You cross the unstable bridge safely.", failureText: "A slab shifts and the fissure scorches you.", successNextRoomID: "ember-flame-tunnels", failureNextRoomID: "ember-flame-tunnels"),
                AdventureSkillCheckDefinition(id: "ember-cross-bridge-athletics", skill: .athletics, difficulty: .challenging, successText: "You cross the unstable bridge safely.", failureText: "A slab shifts and the fissure scorches you.", successNextRoomID: "ember-flame-tunnels", failureNextRoomID: "ember-flame-tunnels"),
                AdventureSkillCheckDefinition(id: "ember-reinforce-bridge-athletics", skill: .athletics, difficulty: .testing, successText: "You secure the loose stones and leave yourself a safer retreat.", failureText: "The bridge refuses to settle.", successNextRoomID: "ember-flame-tunnels", failureNextRoomID: "ember-flame-tunnels"),
                AdventureSkillCheckDefinition(id: "ember-reinforce-bridge-survival", skill: .survival, difficulty: .testing, successText: "You secure the loose stones and leave yourself a safer retreat.", failureText: "The bridge refuses to settle.", successNextRoomID: "ember-flame-tunnels", failureNextRoomID: "ember-flame-tunnels"),
                AdventureSkillCheckDefinition(id: "ember-search-fissure", skill: .awareness, difficulty: .difficult, successText: "You spot an ember deposit beneath the bridge.", failureText: "The smoke burns your lungs before you find anything.", successNextRoomID: "ember-flame-tunnels", failureNextRoomID: "ember-flame-tunnels")
            ], enemyIDs: [], treasurePreview: "Ember Shards glint below the bridge.", nextRoomID: "ember-flame-tunnels"
        ),
        AdventureRoomDefinition(
            id: "ember-flame-tunnels", title: "Split in the Flame Tunnels", type: .choice,
            description: "One passage glitters with exposed ember crystal. The other follows an old, dark cooling channel.",
            choices: [
                AdventureChoiceDefinition(id: "ember-route-vein", text: "Follow the Ember Vein", nextRoomID: "ember-vein"),
                AdventureChoiceDefinition(id: "ember-route-channel", text: "Take the Old Cooling Channel", nextRoomID: "ember-cooling-channel")
            ], skillChecks: [], enemyIDs: [], treasurePreview: nil, nextRoomID: nil
        ),
        AdventureRoomDefinition(
            id: "ember-vein", title: "Ember Vein", type: .skillCheck,
            description: "The walls pulse with exposed ember crystals, each one warm enough to sting bare skin.",
            choices: [AdventureChoiceDefinition(id: "ember-leave-vein", text: "Leave the crystals alone", nextRoomID: "emberbound-patrol")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-mine-vein-athletics", skill: .athletics, difficulty: .difficult, successText: "You break out valuable ember crystal and coin-bearing ore.", failureText: "The vein flares violently.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-mine-vein-endurance", skill: .endurance, difficulty: .difficult, successText: "You endure the heat and break out valuable crystal.", failureText: "The vein flares violently.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-extract-vein-thievery", skill: .thievery, difficulty: .challenging, successText: "You loosen the crystals without disturbing the hottest seams.", failureText: "You recover only a few fragments.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-extract-vein-survival", skill: .survival, difficulty: .challenging, successText: "You loosen the crystals without disturbing the hottest seams.", failureText: "You recover only a few fragments.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol")
            ], enemyIDs: [], treasurePreview: "Ember Shards, Scorched Ore and gold.", nextRoomID: "emberbound-patrol"
        ),
        AdventureRoomDefinition(
            id: "ember-cooling-channel", title: "Old Cooling Channel", type: .skillCheck,
            description: "A narrow stone channel once carried water through the buried forge. Its mechanisms are clogged with ash.",
            choices: [], skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-clear-channel-athletics", skill: .athletics, difficulty: .challenging, successText: "Water coughs through the channel and cools the chambers ahead.", failureText: "The channel remains blocked.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-study-markings-lore", skill: .lore, difficulty: .challenging, successText: "The old forge marks reveal how its guardians were built.", failureText: "The markings offer no useful pattern.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-study-markings-arcana", skill: .arcana, difficulty: .challenging, successText: "The old forge marks reveal how its guardians were built.", failureText: "The markings offer no useful pattern.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol"),
                AdventureSkillCheckDefinition(id: "ember-search-channel", skill: .awareness, difficulty: .testing, successText: "You find coins and ore caught in the channel floor.", failureText: "The channel holds nothing useful.", successNextRoomID: "emberbound-patrol", failureNextRoomID: "emberbound-patrol")
            ], enemyIDs: [], treasurePreview: "A safer route with tactical preparation.", nextRoomID: "emberbound-patrol"
        ),
        AdventureRoomDefinition(
            id: "emberbound-patrol", title: "Emberbound Patrol", type: .combat,
            description: "An armoured forge guardian advances between two ash beetles, its blade glowing along the edge.",
            choices: [], skillChecks: [], enemyIDs: ["emberbound-guard", "ash-beetle", "ash-beetle"],
            treasurePreview: "Path-aware gear and ember material.", nextRoomID: "ember-charred-shrine"
        ),
        AdventureRoomDefinition(
            id: "ember-charred-shrine", title: "Charred Shrine", type: .choice,
            description: "A blackened shrine stands in the ash. It is not evil, but it is old and hungry.",
            choices: [
                AdventureChoiceDefinition(id: "ember-offer-gold", text: "Offer 10 gold", nextRoomID: "ember-sealed-forge-cache"),
                AdventureChoiceDefinition(id: "ember-offer-blood", text: "Offer a drop of blood", nextRoomID: "ember-sealed-forge-cache"),
                AdventureChoiceDefinition(id: "ember-leave-shrine", text: "Leave it alone", nextRoomID: "ember-sealed-forge-cache")
            ], skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-clean-shrine-presence", skill: .persuasion, difficulty: .challenging, successText: "The cleaned shrine grants protection from the next flame.", failureText: "The shrine remains cold and silent.", successNextRoomID: "ember-sealed-forge-cache", failureNextRoomID: "ember-sealed-forge-cache"),
                AdventureSkillCheckDefinition(id: "ember-clean-shrine-lore", skill: .lore, difficulty: .challenging, successText: "The cleaned shrine grants protection from the next flame.", failureText: "The shrine remains cold and silent.", successNextRoomID: "ember-sealed-forge-cache", failureNextRoomID: "ember-sealed-forge-cache")
            ], enemyIDs: [], treasurePreview: "A blessing, at a price.", nextRoomID: "ember-sealed-forge-cache"
        ),
        AdventureRoomDefinition(
            id: "ember-sealed-forge-cache", title: "Sealed Forge Cache", type: .treasure,
            description: "A sealed iron cache waits behind a half-melted door. Its lock and runes still glow.",
            choices: [AdventureChoiceDefinition(id: "ember-leave-cache", text: "Leave the cache sealed", nextRoomID: "ember-furnace-hound")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-pick-cache", skill: .thievery, difficulty: .difficult, successText: "The lock opens and the cache cools.", failureText: "The lock spits a tongue of flame.", successNextRoomID: "ember-furnace-hound", failureNextRoomID: "ember-furnace-hound"),
                AdventureSkillCheckDefinition(id: "ember-force-cache", skill: .athletics, difficulty: .severe, successText: "The warped door tears free.", failureText: "The heated iron burns your hands.", successNextRoomID: "ember-furnace-hound", failureNextRoomID: "ember-furnace-hound"),
                AdventureSkillCheckDefinition(id: "ember-runes-cache-arcana", skill: .arcana, difficulty: .difficult, successText: "The locking runes unwind safely.", failureText: "The runes flare against you.", successNextRoomID: "ember-furnace-hound", failureNextRoomID: "ember-furnace-hound"),
                AdventureSkillCheckDefinition(id: "ember-runes-cache-lore", skill: .lore, difficulty: .difficult, successText: "The locking runes unwind safely.", failureText: "The runes flare against you.", successNextRoomID: "ember-furnace-hound", failureNextRoomID: "ember-furnace-hound")
            ], enemyIDs: [], treasurePreview: "Build-fit armour, material and a consumable.", nextRoomID: "ember-furnace-hound"
        ),
        AdventureRoomDefinition(
            id: "ember-furnace-hound", title: "Furnace Hound", type: .combat,
            description: "A forge-beast pulls itself from a bed of coals, iron ribs glowing around a furnace-bright heart.",
            choices: [], skillChecks: [], enemyIDs: ["furnace-hound"],
            treasurePreview: "Elite gold, ember material and armour or charm chance.", nextRoomID: "ember-cooling-choice"
        ),
        AdventureRoomDefinition(
            id: "ember-cooling-choice", title: "The Cooling Choice", type: .skillCheck,
            description: "Forge vents ring the final approach. Their old controls could change the battle ahead.",
            choices: [AdventureChoiceDefinition(id: "ember-rest-before-boss", text: "Rest briefly in the cooler stone", nextRoomID: "ember-deep-forge-door")],
            skillChecks: [
                AdventureSkillCheckDefinition(id: "ember-open-vents-athletics", skill: .athletics, difficulty: .difficult, successText: "The vents open and cold air spills toward the deep forge.", failureText: "A burst of heat catches you.", successNextRoomID: "ember-deep-forge-door", failureNextRoomID: "ember-deep-forge-door"),
                AdventureSkillCheckDefinition(id: "ember-open-vents-thievery", skill: .thievery, difficulty: .difficult, successText: "The vents open and cold air spills toward the deep forge.", failureText: "A burst of heat catches you.", successNextRoomID: "ember-deep-forge-door", failureNextRoomID: "ember-deep-forge-door"),
                AdventureSkillCheckDefinition(id: "ember-study-rhythm-awareness", skill: .awareness, difficulty: .difficult, successText: "You learn the rhythm of the forge-heart and prepare your first strike.", failureText: "The rhythm shifts too quickly.", successNextRoomID: "ember-deep-forge-door", failureNextRoomID: "ember-deep-forge-door"),
                AdventureSkillCheckDefinition(id: "ember-study-rhythm-arcana", skill: .arcana, difficulty: .difficult, successText: "You learn the rhythm of the forge-heart and prepare your first strike.", failureText: "The rhythm shifts too quickly.", successNextRoomID: "ember-deep-forge-door", failureNextRoomID: "ember-deep-forge-door"),
                AdventureSkillCheckDefinition(id: "ember-draw-heat", skill: .endurance, difficulty: .difficult, successText: "You draw the forge heat into your next blow.", failureText: "The heat scorches through your guard.", successNextRoomID: "ember-deep-forge-door", failureNextRoomID: "ember-deep-forge-door")
            ], enemyIDs: [], treasurePreview: "Prepare for the Emberheart Golem.", nextRoomID: "ember-deep-forge-door"
        ),
        AdventureRoomDefinition(
            id: "ember-deep-forge-door", title: "Deep Forge Door", type: .story,
            description: "The sealed forge door opens. Beyond it, the old cave glows like a furnace, and a cracked construct turns toward the light.",
            choices: [AdventureChoiceDefinition(id: "ember-enter-forge", text: "Enter the deep forge", nextRoomID: "emberheart-golem")],
            skillChecks: [], enemyIDs: [], treasurePreview: nil, nextRoomID: "emberheart-golem"
        ),
        AdventureRoomDefinition(
            id: "emberheart-golem", title: "Emberheart Golem", type: .boss,
            description: "A cracked forge-construct rises around a glowing heart of unstable emberstone.",
            choices: [], skillChecks: [], enemyIDs: ["emberheart-golem"],
            treasurePreview: "Boss Fortune, guaranteed build-fit gear and Emberheart Fragment.", nextRoomID: nil
        )
    ]
}
