import SwiftUI

struct CharacterSheetPreviewView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var selectedAttribute: AttributeType?

    let slotID: Int

    private var hero: HeroProfile? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        header(hero)
                        helpCard
                        progressionCard(hero)
                        identityCard(hero)
                        resourcesCard(hero)
                        attributesCard(hero)
                        skillsCard(hero)
                        abilitiesCard(hero)
                        equipmentCard(hero)
                        inventoryCard(hero)
                        completedAdventuresCard(hero)
                    }
                    .padding(20)
                } else {
                    Text("No hero saved in this slot.")
                        .foregroundStyle(.white)
                        .padding(20)
                }
            }
        }
        .navigationTitle("Character Sheet")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $selectedAttribute) { attribute in
            Alert(
                title: Text(attribute.displayName),
                message: Text(attribute.usageDescription),
                dismissButton: .default(Text("Done"))
            )
        }
    }

    private func header(_ hero: Hero) -> some View {
        HStack(spacing: 14) {
            PortraitBadge(option: hero.portrait)
            VStack(alignment: .leading, spacing: 4) {
                Text(hero.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Level \(hero.level) \(hero.path.rawValue)")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.top, 12)
    }

    private func identityCard(_ hero: Hero) -> some View {
        sheetCard("Identity") {
            detailRow("Origin", hero.origin.rawValue)
            detailRow("Origin Feature", originFeatureText(hero))
            detailRow("Path", hero.path.rawValue)
            if let subpath = hero.subpath, !subpath.isEmpty {
                detailRow("Subpath", subpath)
            }
        }
    }

    private var helpCard: some View {
        sheetCard("Help") {
            Text("Tap attributes to see what they affect. Tap abilities for detail text. Defence is recalculated from equipped armour, shield bonuses and Agility rules.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func progressionCard(_ hero: Hero) -> some View {
        sheetCard("Progression") {
            if LevelUpEngine.pendingNextLevel(for: hero) != nil {
                Text("Unused attribute increase or level-up choices may be available during the normal level-up flow.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    LevelUpFlowView(slotID: slotID)
                } label: {
                    Label("Level Up", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
            }

            if hero.level >= 3, hero.selectedSubpath == nil {
                Text("Subpath selection is required before Subpath abilities can be assigned.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                NavigationLink {
                    DeveloperSubpathSelectionView(slotID: slotID)
                } label: {
                    Label("Choose Subpath", systemImage: "point.3.connected.trianglepath.dotted")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
            }

            #if DEBUG
            NavigationLink {
                DeveloperAttributeRespecView(slotID: slotID)
            } label: {
                Label("Developer Respec Attributes", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(QuestboundTheme.accent)
            #endif

            if LevelUpEngine.pendingNextLevel(for: hero) == nil,
               !(hero.level >= 3 && hero.selectedSubpath == nil) {
                Text(hero.level >= GameConstants.versionOneLevelCap ? "Version 1 level cap reached." : "No progression choices are waiting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func resourcesCard(_ hero: Hero) -> some View {
        sheetCard("Resources") {
            detailRow("Level", "\(hero.level)")
            detailRow("XP", "\(hero.xp)")
            detailRow("Gold", "\(hero.gold)")
            detailRow("HP", "\(hero.currentHealth) / \(hero.maxHealth)")
            if hero.maxFocus > 0 {
                detailRow("Focus", "\(hero.currentFocus) / \(hero.maxFocus)")
            }
            if hero.maxStamina > 0 {
                detailRow("Stamina", "\(hero.currentStamina) / \(hero.maxStamina)")
            }
            detailRow("Defence", "\(ItemData.defence(for: hero))")
            detailRow("Training Bonus", "+\(ProgressionRules.versionOne.trainingBonus(for: hero.level) ?? 0)")
        }
    }

    private func attributesCard(_ hero: Hero) -> some View {
        sheetCard("Attributes") {
            ForEach(AttributeType.allCases) { attribute in
                Button {
                    selectedAttribute = attribute
                } label: {
                    HStack {
                        Label(attribute.displayName, systemImage: "info.circle")
                        Spacer()
                        Text("\(hero.attributes.score(for: attribute)) (\(signed(hero.attributes.modifier(for: attribute))))")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.plain)
                if attribute != AttributeType.allCases.last {
                    Divider()
                }
            }
        }
    }

    private func skillsCard(_ hero: Hero) -> some View {
        sheetCard("Trained Skills") {
            if hero.trainedSkills.isEmpty {
                Text("No trained skills saved.")
                    .foregroundStyle(.secondary)
            } else {
                Text(hero.trainedSkills.map(\.displayName).joined(separator: ", "))
            }
        }
    }

    private func abilitiesCard(_ hero: Hero) -> some View {
        sheetCard("Unlocked Abilities") {
            if hero.abilities.isEmpty {
                Text("No abilities saved.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("All unlocked Version 1 combat abilities are currently available in battle. A future loadout screen can let you equip or swap active abilities when the ability pool grows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(hero.abilities) { ability in
                        NavigationLink {
                            AbilityDetailView(ability: ability)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ability.name)
                                        .fontWeight(.semibold)
                                    Text(ability.actionType.rawValue.capitalized)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(AbilityRules.availabilityText(for: ability, state: nil, hero: hero))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func equipmentCard(_ hero: Hero) -> some View {
        sheetCard("Equipped Items") {
            NavigationLink {
                EquipmentView(slotID: slotID)
            } label: {
                Label("Change Equipment", systemImage: "shield.lefthalf.filled")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            if hero.equippedItems.slots.isEmpty {
                Text("No equipped items saved.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hero.equippedItems.slots.sorted(by: { $0.key.rawValue < $1.key.rawValue }), id: \.key) { slot, itemName in
                    detailRow(slot.displayName, itemName)
                }
            }
        }
    }

    private func inventoryCard(_ hero: Hero) -> some View {
        sheetCard("Inventory Summary") {
            if hero.inventory.itemQuantities.isEmpty {
                Text("No inventory items saved.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hero.inventory.itemQuantities.sorted(by: { $0.key < $1.key }), id: \.key) { itemName, quantity in
                    detailRow(itemName, "x\(quantity)")
                }
            }
        }
    }

    private func completedAdventuresCard(_ hero: Hero) -> some View {
        sheetCard("Completed Adventures") {
            let completed = hero.currentAdventureState.completedAdventureIDs.sorted()
            if completed.isEmpty {
                Text("None yet.")
                    .foregroundStyle(.secondary)
            } else {
                Text(completed.joined(separator: ", "))
            }
        }
    }

    private func sheetCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func originFeatureText(_ hero: Hero) -> String {
        guard let feature = hero.originFeature else { return "Not saved" }
        return "\(feature.name): \(feature.summary)"
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
