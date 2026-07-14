import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var selectedTab: ShopTab = .buy
    @State private var message: String?
    @State private var showRestockConfirm = false
    @State private var categoryFilter: ShopCategoryFilter = .all
    @State private var rarityFilter: ShopRarityFilter = .all
    @State private var pathFilter: ShopPathFilter = .all
    @State private var subpathFilter: ShopSubpathFilter = .all
    @State private var recommendedOnly = false
    @State private var sellSelectionMode = false
    @State private var selectedSellItems: Set<String> = []
    @State private var selectedSellQuantities: [String: Int] = [:]
    @State private var showMultiSellConfirmation = false
    @State private var skipNormalSellWarningChoice = false

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
                        header(hero)
                        TutorialTipView(tip: .shop)
                        eventControls
                        Picker("Shop Tab", selection: $selectedTab) {
                            ForEach(ShopTab.allCases) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)

                        if selectedTab == .buy {
                            buyTab(hero)
                        } else {
                            sellTab(hero)
                        }

                        if let message {
                            Text(message)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
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
        .navigationTitle("Greywick Shop")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Manual Restock?", isPresented: $showRestockConfirm) {
            Button("Restock") {
                guard let hero else { return }
                if let error = saveStore.restockShop(for: slotID, heroLevel: hero.level) {
                    message = error
                } else {
                    message = "Shop stock refreshed."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Spend \(saveStore.nextRestockCost) gold to refresh shop stock now? The shop will also refresh for free after your next completed adventure. Manual restock prices reset after a completed adventure.")
        }
        .sheet(isPresented: $showMultiSellConfirmation) {
            if let hero {
                MultiSellConfirmationView(
                    lines: selectedSellLines(hero),
                    totalGold: selectedSellTotal(hero),
                    showsNormalSkipToggle: !multiSellHasForcedWarning(hero),
                    skipNormalWarning: $skipNormalSellWarningChoice
                ) {
                    performMultiSell(updateSkipPreference: skipNormalSellWarningChoice)
                } onCancel: {
                    showMultiSellConfirmation = false
                }
            }
        }
    }

    private func header(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Greywick Shop")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
                .padding(.top, 12)

            shopCard {
                detailRow("Gold", "\(hero.gold)")
                detailRow("Hero Level", "\(hero.level)")
            }

            shopCard {
                Text("Shop Refresh")
                    .font(.headline)
                detailRow("Next Natural Refresh", "After your next completed adventure")
                detailRow(
                    "Manual Restocks",
                    "\(saveStore.shopState.manualRestocksUsed) / \(GameConstants.maxManualRestocks) used"
                )
                detailRow("Restocks Remaining", "\(saveStore.restocksRemaining)")
                detailRow(
                    "Next Restock Cost",
                    saveStore.restocksRemaining > 0 ? "\(saveStore.nextRestockCost) gold" : "Unavailable"
                )

                Divider()
                Text(shopEventStatus)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Manual restock uses reset after you complete an adventure.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showRestockConfirm = true
                } label: {
                    Label(manualRestockButtonTitle, systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
                .disabled(saveStore.restocksRemaining == 0)

                if saveStore.restocksRemaining == 0 {
                    Text("Manual Restock unavailable until you complete an adventure.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuestboundTheme.accent)
                } else if hero.gold < saveStore.nextRestockCost {
                    Text("Not enough gold to restock.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuestboundTheme.accent)
                }
            }
        }
    }

    private var manualRestockButtonTitle: String {
        guard saveStore.restocksRemaining > 0 else { return "Manual Restock Unavailable" }
        return "Manual Restock — \(saveStore.nextRestockCost) gold"
    }

    private var shopEventStatus: String {
        guard let event = saveStore.shopState.activeEvent else {
            return "No active shop event."
        }
        switch event.type {
        case .sale:
            return "\(event.name) active. This lasts until your next completed adventure."
        case .merchantDemand:
            return "Merchant Demand active. Gear sells for \(event.sellPercentOverride ?? GameConstants.merchantDemandSellPercent)% until your next completed adventure."
        }
    }

    private var eventControls: some View {
        shopCard {
            DisclosureGroup {
                Text("Test-only controls for sale and demand event QA.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("25%") {
                        saveStore.setShopEvent(.sale25)
                        message = "25% Sale event active."
                    }
                    Button("35%") {
                        saveStore.setShopEvent(.sale35)
                        message = "35% Sale event active."
                    }
                    Button("50%") {
                        saveStore.setShopEvent(.sale50)
                        message = "50% Sale event active."
                    }
                    Button("Demand") {
                        saveStore.setShopEvent(.merchantDemand)
                        message = "Merchant Demand active."
                    }
                    Button("Clear") {
                        saveStore.setShopEvent(nil)
                        message = "Shop event cleared."
                    }
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
            } label: {
                Label("Developer Test Tools", systemImage: "hammer")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func buyTab(_ hero: Hero) -> some View {
        shopCard {
            Text("Buy")
                .font(.headline)
            buyFilters(hero)

            let items = filteredStockItems(hero)
            if items.isEmpty {
                Text("No items match these filters.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.name) { item in
                    NavigationLink {
                        ShopItemDetailView(slotID: slotID, item: item, mode: .buy)
                    } label: {
                        shopItemRow(item, hero: hero, mode: .buy)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func buyFilters(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Recommended for My Hero", isOn: $recommendedOnly)
                .font(.subheadline.weight(.semibold))
                .tint(QuestboundTheme.accent)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                filterPicker("Category", selection: $categoryFilter, values: ShopCategoryFilter.allCases)
                filterPicker("Rarity", selection: $rarityFilter, values: ShopRarityFilter.allCases)
                filterPicker("Path", selection: $pathFilter, values: ShopPathFilter.allCases)
                filterPicker("Subpath", selection: $subpathFilter, values: ShopSubpathFilter.allCases)
            }

            if filtersAreActive {
                Button {
                    categoryFilter = .all
                    rarityFilter = .all
                    pathFilter = .all
                    subpathFilter = .all
                    recommendedOnly = false
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var filtersAreActive: Bool {
        categoryFilter != .all || rarityFilter != .all || pathFilter != .all || subpathFilter != .all || recommendedOnly
    }

    private func filterPicker<T: ShopFilterOption>(_ title: String, selection: Binding<T>, values: [T]) -> some View {
        Menu {
            Picker(title, selection: selection) {
                ForEach(values) { value in
                    Text(value.displayName).tag(value)
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selection.wrappedValue.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(QuestboundTheme.background.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(QuestboundTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func sellTab(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            shopCard {
                Text("Equipped Gear")
                    .font(.headline)
                Text("Equipped — protected. Unequip gear or sell spare copies from Backpack.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(ItemData.equipmentSlots) { slot in
                    if let itemName = hero.equippedItems.slots[slot],
                       let item = ItemData.definition(named: itemName) {
                        NavigationLink {
                            ShopItemDetailView(slotID: slotID, item: item, mode: .sell)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                ItemIconPlaceholder(item: item)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(slot.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Text(item.name)
                                        .font(.subheadline.weight(.semibold))
                                    Text("Equipped — protected")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(QuestboundTheme.accent)
                                }
                                Spacer()
                                Text("No sell controls")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            sellSelectionControls(hero)

            Text("Backpack / Available to Sell")
                .font(.title3.bold())
                .foregroundStyle(.white)

            ForEach(sellCategories) { category in
                shopCard {
                    Text(category.displayName)
                        .font(.headline)
                    if category == .material {
                        Text("Materials can be sold in Version 1, but may be used for crafting and upgrades in future versions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    let names = ItemData.backpackItemNames(in: hero, category: category)
                        .filter { name in
                            guard let item = ItemData.definition(named: name) else { return false }
                            return item.isSellable && item.category != .questItem
                        }
                    if names.isEmpty {
                        Text("No backpack items available to sell in this category.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(names, id: \.self) { name in
                            if let item = ItemData.definition(named: name) {
                                if sellSelectionMode {
                                    multiSellItemRow(item, hero: hero)
                                } else {
                                    NavigationLink {
                                        ShopItemDetailView(slotID: slotID, item: item, mode: .sell)
                                    } label: {
                                        shopItemRow(item, hero: hero, mode: .sell)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func sellSelectionControls(_ hero: Hero) -> some View {
        shopCard {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Multi-Select Selling")
                        .font(.headline)
                    Text(sellSelectionMode ? "\(selectedSellItems.count) item types selected • \(selectedSellTotal(hero)) gold" : "Select several backpack items and sell them together.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(sellSelectionMode ? "Cancel Selection" : "Select Items to Sell") {
                    if sellSelectionMode {
                        clearSellSelection()
                        sellSelectionMode = false
                    } else {
                        sellSelectionMode = true
                    }
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
            }

            if sellSelectionMode {
                HStack {
                    Button("Select All Sellable") {
                        selectAllSellable(hero)
                    }
                    Button("Clear Selection") {
                        clearSellSelection()
                    }
                    .disabled(selectedSellItems.isEmpty)
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)

                Button(role: .destructive) {
                    startMultiSell(hero)
                } label: {
                    Label("Sell Selected", systemImage: "tray.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSellItems.isEmpty)
            }
        }
    }

    private func multiSellItemRow(_ item: ItemDefinition, hero: Hero) -> some View {
        let backpackQuantity = ItemData.backpackQuantity(item.name, hero: hero)
        let isSelected = selectedSellItems.contains(item.name)
        let quantity = selectedQuantity(for: item, hero: hero)
        let totalValue = saveStore.sellValue(for: item) * quantity

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    toggleSellSelection(item, hero: hero)
                } label: {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(isSelected ? QuestboundTheme.accent : .secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)

                ItemIconPlaceholder(item: item)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(item.name) x\(backpackQuantity)")
                        .font(.subheadline.weight(.semibold))
                    Text("\(item.rarity.displayName) • \(item.category.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.effectText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if ItemData.isEquipped(item.name, hero: hero) {
                        Text("Equipped copy protected; backpack x\(backpackQuantity) selectable.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(QuestboundTheme.accent)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(saveStore.sellValue(for: item))g each")
                        .font(.subheadline.weight(.bold))
                    if isSelected {
                        Text("\(totalValue)g total")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if isSelected {
                HStack(spacing: 10) {
                    Text("Sell Quantity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button {
                        setSelectedQuantity(max(1, quantity - 1), for: item, hero: hero)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(quantity <= 1)

                    Text("\(quantity)")
                        .font(.headline)
                        .frame(minWidth: 34)

                    Button {
                        setSelectedQuantity(min(backpackQuantity, quantity + 1), for: item, hero: hero)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .disabled(quantity >= backpackQuantity)

                    Spacer()
                }
            }
        }
        .padding(10)
        .background(isSelected ? QuestboundTheme.accent.opacity(0.15) : QuestboundTheme.cardText.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? QuestboundTheme.accent : QuestboundTheme.border, lineWidth: 1)
        }
    }

    private func shopItemRow(_ item: ItemDefinition, hero: Hero, mode: ShopMode) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ItemIconPlaceholder(item: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                if mode == .sell {
                    Text("\(item.name) x\(ItemData.backpackQuantity(item.name, hero: hero))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("\(item.rarity.displayName) • \(item.category.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.effectText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if mode == .sell, ItemData.isEquipped(item.name, hero: hero) {
                    Text("Spare copy in Backpack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuestboundTheme.accent)
                } else if ItemData.isEquipped(item.name, hero: hero) {
                    Text("Equipped")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(QuestboundTheme.accent)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(mode == .buy ? "\(saveStore.buyPrice(for: item))g" : "\(saveStore.sellValue(for: item))g")
                    .font(.subheadline.weight(.bold))
                if mode == .buy, let discount = saveStore.shopState.activeEvent?.discountPercent {
                    Text("-\(discount)%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func stockItems(_ hero: Hero) -> [ItemDefinition] {
        let stockNames = saveStore.shopState.stockItemIDs.isEmpty
            ? ItemData.startingItems.map(\.name)
            : saveStore.shopState.stockItemIDs
        return stockNames
            .compactMap(ItemData.definition(named:))
            .filter { item in
                guard item.rarity == .epic, item.subpathRequirement != nil else { return true }
                return hero.level >= 3 && item.subpathRequirement == hero.subpath
            }
    }

    private func filteredStockItems(_ hero: Hero) -> [ItemDefinition] {
        stockItems(hero).filter { item in
            categoryFilter.matches(item)
                && rarityFilter.matches(item)
                && pathFilter.matches(item, hero: hero)
                && subpathFilter.matches(item)
                && (!recommendedOnly || isRecommended(item, for: hero))
        }
    }

    private func isRecommended(_ item: ItemDefinition, for hero: Hero) -> Bool {
        ItemData.isRecommendedFor(hero: hero, item: item)
    }

    private var sellCategories: [ItemCategory] {
        [.weapon, .armour, .charm, .consumable, .material, .miscellaneous, .questItem]
    }

    private func allSellableBackpackItems(_ hero: Hero) -> [ItemDefinition] {
        sellCategories
            .flatMap { category in
                ItemData.backpackItemNames(in: hero, category: category)
            }
            .compactMap(ItemData.definition(named:))
            .filter { $0.isSellable && $0.category != .questItem && ItemData.backpackQuantity($0.name, hero: hero) > 0 }
    }

    private func selectedQuantity(for item: ItemDefinition, hero: Hero) -> Int {
        let maximum = max(1, ItemData.backpackQuantity(item.name, hero: hero))
        return min(max(1, selectedSellQuantities[item.name] ?? maximum), maximum)
    }

    private func setSelectedQuantity(_ quantity: Int, for item: ItemDefinition, hero: Hero) {
        let maximum = max(1, ItemData.backpackQuantity(item.name, hero: hero))
        selectedSellQuantities[item.name] = min(max(1, quantity), maximum)
    }

    private func toggleSellSelection(_ item: ItemDefinition, hero: Hero) {
        if selectedSellItems.contains(item.name) {
            selectedSellItems.remove(item.name)
            selectedSellQuantities[item.name] = nil
        } else {
            selectedSellItems.insert(item.name)
            selectedSellQuantities[item.name] = ItemData.backpackQuantity(item.name, hero: hero)
        }
    }

    private func selectAllSellable(_ hero: Hero) {
        clearSellSelection()
        for item in allSellableBackpackItems(hero) {
            selectedSellItems.insert(item.name)
            selectedSellQuantities[item.name] = ItemData.backpackQuantity(item.name, hero: hero)
        }
    }

    private func clearSellSelection() {
        selectedSellItems.removeAll()
        selectedSellQuantities.removeAll()
        skipNormalSellWarningChoice = false
    }

    private func selectedSellLines(_ hero: Hero) -> [MultiSellLine] {
        allSellableBackpackItems(hero)
            .filter { selectedSellItems.contains($0.name) }
            .map { item in
                let quantity = selectedQuantity(for: item, hero: hero)
                return MultiSellLine(
                    itemName: item.name,
                    quantity: quantity,
                    totalGold: saveStore.sellValue(for: item) * quantity,
                    rarity: item.rarity
                )
            }
            .filter { $0.quantity > 0 }
            .sorted { $0.itemName < $1.itemName }
    }

    private func selectedSellTotal(_ hero: Hero) -> Int {
        selectedSellLines(hero).reduce(0) { $0 + $1.totalGold }
    }

    private func multiSellHasForcedWarning(_ hero: Hero) -> Bool {
        selectedSellLines(hero).contains { line in
            line.rarity == .epic
                || line.rarity == .legendary
                || line.rarity == .mythic
                || (line.rarity == .rare && saveStore.settings.confirmRareEpicSales)
        }
    }

    private func startMultiSell(_ hero: Hero) {
        guard !selectedSellItems.isEmpty else {
            message = "Select at least one item to sell."
            return
        }

        if multiSellHasForcedWarning(hero) || !saveStore.settings.skipNormalSellConfirmation {
            skipNormalSellWarningChoice = false
            showMultiSellConfirmation = true
        } else {
            performMultiSell(updateSkipPreference: false)
        }
    }

    private func performMultiSell(updateSkipPreference: Bool) {
        guard let hero else { return }
        let lines = selectedSellLines(hero)
        guard !lines.isEmpty else {
            message = "No selected items are available to sell."
            return
        }

        if updateSkipPreference {
            var settings = saveStore.settings
            settings.skipNormalSellConfirmation = true
            saveStore.updateSettings(settings)
        }

        var errors: [String] = []
        for line in lines {
            guard let item = ItemData.definition(named: line.itemName) else { continue }
            if let error = saveStore.sellItem(item, quantity: line.quantity, from: slotID) {
                errors.append(error)
            }
        }

        let totalGold = lines.reduce(0) { $0 + $1.totalGold }
        let totalQuantity = lines.reduce(0) { $0 + $1.quantity }
        clearSellSelection()
        sellSelectionMode = false
        showMultiSellConfirmation = false
        message = errors.isEmpty ? "Sold \(totalQuantity) items for \(totalGold) gold." : errors.joined(separator: " ")
    }

    private func shopCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

enum ShopTab: String, CaseIterable, Identifiable {
    case buy = "Buy"
    case sell = "Sell"

    var id: String { rawValue }
}

enum ShopMode {
    case buy
    case sell
}

struct MultiSellLine: Identifiable {
    let itemName: String
    let quantity: Int
    let totalGold: Int
    let rarity: Rarity

    var id: String { itemName }
}

struct MultiSellConfirmationView: View {
    let lines: [MultiSellLine]
    let totalGold: Int
    let showsNormalSkipToggle: Bool
    @Binding var skipNormalWarning: Bool
    var onConfirm: () -> Void
    var onCancel: () -> Void

    private var warningTitle: String {
        showsNormalSkipToggle ? "Confirm Sale" : "Confirm High-Value Sale"
    }

    private var warningText: String {
        showsNormalSkipToggle
            ? "You are about to sell selected items. This cannot be undone."
            : "You are about to sell Rare, Epic or higher gear. This cannot be undone."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QuestboundTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(warningTitle)
                            .font(.title.bold())
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 10) {
                            Text(warningText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ForEach(lines) { line in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(line.itemName) x\(line.quantity)")
                                            .font(.subheadline.weight(.semibold))
                                        Text(line.rarity.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(line.totalGold)g")
                                        .font(.subheadline.weight(.bold))
                                }
                            }

                            Divider()
                                .background(QuestboundTheme.border)

                            HStack {
                                Text("Total Gold")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(totalGold)g")
                                    .font(.headline)
                            }

                            if showsNormalSkipToggle {
                                Toggle("Do not remind me again for normal items.", isOn: $skipNormalWarning)
                                    .font(.caption.weight(.semibold))
                                    .tint(QuestboundTheme.accent)
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

                        Button(role: .destructive) {
                            onConfirm()
                        } label: {
                            Label("Confirm Sale", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Cancel", role: .cancel) {
                            onCancel()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Confirm Sale")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

protocol ShopFilterOption: CaseIterable, Hashable, Identifiable where AllCases == [Self] {
    var displayName: String { get }
}

extension ShopFilterOption {
    var id: String { displayName }
}

enum ShopCategoryFilter: ShopFilterOption {
    case all
    case weapons
    case armour
    case charms
    case consumables
    case materials
    case miscellaneous

    var displayName: String {
        switch self {
        case .all: return "All"
        case .weapons: return "Weapons"
        case .armour: return "Armour"
        case .charms: return "Charms"
        case .consumables: return "Consumables"
        case .materials: return "Materials"
        case .miscellaneous: return "Miscellaneous"
        }
    }

    func matches(_ item: ItemDefinition) -> Bool {
        switch self {
        case .all: return true
        case .weapons: return item.category == .weapon
        case .armour: return item.category == .armour
        case .charms: return item.category == .charm
        case .consumables: return item.category == .consumable
        case .materials: return item.category == .material
        case .miscellaneous: return item.category == .miscellaneous
        }
    }
}

enum ShopRarityFilter: ShopFilterOption {
    case all
    case common
    case uncommon
    case rare
    case epic

    var displayName: String {
        switch self {
        case .all: return "All"
        case .common: return "Common"
        case .uncommon: return "Uncommon"
        case .rare: return "Rare"
        case .epic: return "Epic"
        }
    }

    func matches(_ item: ItemDefinition) -> Bool {
        switch self {
        case .all: return true
        case .common: return item.rarity == .common
        case .uncommon: return item.rarity == .uncommon
        case .rare: return item.rarity == .rare
        case .epic: return item.rarity == .epic
        }
    }
}

enum ShopPathFilter: ShopFilterOption {
    case all
    case bladeguard
    case shadowstep
    case wildwarden
    case embermage
    case oathkeeper
    case general

    var displayName: String {
        switch self {
        case .all: return "All Paths"
        case .bladeguard: return "Bladeguard"
        case .shadowstep: return "Shadowstep"
        case .wildwarden: return "Wildwarden"
        case .embermage: return "Embermage"
        case .oathkeeper: return "Oathkeeper"
        case .general: return "General / No Path"
        }
    }

    private var path: Path? {
        switch self {
        case .bladeguard: return .bladeguard
        case .shadowstep: return .shadowstep
        case .wildwarden: return .wildwarden
        case .embermage: return .embermage
        case .oathkeeper: return .oathkeeper
        case .all, .general: return nil
        }
    }

    func matches(_ item: ItemDefinition, hero: Hero) -> Bool {
        switch self {
        case .all:
            return true
        case .general:
            return item.pathRequirement == nil && item.subpathRequirement == nil
        default:
            guard let path else { return true }
            if item.pathTags.contains(path) { return true }
            if item.pathRequirement != nil { return false }
            return inferredPathMatch(item, path: path)
        }
    }

    private func inferredPathMatch(_ item: ItemDefinition, path: Path) -> Bool {
        guard item.category == .weapon else { return false }
        let text = "\(item.name) \(item.description) \(item.effectText) \(item.damage ?? "")".lowercased()
        switch path {
        case .bladeguard:
            return text.contains("sword") || text.contains("mace") || text.contains("axe") || text.contains("shield") || text.contains("bastion") || text.contains("tempest")
        case .shadowstep:
            return text.contains("dagger") || text.contains("shiv") || text.contains("fang")
        case .wildwarden:
            return text.contains("bow") || text.contains("spear") || text.contains("hunter") || text.contains("packwarden") || text.contains("thorn")
        case .embermage:
            return text.contains("staff") || text.contains("rod") || text.contains("focus") || text.contains("ember") || text.contains("star")
        case .oathkeeper:
            return text.contains("vow") || text.contains("oath") || text.contains("dawn") || text.contains("sun") || text.contains("mercy") || text.contains("verdict")
        }
    }
}

enum ShopSubpathFilter: String, ShopFilterOption {
    case all = "All Subpaths"
    case ironVanguard = "Iron Vanguard"
    case stormDuelist = "Storm Duelist"
    case nightblade = "Nightblade"
    case trickhand = "Trickhand"
    case beastcaller = "Beastcaller"
    case deepwoodArcher = "Deepwood Archer"
    case flamecaller = "Flamecaller"
    case starweaver = "Voidweaver"
    case dawnshield = "Dawnshield"
    case judgementFlame = "Judgement Flame"
    case none = "No Subpath Requirement"

    var displayName: String { rawValue }

    func matches(_ item: ItemDefinition) -> Bool {
        switch self {
        case .all:
            return true
        case .none:
            return item.subpathRequirement == nil
        default:
            return item.subpathTags.contains(rawValue)
        }
    }
}

struct ShopItemDetailView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var message: String?
    @State private var showRareSellConfirmation = false
    @State private var selectedQuantity = 1
    @State private var comparisonItem: ItemDefinition?

    let slotID: Int
    let item: ItemDefinition
    let mode: ShopMode

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        ItemDetailHeader(item: item)
                        detailCard(hero)
                        actionCard(hero)
                        if let message {
                            Text(message)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sell rare gear?", isPresented: $showRareSellConfirmation) {
            Button("Sell", role: .destructive) {
                sell(quantity: selectedQuantity)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Confirm selling \(item.name).")
        }
        .sheet(item: $comparisonItem) { item in
            ItemComparisonView(slotID: slotID, item: item)
        }
    }

    private func detailCard(_ hero: Hero) -> some View {
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
            detailRow("Value", "\(item.value) gold")
            detailRow("Sellable", item.isSellable && item.category != .questItem ? "Yes" : "No")
            detailRow("Crafting Use", ItemData.craftingUseText(for: item))
            if mode == .buy {
                detailRow("Shop Price", "\(saveStore.buyPrice(for: item)) gold")
                if let discount = saveStore.shopState.activeEvent?.discountPercent {
                    detailRow("Discount", "\(discount)%")
                }
            } else {
                detailRow("Sell Value", "\(saveStore.sellValue(for: item)) gold")
            }
            detailRow("Level Requirement", item.levelRequirement.map(String.init) ?? "None")
            detailRow("Path Requirement", item.pathRequirement?.rawValue ?? "None")
            detailRow("Subpath Requirement", item.subpathRequirement ?? "None")
            detailRow("Equipped", ItemData.isEquipped(item.name, hero: hero) ? "Yes" : "No")
            if mode == .sell {
                detailRow("Sellable Copy Available", ItemData.backpackQuantity(item.name, hero: hero) > 0 ? "Yes, x\(ItemData.backpackQuantity(item.name, hero: hero))" : "No")
            }
            Text(item.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
    }

    private func actionCard(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if item.isEquippable {
                Button {
                    comparisonItem = item
                } label: {
                    Label("Compare Gear", systemImage: "info.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(QuestboundTheme.accent)
            }

            if mode == .buy {
                quantitySelector(hero: hero, unitValue: saveStore.buyPrice(for: item), isBuying: true)
                Button {
                    if let error = saveStore.buyItem(item, quantity: selectedQuantity, for: slotID) {
                        message = error
                    } else {
                        message = "Bought \(selectedQuantity) \(item.name)."
                    }
                } label: {
                    Label("Buy \(selectedQuantity)", systemImage: "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
                .disabled(hero.gold < saveStore.buyPrice(for: item) * selectedQuantity)

                if item.isEquippable {
                    ForEach(item.slots) { slot in
                        if ItemData.isCompatible(item, with: slot, hero: hero) {
                            Button {
                                if hero.inventory.itemQuantities[item.name] == nil {
                                    message = "Buy this item before equipping it."
                                } else {
                                    let updatedHero = ItemData.equippedHero(hero, with: item, in: slot)
                                    saveStore.updateHero(updatedHero, in: slotID)
                                    message = "Equipped \(item.name)."
                                }
                            } label: {
                                Label("Equip Now: \(slot.displayName)", systemImage: "checkmark.circle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(QuestboundTheme.accent)
                        } else {
                            Text("\(slot.displayName): \(ItemData.requirementIssue(for: item, hero: hero) ?? "Incompatible")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                if ItemData.isEquipped(item.name, hero: hero) {
                    Text("This equipped copy is protected. Spare copies appear in Backpack and can be sold.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if ItemData.backpackQuantity(item.name, hero: hero) == 0 {
                    Text("No unequipped copies are available to sell.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                } else {
                    quantitySelector(hero: hero, unitValue: saveStore.sellValue(for: item), isBuying: false)
                    Button(role: .destructive) {
                        if saveStore.settings.confirmRareEpicSales && (item.rarity == .rare || item.rarity == .epic) {
                            showRareSellConfirmation = true
                        } else {
                            sell(quantity: selectedQuantity)
                        }
                    } label: {
                        Label("Sell \(selectedQuantity)", systemImage: "minus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        let quantity = ItemData.backpackQuantity(item.name, hero: hero)
                        selectedQuantity = quantity
                        if saveStore.settings.confirmRareEpicSales && (item.rarity == .rare || item.rarity == .epic) {
                            showRareSellConfirmation = true
                        } else {
                            sell(quantity: quantity)
                        }
                    } label: {
                        Label("Sell All \(ItemData.backpackQuantity(item.name, hero: hero))", systemImage: "tray.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            selectedQuantity = min(max(1, selectedQuantity), maximumQuantity(hero: hero))
        }
    }

    private func quantitySelector(hero: Hero, unitValue: Int, isBuying: Bool) -> some View {
        let maxQuantity = maximumQuantity(hero: hero)
        return VStack(alignment: .leading, spacing: 8) {
            detailRow(isBuying ? "Quantity" : "Sell Quantity", "\(selectedQuantity)")
            HStack(spacing: 10) {
                Button {
                    selectedQuantity = max(1, selectedQuantity - 1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(selectedQuantity <= 1)

                Text("\(selectedQuantity)")
                    .font(.headline)
                    .frame(maxWidth: .infinity)

                Button {
                    selectedQuantity = min(maxQuantity, selectedQuantity + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.bordered)
                .disabled(selectedQuantity >= maxQuantity)
            }
            detailRow(isBuying ? "Total Cost" : "Total Sell Value", "\(unitValue * selectedQuantity) gold")
            if !item.isStackable {
                Text("Gear is limited to quantity 1.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func maximumQuantity(hero: Hero) -> Int {
        if mode == .sell {
            return max(1, ItemData.backpackQuantity(item.name, hero: hero))
        }
        guard item.isStackable else { return 1 }
        return max(1, min(99, hero.gold / max(1, saveStore.buyPrice(for: item))))
    }

    private func sell(quantity: Int) {
        if let error = saveStore.sellItem(item, quantity: quantity, from: slotID) {
            message = error
        } else {
            message = "Sold \(quantity) \(item.name)."
        }
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

struct ItemDetailHeader: View {
    let item: ItemDefinition

    var body: some View {
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
}
