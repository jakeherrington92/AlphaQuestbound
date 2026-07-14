import SwiftUI

struct EquipmentView: View {
    @EnvironmentObject private var saveStore: SaveStore
    let slotID: Int

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Equipment")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 12)

                        equipmentSummary(hero)

                        VStack(spacing: 10) {
                            ForEach(ItemData.equipmentSlots) { slot in
                                NavigationLink {
                                    EquipmentSlotSelectionView(slotID: slotID, slot: slot)
                                } label: {
                                    equipmentSlotRow(slot, hero: hero)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                } else {
                    Text("No hero saved in this slot.")
                        .foregroundStyle(.white)
                        .padding(20)
                }
            }
        }
        .navigationTitle("Equipment")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func equipmentSummary(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Defence")
                .font(.headline)
            Text("\(ItemData.defence(for: hero))")
                .font(.title.bold())
            Text("Calculated from chest armour, shield and Agility modifier.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func equipmentSlotRow(_ slot: EquipmentSlot, hero: Hero) -> some View {
        HStack(spacing: 10) {
            if let itemName = hero.equippedItems.slots[slot],
               let item = ItemData.definition(named: itemName) {
                ItemIconPlaceholder(item: item)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.displayName)
                    .font(.subheadline.weight(.semibold))
                Text(hero.equippedItems.slots[slot] ?? "Empty")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }
}

struct EquipmentSlotSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var saveStore: SaveStore
    @State private var comparisonItem: ItemDefinition?

    let slotID: Int
    let slot: EquipmentSlot

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(slot.displayName)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 12)

                        currentItemCard(hero)

                        ForEach(compatibleCandidates(hero), id: \.name) { item in
                            candidateCard(item, hero: hero)
                        }

                        if canUnequip(hero) {
                            Button(role: .destructive) {
                                let updatedHero = ItemData.unequippedHero(hero, slot: slot)
                                saveStore.updateHero(updatedHero, in: slotID)
                                dismiss()
                            } label: {
                                Label("Unequip \(slot.displayName)", systemImage: "xmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }

                        incompatibleSection(hero)
                    }
                    .padding(20)
                } else {
                    Text("No hero saved in this slot.")
                        .foregroundStyle(.white)
                        .padding(20)
                }
            }
        }
        .navigationTitle(slot.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $comparisonItem) { item in
            ItemComparisonView(slotID: slotID, item: item, initialSlot: slot)
        }
    }

    private func currentItemCard(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current")
                .font(.headline)
            Text(hero.equippedItems.slots[slot] ?? "Empty")
                .foregroundStyle(.secondary)
            Text(currentSlotSummary(hero))
                .font(.caption.weight(.semibold))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func candidateCard(_ item: ItemDefinition, hero: Hero) -> some View {
        let previewHero = ItemData.equippedHero(hero, with: item, in: slot)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ItemIconPlaceholder(item: item)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.rarity.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            comparison(currentHero: hero, previewHero: previewHero, selectedItem: item)

            HStack(spacing: 10) {
                Button {
                    comparisonItem = item
                } label: {
                    Label("Compare", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)

                Button {
                    saveStore.updateHero(previewHero, in: slotID)
                    dismiss()
                } label: {
                    Label("Equip", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
            }
        }
        .padding(16)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func comparison(currentHero: Hero, previewHero: Hero, selectedItem: ItemDefinition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current: \(currentHero.equippedItems.slots[slot] ?? "Empty")")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Selected: \(selectedItem.name)")
                .font(.caption)
            ForEach(quickComparisonLines(currentHero: currentHero, previewHero: previewHero, selectedItem: selectedItem), id: \.self) { line in
                Text(line)
                    .font(.caption)
            }
            Text(requirementsText(selectedItem))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func currentSlotSummary(_ hero: Hero) -> String {
        guard let itemName = hero.equippedItems.slots[slot],
              let item = ItemData.definition(named: itemName) else {
            return "Empty slot"
        }
        switch slot {
        case .mainWeapon, .offHand:
            if item.category == .weapon {
                return "Damage: \(item.damage ?? "None")"
            }
            if item.defenceBonus > 0 {
                return "Defence Bonus: +\(item.defenceBonus)"
            }
            return item.effectText.isEmpty ? "No effect" : "Effect: \(item.effectText)"
        case .chest:
            return "Total Defence: \(ItemData.defence(for: hero))"
        case .head, .hands, .legs, .feet:
            return item.defenceBonus > 0 ? "Defence Bonus: +\(item.defenceBonus)" : "Effect: \(item.effectText)"
        case .charm1, .charm2:
            return item.effectText.isEmpty ? "No effect" : "Effect: \(item.effectText)"
        }
    }

    private func quickComparisonLines(currentHero: Hero, previewHero: Hero, selectedItem: ItemDefinition) -> [String] {
        let currentItem = currentHero.equippedItems.slots[slot].flatMap(ItemData.definition(named:))
        let currentEffect = shortEffect(currentItem)
        let selectedEffect = shortEffect(selectedItem)

        switch slot {
        case .mainWeapon:
            return [
                "Damage: \(currentItem?.damage ?? "Empty Slot") -> \(selectedItem.damage ?? "None")",
                "Effect: \(currentEffect) -> \(selectedEffect)"
            ]
        case .offHand:
            if selectedItem.category == .weapon {
                return [
                    "Damage: \(currentItem?.damage ?? "Empty Slot") -> \(selectedItem.damage ?? "None")",
                    "Effect: \(currentEffect) -> \(selectedEffect)"
                ]
            }
            return [
                "Defence Bonus: \(defenceBonusText(currentItem)) -> \(defenceBonusText(selectedItem))",
                "Effect: \(currentEffect) -> \(selectedEffect)"
            ]
        case .chest:
            return [
                "Defence: \(ItemData.defence(for: currentHero)) -> \(ItemData.defence(for: previewHero))",
                "Effect: \(currentEffect) -> \(selectedEffect)"
            ]
        case .head, .hands, .legs, .feet:
            return [
                "Defence Bonus: \(defenceBonusText(currentItem)) -> \(defenceBonusText(selectedItem))",
                "Effect: \(currentEffect) -> \(selectedEffect)"
            ]
        case .charm1, .charm2:
            return [
                "Effect: \(currentEffect) -> \(selectedEffect)"
            ]
        }
    }

    private func shortEffect(_ item: ItemDefinition?) -> String {
        guard let item else { return "Empty Slot" }
        return item.effectText.isEmpty ? "No extra effect" : item.effectText
    }

    private func defenceBonusText(_ item: ItemDefinition?) -> String {
        guard let item else { return "None" }
        if item.defenceBonus > 0 { return "+\(item.defenceBonus)" }
        if item.defenceBase != nil { return "Base armour" }
        return "None"
    }

    private func incompatibleSection(_ hero: Hero) -> some View {
        let incompatible = inventoryDefinitions(hero).filter { !ItemData.isCompatible($0, with: slot, hero: hero) && !$0.slots.isEmpty }
        return VStack(alignment: .leading, spacing: 8) {
            Text("Incompatible")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(incompatible, id: \.name) { item in
                Text("\(item.name): \(incompatibilityReason(item, hero: hero))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
    }

    private func compatibleCandidates(_ hero: Hero) -> [ItemDefinition] {
        inventoryDefinitions(hero)
            .filter { item in
                ItemData.isCompatible(item, with: slot, hero: hero)
                    && (ItemData.backpackQuantity(item.name, hero: hero) > 0 || hero.equippedItems.slots[slot] == item.name)
            }
            .sorted { $0.name < $1.name }
    }

    private func inventoryDefinitions(_ hero: Hero) -> [ItemDefinition] {
        hero.inventory.itemQuantities.keys.compactMap(ItemData.definition(named:))
    }

    private func canUnequip(_ hero: Hero) -> Bool {
        guard hero.equippedItems.slots[slot] != nil else { return false }
        return slot != .mainWeapon
    }

    private func incompatibilityReason(_ item: ItemDefinition, hero: Hero) -> String {
        if let issue = ItemData.requirementIssue(for: item, hero: hero) {
            return issue
        }
        return "Does not fit \(slot.displayName)."
    }

    private func requirementsText(_ item: ItemDefinition) -> String {
        var parts: [String] = []
        if let levelRequirement = item.levelRequirement {
            parts.append("Level \(levelRequirement)")
        }
        if let pathRequirement = item.pathRequirement {
            parts.append(pathRequirement.rawValue)
        }
        if let subpathRequirement = item.subpathRequirement {
            parts.append(subpathRequirement)
        }
        return parts.isEmpty ? "Requirements: None" : "Requirements: \(parts.joined(separator: ", "))"
    }
}
