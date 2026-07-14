import Foundation

enum EnemyData {
    static let hollowMineEnemies: [Enemy] = [
        Enemy(
            id: "cave-rat",
            name: "Cave Rat",
            tier: .minor,
            family: "Vermin",
            level: 1,
            maxHealth: 5,
            defence: 10,
            initiativeBonus: 2,
            attackBonus: 3,
            damageExpression: "1d4",
            damageType: .physical,
            resistances: [:],
            weaknesses: [:],
            abilities: [],
            immunities: [],
            xp: 25,
            goldRange: 1...3,
            summary: "A hungry cave rat with sharp teeth and little fear."
        ),
        Enemy(
            id: "tunnel-skitter",
            name: "Tunnel Skitter",
            tier: .minor,
            family: "Vermin",
            level: 1,
            maxHealth: 6,
            defence: 11,
            initiativeBonus: 3,
            attackBonus: 3,
            damageExpression: "1d4",
            damageType: .physical,
            resistances: [:],
            weaknesses: [.fire: 1],
            abilities: [
                EnemyAbility(
                    id: "skitter-venom",
                    name: "Venomous Bite",
                    summary: "On hit, 20% chance to apply Poisoned for 1 turn.",
                    actionType: .passive,
                    damageType: .poison
                )
            ],
            immunities: [],
            xp: 25,
            goldRange: 1...4,
            summary: "A pale tunnel crawler whose bite can sour the blood."
        ),
        Enemy(
            id: "greywick-raider",
            name: "Greywick Raider",
            tier: .standard,
            family: "Raider",
            level: 1,
            maxHealth: 12,
            defence: 12,
            initiativeBonus: 1,
            attackBonus: 4,
            damageExpression: "1d6 + 1",
            damageType: .physical,
            resistances: [:],
            weaknesses: [:],
            abilities: [
                EnemyAbility(
                    id: "dirty-slash",
                    name: "Dirty Slash",
                    summary: "Once per combat, applies Bleeding for 1 turn on hit.",
                    actionType: .major,
                    damageType: .physical
                )
            ],
            immunities: [],
            xp: 50,
            goldRange: 4...10,
            summary: "A rough blade-for-hire preying on travellers near the mine road."
        ),
        Enemy(
            id: "raider-lookout",
            name: "Raider Lookout",
            tier: .standard,
            family: "Raider",
            level: 1,
            maxHealth: 10,
            defence: 12,
            initiativeBonus: 2,
            attackBonus: 4,
            damageExpression: "1d6",
            damageType: .physical,
            resistances: [:],
            weaknesses: [:],
            abilities: [
                EnemyAbility(
                    id: "quick-draw",
                    name: "Quick Draw",
                    summary: "First attack each combat gains +1 to hit.",
                    actionType: .passive,
                    damageType: .physical
                )
            ],
            immunities: [],
            xp: 50,
            goldRange: 4...12,
            summary: "A wary raider posted to warn the camp and loose the first shot."
        ),
        Enemy(
            id: "bristleback-brute",
            name: "Bristleback Brute",
            tier: .boss,
            family: "Raider/Beast",
            level: 2,
            maxHealth: 30,
            defence: 13,
            initiativeBonus: 0,
            attackBonus: 4,
            damageExpression: "1d8 + 2",
            damageType: .physical,
            resistances: [.physical: 1],
            weaknesses: [:],
            abilities: [
                EnemyAbility(
                    id: "ground-slam",
                    name: "Ground Slam",
                    summary: "Once per combat. On hit, deals 1d6 + 2 physical and applies Knocked Down.",
                    actionType: .major,
                    damageType: .physical
                )
            ],
            immunities: [],
            xp: 200,
            goldRange: 25...60,
            summary: "A hulking brute in scavenged mail with a bone-rattling charge."
        ),
        Enemy(
            id: "crypt-shambler", name: "Crypt Shambler", tier: .standard, family: "Undead", level: 2,
            maxHealth: 10, defence: 11, initiativeBonus: -1, attackBonus: 3,
            damageExpression: "1d6", damageType: .physical, resistances: [:], weaknesses: [.fire: 1],
            abilities: [], immunities: [.poisoned], xp: 50, goldRange: 3...8,
            summary: "A waterlogged corpse animated by the bell beneath the marsh."
        ),
        Enemy(
            id: "bone-rat-swarm", name: "Bone Rat Swarm", tier: .standard, family: "Undead/Swarm", level: 2,
            maxHealth: 8, defence: 12, initiativeBonus: 2, attackBonus: 4,
            damageExpression: "1d4", damageType: .physical, resistances: [:], weaknesses: [:],
            abilities: [
                EnemyAbility(id: "bone-swarm-bleed", name: "Gnawing Bones", summary: "On hit, 20% chance to apply Bleeding.", actionType: .passive, damageType: .physical)
            ],
            immunities: [.poisoned], xp: 50, goldRange: 2...7,
            summary: "A churning knot of tiny skeletons bound together by grave-light."
        ),
        Enemy(
            id: "drowned-skeleton", name: "Drowned Skeleton", tier: .standard, family: "Undead", level: 2,
            maxHealth: 14, defence: 12, initiativeBonus: 1, attackBonus: 4,
            damageExpression: "1d6 + 1", damageType: .physical, resistances: [:], weaknesses: [.fire: 1],
            abilities: [], immunities: [.poisoned], xp: 50, goldRange: 5...10,
            summary: "A marsh-stained skeleton still wearing fragments of burial armour."
        ),
        Enemy(
            id: "bell-touched-warden", name: "Bell-Touched Warden", tier: .strong, family: "Undead", level: 3,
            maxHealth: 18, defence: 13, initiativeBonus: 1, attackBonus: 4,
            damageExpression: "1d8", damageType: .physical, resistances: [:], weaknesses: [.fire: 1],
            abilities: [
                EnemyAbility(id: "bell-touched-strike", name: "Bell-Touched Strike", summary: "First successful hit may apply Weakened.", actionType: .passive, damageType: .shadow)
            ],
            immunities: [.poisoned], xp: 100, goldRange: 8...16,
            summary: "A crypt guardian stirred early by the ringing chain."
        ),
        Enemy(
            id: "bell-drowned-warden", name: "Bell-Drowned Warden", tier: .boss, family: "Undead", level: 3,
            maxHealth: 42, defence: 14, initiativeBonus: 1, attackBonus: 5,
            damageExpression: "1d8 + 3", damageType: .physical,
            resistances: [.physical: 1], weaknesses: [.fire: 1],
            abilities: [
                EnemyAbility(id: "drowned-toll", name: "Drowned Toll", summary: "May ring the bell and apply Weakened for 1 turn.", actionType: .major, damageType: .shadow),
                EnemyAbility(id: "grave-pull", name: "Grave Pull", summary: "On hit, 25% chance to apply Slowed for 1 turn.", actionType: .passive, damageType: .shadow),
                EnemyAbility(id: "waterlogged-armour", name: "Waterlogged Armour", summary: "Physical Resistance 1 and Fire Weakness 1.", actionType: .passive, damageType: .physical)
            ],
            immunities: [.poisoned], xp: 200, goldRange: 50...75,
            summary: "A drowned guardian dragging a rusted bell hammer through black water."
        ),
        Enemy(
            id: "ash-beetle", name: "Ash Beetle", tier: .standard, family: "Beast/Fire-touched", level: 3,
            maxHealth: 9, defence: 12, initiativeBonus: 2, attackBonus: 4,
            damageExpression: "1d4", damageType: .physical,
            resistances: [.fire: 1], weaknesses: [.frost: 1],
            abilities: [
                EnemyAbility(id: "ash-spark", name: "Ash Spark", summary: "On hit, 20% chance to deal +1 fire damage.", actionType: .passive, damageType: .fire)
            ],
            immunities: [], xp: 50, goldRange: 4...9,
            summary: "A broad-shelled cave beetle glowing through cracks in its ash-black carapace."
        ),
        Enemy(
            id: "ember-skitter", name: "Ember Skitter", tier: .standard, family: "Beast/Fire-touched", level: 3,
            maxHealth: 11, defence: 12, initiativeBonus: 3, attackBonus: 4,
            damageExpression: "1d4 + 1", damageType: .fire,
            resistances: [.fire: 1], weaknesses: [.frost: 1],
            abilities: [
                EnemyAbility(id: "ember-venom", name: "Searing Bite", summary: "On hit, 20% chance to apply Burning for 1 turn.", actionType: .passive, damageType: .fire)
            ],
            immunities: [], xp: 50, goldRange: 5...10,
            summary: "A fast cave crawler whose mandibles spit sparks when they close."
        ),
        Enemy(
            id: "emberbound-guard", name: "Emberbound Guard", tier: .strong, family: "Construct/Forge", level: 3,
            maxHealth: 18, defence: 13, initiativeBonus: 1, attackBonus: 5,
            damageExpression: "1d6 + 2", damageType: .physical,
            resistances: [.fire: 1], weaknesses: [:],
            abilities: [
                EnemyAbility(id: "ember-blade", name: "Ember Blade", summary: "On hit, 25% chance to deal +1 fire damage.", actionType: .passive, damageType: .fire)
            ],
            immunities: [.poisoned], xp: 100, goldRange: 10...20,
            summary: "An old forge sentinel bound to a blade that still carries living heat."
        ),
        Enemy(
            id: "furnace-hound", name: "Furnace Hound", tier: .strong, family: "Construct/Beast", level: 4,
            maxHealth: 30, defence: 14, initiativeBonus: 2, attackBonus: 5,
            damageExpression: "1d8 + 2", damageType: .physical,
            resistances: [.fire: 1], weaknesses: [.frost: 1],
            abilities: [
                EnemyAbility(id: "flame-snap", name: "Flame Snap", summary: "On hit, 25% chance to apply Burning for 1 turn.", actionType: .passive, damageType: .fire)
            ],
            immunities: [.poisoned], xp: 100, goldRange: 18...30,
            summary: "An iron-ribbed forge-beast with a coal bed burning behind its teeth."
        ),
        Enemy(
            id: "emberheart-golem", name: "Emberheart Golem", tier: .boss, family: "Construct/Forge", level: 4,
            maxHealth: 55, defence: 15, initiativeBonus: 0, attackBonus: 5,
            damageExpression: "1d8 + 3", damageType: .physical,
            resistances: [.fire: 1], weaknesses: [.frost: 1],
            abilities: [
                EnemyAbility(id: "ember-pulse", name: "Ember Pulse", summary: "Every third round, releases a pulse of fire. Endurance Target 14 reduces its impact.", actionType: .major, damageType: .fire),
                EnemyAbility(id: "molten-fist", name: "Molten Fist", summary: "On hit, 20% chance to apply Burning for 1 turn.", actionType: .passive, damageType: .fire),
                EnemyAbility(id: "cracked-core", name: "Cracked Core", summary: "Below half health, attacks deal +1 fire damage.", actionType: .passive, damageType: .fire)
            ],
            immunities: [.poisoned], xp: 300, goldRange: 75...100,
            summary: "A towering forge-construct animated by an unstable heart of emberstone."
        )
    ]

    static func enemy(id: String) -> Enemy? {
        hollowMineEnemies.first { $0.id == id }
    }

    static func enemies(ids: [String]) -> [Enemy] {
        ids.compactMap(enemy(id:))
    }
}
