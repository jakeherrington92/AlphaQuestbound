import SwiftUI

struct ItemDetailView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var comparisonItem: ItemDefinition?

    let slotID: Int
    let item: ItemDefinition

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    detailCard
                    if item.isEquippable {
                        compareButton(item)
                    }
                    if let hero, item.isEquippable {
                        equipLinks(hero)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $comparisonItem) { item in
            ItemComparisonView(slotID: slotID, item: item)
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            ItemIconPlaceholder(item: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("\(item.rarity.displayName) • \(item.category.displayName)")
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .padding(.top, 12)
    }

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            detailRow("Rarity", item.rarity.displayName)
            detailRow("Category", item.category.displayName)
            detailRow("Slot", item.slots.isEmpty ? "None" : item.slots.map(\.displayName).joined(separator: ", "))
            if let damage = item.damage {
                detailRow("Damage", damage)
            }
            if item.defenceBase != nil || item.defenceBonus > 0 {
                detailRow("Defence", defenceText)
            }
            detailRow("Effects", item.effectText)
            if ItemData.staminaDraughtNames.contains(item.name) {
                detailRow(
                    "Adventure Limit",
                    "Only \(GameConstants.maxStaminaDraughtUsesPerAdventure) Stamina Draughts can be used per adventure."
                )
                if hero?.maxStamina == 0 {
                    Text("Useful for heroes who use Stamina.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            detailRow("Value", "\(item.value) gold")
            detailRow("Sellable", item.isSellable && item.category != .questItem ? "Yes" : "No")
            detailRow("Estimated Sell Value", ItemData.estimatedSellValue(for: item))
            if item.category == .questItem {
                detailRow("Sell Note", "Cannot be sold.")
            }
            detailRow("Crafting Use", ItemData.craftingUseText(for: item))
            detailRow("Level Requirement", item.levelRequirement.map(String.init) ?? "None")
            detailRow("Path Requirement", item.pathRequirement?.rawValue ?? "None")
            detailRow("Subpath Requirement", item.subpathRequirement ?? "None")
            Divider()
            Text("Build Fit")
                .font(.headline)
            detailRow("Recommended for", ItemData.recommendedForText(for: item))
            detailRow("Build style", ItemData.buildStyleText(for: item))
            if !item.subpathTags.isEmpty {
                detailRow("Subpath", item.subpathTags.joined(separator: ", "))
            }
            if let hero {
                Text(ItemData.buildFitSummary(for: item, hero: hero))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(QuestboundTheme.accent)
                detailRow("Equipped", ItemData.isEquipped(item.name, hero: hero) ? "Yes" : "No")
                if item.isEquippable {
                    detailRow("Sellable Copy Available", ItemData.backpackQuantity(item.name, hero: hero) > 0 ? "Yes, x\(ItemData.backpackQuantity(item.name, hero: hero))" : "No")
                    if ItemData.isEquipped(item.name, hero: hero) {
                        Text("Equipped gear is protected from selling.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            if item.category == .material {
                Text("Materials can be sold in Version 1, but may be used for crafting and upgrades in future versions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

    private func equipLinks(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Equip")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(item.slots) { slot in
                if ItemData.isCompatible(item, with: slot, hero: hero) {
                    Button {
                        let updatedHero = ItemData.equippedHero(hero, with: item, in: slot)
                        saveStore.updateHero(updatedHero, in: slotID)
                    } label: {
                        Label("Equip to \(slot.displayName)", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(QuestboundTheme.accent)
                } else {
                    Text("\(slot.displayName): \(ItemData.requirementIssue(for: item, hero: hero) ?? "Incompatible")")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }
        }
    }

    private func compareButton(_ item: ItemDefinition) -> some View {
        Button {
            comparisonItem = item
        } label: {
            Label("Compare Gear", systemImage: "info.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(QuestboundTheme.accent)
    }

    private var defenceText: String {
        if let defenceBase = item.defenceBase {
            if let agilityModifierCap = item.agilityModifierCap {
                return "\(defenceBase) + Agility modifier, max +\(agilityModifierCap)"
            }
            return "\(defenceBase) + full Agility modifier"
        }
        return "+\(item.defenceBonus) Defence"
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
}

struct ItemComparisonView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: EquipmentSlot?

    let slotID: Int
    let item: ItemDefinition
    let initialSlot: EquipmentSlot?

    init(slotID: Int, item: ItemDefinition, initialSlot: EquipmentSlot? = nil) {
        self.slotID = slotID
        self.item = item
        self.initialSlot = initialSlot
    }

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    private var targetSlot: EquipmentSlot? {
        selectedSlot ?? hero.flatMap { ItemComparisonHelper.defaultComparisonSlot(for: item, hero: $0) }
    }

    private var equippedItem: ItemDefinition? {
        guard let hero, let targetSlot, let equippedName = hero.equippedItems.slots[targetSlot] else { return nil }
        return ItemData.definition(named: equippedName)
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()
            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Compare Gear")
                            .font(.title2.bold())
                        comparisonHeader(hero)
                        if item.category == .charm, charmSlotsAreFull(hero) {
                            charmSlotPicker(hero)
                        }
                        comparisonRows(hero)
                        equipControls(hero)
                    }
                    .padding(20)
                }
            }
        }
        .onAppear {
            if selectedSlot == nil, let hero {
                selectedSlot = initialSlot ?? ItemComparisonHelper.defaultComparisonSlot(for: item, hero: hero)
            }
        }
    }

    private func comparisonHeader(_ hero: Hero) -> some View {
        comparisonCard {
            ItemDetailHeader(item: item)
            detailRow("Slot", targetSlot?.displayName ?? item.slots.map(\.displayName).joined(separator: ", "))
            detailRow("Compared With", equippedItem?.name ?? "Empty \(targetSlot?.displayName ?? "Slot")")
            detailRow("Build Fit", ItemData.buildFitSummary(for: item, hero: hero))
            if let issue = ItemData.requirementIssue(for: item, hero: hero) {
                detailRow("Compatibility", issue)
            }
        }
    }

    private func charmSlotPicker(_ hero: Hero) -> some View {
        comparisonCard {
            Text("Charm Slot")
                .font(.headline)
            Picker("Charm Slot", selection: Binding(
                get: { selectedSlot ?? .charm1 },
                set: { selectedSlot = $0 }
            )) {
                Text("Charm 1").tag(EquipmentSlot.charm1)
                Text("Charm 2").tag(EquipmentSlot.charm2)
            }
            .pickerStyle(.segmented)
            detailRow("Charm 1", hero.equippedItems.slots[.charm1] ?? "Empty Charm Slot")
            detailRow("Charm 2", hero.equippedItems.slots[.charm2] ?? "Empty Charm Slot")
        }
    }

    private func comparisonRows(_ hero: Hero) -> some View {
        comparisonCard {
            Text("Comparison")
                .font(.headline)
            compareRow("Rarity", ItemComparisonHelper.rarityResult(item, equippedItem), detail: "\(item.rarity.displayName) vs \(equippedItem?.rarity.displayName ?? "Empty")")
            if item.category == .weapon {
                compareRow("Damage", ItemComparisonHelper.damageResult(item, equippedItem), detail: ItemComparisonHelper.damageDetail(item, equippedItem))
            }
            if item.category == .armour {
                compareRow("Defence", ItemComparisonHelper.defenceResult(item, equippedItem, hero: hero), detail: ItemComparisonHelper.defenceDetail(item, equippedItem, hero: hero))
            }
            compareRow("Effect", ItemComparisonHelper.effectResult(item, equippedItem), detail: ItemComparisonHelper.effectDetail(item, equippedItem))
            compareRow("Requirements", ItemComparisonHelper.requirementResult(item, equippedItem), detail: ItemComparisonHelper.requirementDetail(item, equippedItem))
            compareRow("Value", ItemComparisonHelper.valueResult(item, equippedItem), detail: "\(item.value)g vs \(equippedItem?.value ?? 0)g")
        }
    }

    private func equipControls(_ hero: Hero) -> some View {
        comparisonCard {
            if ItemData.isEquipped(item.name, hero: hero), ItemData.backpackQuantity(item.name, hero: hero) == 0 {
                Text("Already Equipped")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    equip(hero)
                } label: {
                    Text("Equip This Item")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(equipIssue(hero) != nil)
                if let issue = equipIssue(hero) {
                    Text(issue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
    }

    private func equip(_ hero: Hero) {
        guard let targetSlot, equipIssue(hero) == nil else { return }
        saveStore.updateHero(ItemData.equippedHero(hero, with: item, in: targetSlot), in: slotID)
        dismiss()
    }

    private func equipIssue(_ hero: Hero) -> String? {
        guard let targetSlot else { return "No compatible slot." }
        if let issue = ItemData.requirementIssue(for: item, hero: hero) { return issue }
        guard ItemData.isCompatible(item, with: targetSlot, hero: hero) else { return "Does not fit \(targetSlot.displayName)." }
        guard ItemData.backpackQuantity(item.name, hero: hero) > 0 || hero.equippedItems.slots[targetSlot] == item.name else {
            return "Item is not in Backpack."
        }
        return nil
    }

    private func charmSlotsAreFull(_ hero: Hero) -> Bool {
        hero.equippedItems.slots[.charm1] != nil && hero.equippedItems.slots[.charm2] != nil
    }

    @ViewBuilder
    private func compareRow(_ label: String, _ result: ItemComparisonResult, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .top) {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(result.text)
                    .fontWeight(.semibold)
                    .foregroundStyle(result.color)
                    .multilineTextAlignment(.trailing)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        Divider()
    }

    private func comparisonCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
}

struct ItemComparisonResult {
    var text: String
    var color: Color

    static let higher = ItemComparisonResult(text: "↑ Higher / Better", color: .green)
    static let same = ItemComparisonResult(text: "– Same", color: .secondary)
    static let lower = ItemComparisonResult(text: "↓ Lower / Worse", color: .red)
    static let none = ItemComparisonResult(text: "None", color: .secondary)
    static let different = ItemComparisonResult(text: "Different", color: .secondary)
    static let notApplicable = ItemComparisonResult(text: "N/A", color: .secondary)
}

enum ItemComparisonHelper {
    static func defaultComparisonSlot(for item: ItemDefinition, hero: Hero) -> EquipmentSlot? {
        if item.category == .charm {
            if hero.equippedItems.slots[.charm1] == nil { return .charm1 }
            if hero.equippedItems.slots[.charm2] == nil { return .charm2 }
            return .charm1
        }
        return ItemData.upgradePromptSlot(for: item, hero: hero)
    }

    static func rarityResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> ItemComparisonResult {
        guard let equipped else { return .higher }
        return compare(rank(selected.rarity), rank(equipped.rarity))
    }

    static func damageResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> ItemComparisonResult {
        guard selected.category == .weapon else { return .notApplicable }
        guard let selectedAverage = averageDamage(selected.damage) else { return .notApplicable }
        guard let equippedAverage = averageDamage(equipped?.damage) else { return .higher }
        return compare(selectedAverage, equippedAverage)
    }

    static func damageDetail(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> String {
        guard selected.category == .weapon else { return "N/A" }
        return "\(selected.damage ?? "None") vs \(equipped?.damage ?? "Empty Slot")"
    }

    static func defenceResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?, hero: Hero) -> ItemComparisonResult {
        guard selected.category == .armour else { return .notApplicable }
        let selectedDefence = defenceContribution(selected, hero: hero)
        let equippedDefence = equipped.map { defenceContribution($0, hero: hero) } ?? 0
        return compare(selectedDefence, equippedDefence)
    }

    static func defenceDetail(_ selected: ItemDefinition, _ equipped: ItemDefinition?, hero: Hero) -> String {
        guard selected.category == .armour else { return "N/A" }
        let selectedDefence = defenceContribution(selected, hero: hero)
        let equippedDefence = equipped.map { defenceContribution($0, hero: hero) } ?? 0
        let delta = selectedDefence - equippedDefence
        let selectedText = "Selected: \(defenceFormula(selected))"
        let equippedText = "Equipped: \(equipped.map(defenceFormula) ?? "Empty Slot")"
        let resultText: String
        if delta > 0 {
            resultText = "+\(delta) Defence"
        } else if delta < 0 {
            resultText = "\(delta) Defence"
        } else {
            resultText = "Same"
        }
        return "\(selectedText). \(equippedText). Result: \(resultText)."
    }

    static func effectResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> ItemComparisonResult {
        let selectedEffect = normalizedEffect(playerEffectText(for: selected))
        let equippedEffect = normalizedEffect(equipped.map(playerEffectText(for:)) ?? "")
        if selectedEffect.isEmpty && equippedEffect.isEmpty {
            return .none
        }
        if !selectedEffect.isEmpty && equippedEffect.isEmpty { return .higher }
        if selectedEffect.isEmpty && !equippedEffect.isEmpty { return .lower }
        if selectedEffect == equippedEffect { return .same }
        return .different
    }

    static func effectDetail(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> String {
        let selectedEffect = playerEffectText(for: selected)
        let equippedEffect = equipped.map(playerEffectText(for:)) ?? ""
        let selectedText = normalizedEffect(selectedEffect).isEmpty ? "Selected: No extra effect" : "Selected: \(selectedEffect)"
        let equippedText = normalizedEffect(equippedEffect).isEmpty ? "Equipped: No extra effect" : "Equipped: \(equippedEffect)"
        return "\(selectedText). \(equippedText)."
    }

    static func requirementResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> ItemComparisonResult {
        requirementDetail(selected, equipped).contains("Same") ? .same : .different
    }

    static func requirementDetail(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> String {
        let selectedText = requirementText(selected)
        let equippedText = equipped.map(requirementText) ?? "None"
        let resultText = selectedText == equippedText ? "Same" : "Different"
        return "Selected: \(selectedText). Equipped: \(equippedText). Result: \(resultText)."
    }

    static func valueResult(_ selected: ItemDefinition, _ equipped: ItemDefinition?) -> ItemComparisonResult {
        compare(selected.value, equipped?.value ?? 0)
    }

    private static func compare<T: Comparable>(_ selected: T, _ equipped: T) -> ItemComparisonResult {
        if selected > equipped { return .higher }
        if selected < equipped { return .lower }
        return .same
    }

    private static func rank(_ rarity: Rarity) -> Int {
        Rarity.allCases.firstIndex(of: rarity) ?? 0
    }

    private static func defenceContribution(_ item: ItemDefinition, hero: Hero) -> Int {
        if let defenceBase = item.defenceBase {
            let agility = hero.attributes.modifier(for: .agility)
            return defenceBase + min(agility, item.agilityModifierCap ?? agility)
        }
        return item.defenceBonus
    }

    private static func defenceFormula(_ item: ItemDefinition) -> String {
        if let defenceBase = item.defenceBase {
            if let agilityModifierCap = item.agilityModifierCap {
                if agilityModifierCap == 0 {
                    return "Defence \(defenceBase)"
                }
                return "Defence \(defenceBase) + Agility modifier, max +\(agilityModifierCap)"
            }
            return "Defence \(defenceBase) + full Agility modifier"
        }
        if item.defenceBonus > 0 {
            return "+\(item.defenceBonus) Defence"
        }
        return "No Defence"
    }

    private static func averageDamage(_ damage: String?) -> Double? {
        guard var damage else { return nil }
        damage = damage
            .lowercased()
            .components(separatedBy: "/")
            .first?
            .replacingOccurrences(of: "physical", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !damage.isEmpty else { return nil }
        return damage.split(separator: "+").reduce(0.0) { total, rawPart in
            let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
            if part.contains("d") {
                let pieces = part.split(separator: "d")
                let count = pieces.first.flatMap { Double($0) } ?? 1
                let die = pieces.dropFirst().first.flatMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) } ?? 0
                return total + count * ((die + 1) / 2)
            }
            return total + (Double(part) ?? 0)
        }
    }

    private static func normalizedEffect(_ effect: String) -> String {
        let trimmed = effect.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.localizedCaseInsensitiveContains("no effect") {
            return ""
        }
        return trimmed.lowercased()
    }

    private static func playerEffectText(for item: ItemDefinition) -> String {
        let formulaFragments = [
            "Defence 10 + full Agility modifier",
            "Defence 11 + full Agility modifier",
            "Defence 13 + Agility modifier, maximum +2",
            "Defence 16",
            "+2 Defence"
        ]
        let flavorOnly = [
            "Reliable melee weapon",
            "Worn but usable",
            "Simple chopping weapon",
            "Plain blunt weapon",
            "Light and easy to conceal",
            "Reach weapon for hunters and guards",
            "Simple walking staff pressed into combat",
            "A simple oathbound blade",
            "Basic hand protection",
            "Plain travel wear",
            "Basic foot protection"
        ]

        let parts = item.effectText
            .split(separator: ".")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { part in
                guard !part.isEmpty else { return false }
                if formulaFragments.contains(where: { part.localizedCaseInsensitiveContains($0) }) {
                    return false
                }
                if flavorOnly.contains(where: { part.localizedCaseInsensitiveContains($0) }) {
                    return false
                }
                return true
            }

        return parts.joined(separator: ". ")
    }

    private static func requirementText(_ item: ItemDefinition) -> String {
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
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}
