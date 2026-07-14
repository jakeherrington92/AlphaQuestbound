import SwiftUI

struct InventoryView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var comparisonItem: ItemDefinition?
    let slotID: Int

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    private let categories: [ItemCategory] = [
        .weapon,
        .armour,
        .charm,
        .consumable,
        .material,
        .miscellaneous,
        .questItem
    ]

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Inventory")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                            .padding(.top, 12)

                        TutorialTipView(tip: .inventory)

                        NavigationLink {
                            EquipmentView(slotID: slotID)
                        } label: {
                            Label("Change Equipment", systemImage: "shield.lefthalf.filled")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(QuestboundTheme.accent)

                        equippedGearSection(hero)

                        Text("Backpack")
                            .font(.title2.bold())
                            .foregroundStyle(.white)

                        ForEach(categories) { category in
                            inventorySection(category, hero: hero)
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
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $comparisonItem) { item in
            ItemComparisonView(slotID: slotID, item: item)
        }
    }

    private func inventorySection(_ category: ItemCategory, hero: Hero) -> some View {
        let itemNames = ItemData.backpackItemNames(in: hero, category: category)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(category.displayName)
                    .font(.headline)
                Spacer()
                if let limit = ItemData.inventoryLimits[category] ?? nil {
                    Text("\(itemCount(itemNames, hero: hero)) / \(limit)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Unlimited")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if itemNames.isEmpty {
                Text("No items in this category yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(itemNames, id: \.self) { itemName in
                    if let item = ItemData.definition(named: itemName) {
                        HStack(spacing: 8) {
                            NavigationLink {
                                ItemDetailView(slotID: slotID, item: item)
                            } label: {
                                inventoryRow(item, quantity: ItemData.backpackQuantity(itemName, hero: hero), hero: hero, isEquippedDisplay: false)
                            }
                            .buttonStyle(.plain)

                            if item.isEquippable {
                                compareIconButton(item)
                            }
                        }
                    }
                }
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

    private func equippedGearSection(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Equipped Gear")
                .font(.headline)
            Text("Equipped gear is protected from selling.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(ItemData.equipmentSlots) { slot in
                if let itemName = hero.equippedItems.slots[slot],
                   let item = ItemData.definition(named: itemName) {
                    HStack(spacing: 8) {
                        NavigationLink {
                            ItemDetailView(slotID: slotID, item: item)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                ItemIconPlaceholder(item: item)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Equipped")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(QuestboundTheme.accent)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        compareIconButton(item)
                    }
                } else {
                    HStack {
                        Text(slot.displayName)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("Empty")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private func inventoryRow(_ item: ItemDefinition, quantity: Int, hero: Hero, isEquippedDisplay: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ItemIconPlaceholder(item: item)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                Text("\(item.name) x\(quantity)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(item.rarity.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isEquippedDisplay {
                    Text("Equipped")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuestboundTheme.accent)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func compareIconButton(_ item: ItemDefinition) -> some View {
        Button {
            comparisonItem = item
        } label: {
            Image(systemName: "info.circle")
                .font(.headline)
                .frame(width: 38, height: 38)
        }
        .buttonStyle(.bordered)
        .tint(QuestboundTheme.accent)
        .accessibilityLabel("Compare \(item.name)")
    }

    private func itemCount(_ itemNames: [String], hero: Hero) -> Int {
        itemNames.reduce(0) { total, itemName in
            total + ItemData.backpackQuantity(itemName, hero: hero)
        }
    }
}

struct ItemIconPlaceholder: View {
    let item: ItemDefinition

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor)
            Image(systemName: iconName)
                .foregroundStyle(.white)
                .font(.headline)
        }
        .frame(width: 42, height: 42)
        .accessibilityLabel(item.iconAssetName)
        .accessibilityHidden(true)
    }

    private var iconName: String {
        switch item.category {
        case .weapon: return "bolt.horizontal"
        case .armour: return "shield"
        case .charm: return "sparkle"
        case .consumable: return "cross.vial"
        case .material: return "shippingbox"
        case .miscellaneous: return "bag"
        case .questItem: return "key"
        }
    }

    private var iconColor: Color {
        switch item.category {
        case .weapon: return Color(red: 0.48, green: 0.20, blue: 0.18)
        case .armour: return Color(red: 0.30, green: 0.34, blue: 0.38)
        case .charm: return Color(red: 0.25, green: 0.36, blue: 0.56)
        case .consumable: return Color(red: 0.52, green: 0.18, blue: 0.24)
        case .material: return Color(red: 0.35, green: 0.38, blue: 0.24)
        case .miscellaneous: return Color(red: 0.42, green: 0.28, blue: 0.16)
        case .questItem: return Color(red: 0.50, green: 0.38, blue: 0.12)
        }
    }
}
