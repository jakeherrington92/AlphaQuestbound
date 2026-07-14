import SwiftUI

struct DeveloperToolsView: View {
    @EnvironmentObject private var saveStore: SaveStore

    let slotID: Int

    @State private var developerCode = ""
    @State private var message: String?

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    section("Test Combats") {
                        combatLink("Cave Rat", icon: "pawprint", encounterID: "test-cave-rat", enemyIDs: ["cave-rat"])
                        combatLink("Raider Camp", icon: "person.2", encounterID: "test-raider-camp", enemyIDs: ["greywick-raider", "raider-lookout"])
                        combatLink("Bristleback Brute", icon: "exclamationmark.shield", encounterID: "test-bristleback-brute", enemyIDs: ["bristleback-brute"])
                        combatLink("AoE: 3 Targets", icon: "circle.grid.3x3", encounterID: "test-aoe-three-targets", enemyIDs: ["cave-rat", "cave-rat", "cave-rat"])
                        combatLink("Sunken Crypt Pack", icon: "drop.triangle", encounterID: "test-sunken-crypt-pack", enemyIDs: ["crypt-shambler", "bone-rat-swarm", "drowned-skeleton"])
                        combatLink("Bell-Drowned Warden", icon: "bell", encounterID: "test-bell-drowned-warden", enemyIDs: ["bell-drowned-warden"])
                        combatLink("Ember Cave Pack", icon: "flame", encounterID: "test-ember-cave-pack", enemyIDs: ["ash-beetle", "ash-beetle", "ember-skitter"])
                        combatLink("Furnace Hound", icon: "flame.circle", encounterID: "test-furnace-hound", enemyIDs: ["furnace-hound"])
                        combatLink("Emberheart Golem", icon: "flame.fill", encounterID: "test-emberheart-golem", enemyIDs: ["emberheart-golem"])
                    }

                    section("Developer Codes") {
                        TextField("Enter debug code", text: $developerCode)
                            .textInputAutocapitalization(.characters)
                            .textFieldStyle(.roundedBorder)
                        toolButton("Apply Developer Code", icon: "terminal") {
                            message = saveStore.applyDeveloperCode(developerCode, to: slotID)
                            developerCode = ""
                        }
                        Text("RICHVALE, MAXVALE, SKILLVALE")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    section("Character Level / XP") {
                        Text("Set XP for Level")
                            .font(.caption.weight(.bold))
                        levelButtons(prefix: "Level") { level in
                            message = saveStore.setDeveloperXPForLevel(level, slotID: slotID)
                        }

                        Text("Debug Force Level")
                            .font(.caption.weight(.bold))
                        levelButtons(prefix: "Force") { level in
                            message = saveStore.forceDeveloperLevel(level, slotID: slotID)
                        }

                        HStack(spacing: 8) {
                            Button("+100 XP") { message = saveStore.addDeveloperXP(100, slotID: slotID) }
                            Button("+500 XP") { message = saveStore.addDeveloperXP(500, slotID: slotID) }
                            Button("+1000 XP") { message = saveStore.addDeveloperXP(1_000, slotID: slotID) }
                        }
                        .buttonStyle(.bordered)

                        NavigationLink {
                            DeveloperAttributeRespecView(slotID: slotID)
                        } label: {
                            Label("Respec Attributes", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        toolButton("Full Restore", icon: "cross.case") {
                            message = saveStore.developerFullRestore(slotID: slotID)
                        }
                    }

                    section("Gear Tools") {
                        toolButton("Give Full Equipment Slot Test Set", icon: "backpack") {
                            message = saveStore.giveDeveloperGearTestSet(slotID: slotID)
                        }
                        toolButton("Give All Version 1 Gear", icon: "shippingbox") {
                            message = saveStore.giveAllVersionOneGear(slotID: slotID)
                        }
                        toolButton("Give All Gear for My Path", icon: "figure.archery") {
                            message = saveStore.giveAllGearForMyPath(slotID: slotID)
                        }
                        toolButton("Give All Gear for My Subpath", icon: "point.3.connected.trianglepath.dotted") {
                            message = saveStore.giveAllGearForMySubpath(slotID: slotID)
                        }
                        .disabled(hero?.selectedSubpath == nil)
                        toolButton("Give All Epic Subpath Weapons", icon: "sparkles") {
                            message = saveStore.giveAllEpicSubpathWeapons(slotID: slotID)
                        }
                        toolButton("Equip Best Available Empty Slots", icon: "wand.and.stars") {
                            message = saveStore.equipDeveloperEmptySlots(slotID: slotID)
                        }
                    }

                    section("Shop Tools") {
                        toolButton("Give Recommended Shop Stock", icon: "storefront") {
                            message = saveStore.giveRecommendedShopStock(slotID: slotID)
                        }
                    }

                    section("Adventure Cleanup") {
                        toolButton("Unlock Ember Cave", icon: "lock.open") {
                            message = saveStore.developerUnlockEmberCave(slotID: slotID)
                        }
                        toolButton("Give Ember Cave Test Supplies", icon: "cross.case.fill") {
                            message = saveStore.giveEmberCaveTestSupplies(slotID: slotID)
                        }
                        toolButton("Return Hero to Greywick", icon: "house") {
                            message = saveStore.developerReturnHeroToGreywick(slotID: slotID)
                        }
                        toolButton("Clear Pending Completion", icon: "checkmark.circle") {
                            message = saveStore.developerClearPendingCompletion(slotID: slotID)
                        }
                        toolButton("Clear Active Adventure", icon: "trash", role: .destructive) {
                            message = saveStore.developerClearActiveAdventure(slotID: slotID)
                        }
                    }

                    section("Debug Info") {
                        if let hero {
                            debugRow("Hero", hero.name)
                            debugRow("Level / XP", "\(hero.level) / \(hero.xp)")
                            debugRow("Path", hero.subpath.map { "\(hero.path.rawValue) / \($0)" } ?? hero.path.rawValue)
                            debugRow("Location", hero.currentLocation)
                            debugRow("Adventure Active", hero.currentAdventureState.isActive ? "Yes" : "No")
                            debugRow("Adventure ID", hero.currentAdventureState.adventureID ?? "None")
                            debugRow("Room", AdventureEngine.currentRoom(for: hero)?.title ?? "None")
                            debugRow("Pending Completion", AdventureEngine.hasPendingAdventureCompletion(hero) ? "Yes" : "No")
                            debugRow("Combat Saved", hero.combatState != nil || hero.currentAdventureState.currentCombatState != nil ? "Yes" : "No")
                        } else {
                            Text("No hero found in this slot.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    section("Ability Implementation Audit") {
                        if let hero {
                            ForEach(hero.abilities) { ability in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(ability.name)
                                            .font(.caption.weight(.semibold))
                                        Text(ability.actionType.rawValue.capitalized)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(AbilityRules.implementationStatus(for: ability).rawValue)
                                        .font(.caption2.weight(.bold))
                                        .multilineTextAlignment(.trailing)
                                }
                            }
                        } else {
                            Text("No hero found in this slot.")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let message {
                        Text(message)
                            .font(.caption.weight(.semibold))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(QuestboundTheme.card)
                            .questboundParchmentText()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
#if DEBUG
            print("[Questbound] DeveloperToolsView opened")
#endif
        }
    }

    private func combatLink(_ title: String, icon: String, encounterID: String, enemyIDs: [String]) -> some View {
        NavigationLink {
            CombatView(slotID: slotID, encounterID: encounterID, title: title, enemyIDs: enemyIDs)
        } label: {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    private func levelButtons(prefix: String, action: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 6) {
            ForEach(1...GameConstants.versionOneLevelCap, id: \.self) { level in
                Button("\(prefix) \(level)") {
                    action(level)
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
        }
    }

    private func toolButton(
        _ title: String,
        icon: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: icon)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.bordered)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
        .font(.caption)
    }
}
