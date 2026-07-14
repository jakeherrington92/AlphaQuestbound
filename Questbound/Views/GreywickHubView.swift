import SwiftUI

struct GreywickHubView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @State private var showAbandonAdventureConfirm = false
    @State private var hubMessage: String?
    @State private var pendingCompletionAdventure: AdventureDefinition?
    @State private var pendingCompletionReward: AdventureCompletionReward?

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
                        TutorialTipView(tip: .greywick)
                        townActions
                        if saveStore.settings.developerModeEnabled {
                            developerToolsLink
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
        .navigationTitle("Greywick")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
#if DEBUG
            print("[Questbound] GreywickHub appeared")
            print("[Questbound] Hero loaded: \(hero?.name ?? "none")")
#endif
        }
        .alert("Abandon Adventure?", isPresented: $showAbandonAdventureConfirm) {
            Button("Abandon", role: .destructive) {
                saveStore.abandonAdventure(slotID: slotID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will return to Greywick. XP and loot earned are kept, but completion rewards are not granted.")
        }
        .navigationDestination(item: $pendingCompletionAdventure) { adventure in
            if let pendingCompletionReward {
                AdventureCompleteView(
                    slotID: slotID,
                    adventure: adventure,
                    reward: pendingCompletionReward
                )
            }
        }
    }

    private func header(_ hero: Hero) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                PortraitBadge(option: hero.portrait)

                VStack(alignment: .leading, spacing: 3) {
                    Text(hero.name)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text(pathSummary(hero))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.76))
                    Text(hero.origin.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                compactStat("Level", "\(hero.level)")
                compactStat("HP", "\(hero.currentHealth)/\(hero.maxHealth)")
                if hero.maxFocus > 0 {
                    compactStat("Focus", "\(hero.currentFocus)/\(hero.maxFocus)")
                }
                if hero.maxStamina > 0 {
                    compactStat("Stamina", "\(hero.currentStamina)/\(hero.maxStamina)")
                }
                compactStat("Gold", "\(hero.gold)")
                compactStat("XP", xpProgress(hero))
                compactStat("Shop", greywickShopStatus)
            }

            if LevelUpEngine.pendingNextLevel(for: hero) != nil {
                NavigationLink {
                    LevelUpFlowView(slotID: slotID)
                } label: {
                    Label("Level Up Available", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
            }

            if hero.level >= 3, hero.selectedSubpath == nil {
                NavigationLink {
                    DeveloperSubpathSelectionView(slotID: slotID)
                } label: {
                    Label("Choose Subpath", systemImage: "point.3.connected.trianglepath.dotted")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(QuestboundTheme.accent)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.78, green: 0.62, blue: 0.38).opacity(0.28), lineWidth: 1)
        }
        .padding(.top, 12)
    }

    private func compactStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var townActions: some View {
        townMapPanel {
            if let hero, hero.currentAdventureState.isActive {
                if adventureStateNeedsRecovery(hero) {
                    adventureRecoveryCard
                } else {
                    activeAdventureCard(hero)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 146), spacing: 10)], spacing: 10) {
                NavigationLink {
                    AdventureBoardView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_adventure_board",
                        title: "Adventure Board",
                        subtitle: "Choose your next adventure.",
                        icon: "list.bullet.clipboard"
                    )
                }

                NavigationLink {
                    ShopView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_shop",
                        title: "Shop",
                        subtitle: "Buy, sell and restock supplies.",
                        icon: "storefront"
                    )
                }

                NavigationLink {
                    RestView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_inn",
                        title: "Rest at the Inn",
                        subtitle: "Recover HP and your combat resource.",
                        icon: "bed.double"
                    )
                }

                NavigationLink {
                    InventoryView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_inventory_chest",
                        title: "Inventory / Pack",
                        subtitle: "View items, gear and materials.",
                        icon: "shippingbox"
                    )
                }

                NavigationLink {
                    CharacterSheetPreviewView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_character_portrait_frame",
                        title: "Character",
                        subtitle: "View attributes, skills and abilities.",
                        icon: "person.text.rectangle"
                    )
                }

                NavigationLink {
                    DiceRollerView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_dice_table",
                        title: "Dice Roller",
                        subtitle: "Roll dice and test skill checks.",
                        icon: "die.face.5"
                    )
                }

                NavigationLink {
                    SettingsView(slotID: slotID)
                } label: {
                    townLocationCard(
                        assetName: "location_settings_parchment",
                        title: "Settings",
                        subtitle: "Adjust options and developer tools.",
                        icon: "scroll"
                    )
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func activeAdventureCard(_ hero: Hero) -> some View {
        let completionPending = AdventureEngine.hasPendingAdventureCompletion(hero)
        return VStack(alignment: .leading, spacing: 12) {
            let adventure = hero.currentAdventureState.adventureID.flatMap(AdventureEngine.adventure(id:))
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(QuestboundTheme.accent.opacity(0.18))
                    Image(systemName: "figure.walk.diamond")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(QuestboundTheme.accent)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text(completionPending ? "Claim Adventure Rewards" : "Continue Adventure")
                        .font(.headline)
                    Text(completionPending ? "\(adventure?.title ?? "Adventure") is complete. Claim your rewards." : "Resume your current adventure.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(adventure?.title ?? "Unknown") • \(AdventureEngine.currentRoom(for: hero)?.title ?? "Unknown")")
                        .font(.caption.weight(.semibold))
                }
            }

            HStack(spacing: 10) {
                if completionPending {
                    Button {
                        finishPendingAdventure()
                    } label: {
                        Text("Claim Rewards")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    NavigationLink {
                        AdventureRoomView(slotID: slotID)
                    } label: {
                        Text("Continue Adventure")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(role: .destructive) {
                        showAbandonAdventureConfirm = true
                    } label: {
                        Text("Abandon")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.95))
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(QuestboundTheme.accent.opacity(0.55), lineWidth: 1.5)
        }
    }

    private var developerToolsLink: some View {
        NavigationLink {
            DeveloperToolsView(slotID: slotID)
        } label: {
            Label("Developer Tools", systemImage: "hammer")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(QuestboundTheme.accent)
    }

    private var adventureRecoveryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Adventure state needs recovery.", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("Greywick is still available. Enable Developer Tools in Settings to repair this save.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(QuestboundTheme.card)
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func adventureStateNeedsRecovery(_ hero: Hero) -> Bool {
        guard hero.currentAdventureState.isActive,
              let adventureID = hero.currentAdventureState.adventureID,
              AdventureEngine.adventure(id: adventureID) != nil,
              AdventureEngine.currentRoom(for: hero) != nil else {
            return hero.currentAdventureState.isActive
        }
        return false
    }

    private func townMapPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        // Future generated image hook: background_greywick_town_map
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Greywick")
                    .font(.title.bold())
                    .foregroundStyle(.white)
                Text("Choose where to go in town.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.17, blue: 0.12),
                        Color(red: 0.45, green: 0.34, blue: 0.19),
                        Color(red: 0.16, green: 0.20, blue: 0.17)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.82, blue: 0.52).opacity(0.12),
                        .clear,
                        Color.black.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.78, green: 0.58, blue: 0.31).opacity(0.65), lineWidth: 1.5)
        }
    }

    private func townLocationCard(assetName: String, title: String, subtitle: String, icon: String) -> some View {
        // Future generated image hook: assetName
        VStack(alignment: .leading, spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.23, green: 0.18, blue: 0.13).opacity(0.84),
                                QuestboundTheme.accent.opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: icon)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(QuestboundTheme.accent)
            }
            .frame(height: 56)
            Text(title)
                .font(.subheadline.weight(.bold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: [
                    QuestboundTheme.card.opacity(0.98),
                    Color(red: 0.88, green: 0.78, blue: 0.58).opacity(0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .questboundParchmentText()
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(red: 0.58, green: 0.42, blue: 0.22).opacity(0.72), lineWidth: 1)
        }
        .accessibilityIdentifier(assetName)
    }

    private func hubCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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

    private func xpProgress(_ hero: Hero) -> String {
        if LevelUpEngine.pendingNextLevel(for: hero) != nil {
            return "\(hero.xp) XP • Level up available"
        }
        guard let nextXP = ProgressionRules.versionOne.xpRequired(for: hero.level + 1) else {
            return "\(hero.xp) XP • Level cap"
        }
        return "\(hero.xp) / \(nextXP) XP"
    }

    private func finishPendingAdventure() {
        guard let result = saveStore.completeFinalBossAdventure(slotID: slotID) else {
            hubMessage = "No completed final boss adventure is waiting."
            return
        }
        pendingCompletionReward = result.1
        pendingCompletionAdventure = result.0
    }

    private var greywickShopStatus: String {
        guard let event = saveStore.shopState.activeEvent else {
            return "No active shop event"
        }
        switch event.type {
        case .sale:
            return "\(event.name) until next adventure"
        case .merchantDemand:
            return "Merchant Demand until next adventure"
        }
    }

    private func pathSummary(_ hero: Hero) -> String {
        guard let subpath = hero.subpath, !subpath.isEmpty else {
            return hero.path.rawValue
        }
        return "\(hero.path.rawValue) / \(subpath)"
    }

    private func nextUnlock(_ hero: Hero) -> String {
        if let pendingLevel = LevelUpEngine.pendingNextLevel(for: hero) {
            return "Level \(pendingLevel) ready"
        }
        if hero.level < 3 {
            return "Level 3 Subpath"
        }
        if hero.level < GameConstants.versionOneLevelCap {
            return "Level \(hero.level + 1) training"
        }
        return "Version 1 level cap reached"
    }
}

struct DeveloperAttributeRespecView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int

    @State private var attributes = Attributes()
    @State private var restoreFull = true
    @State private var message: String?

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()
            ScrollView {
                if let hero {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Developer Attribute Respec")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Developer respec ignores normal character creation limits.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.72))

                        respecCard {
                            ForEach(AttributeType.allCases) { attribute in
                                attributeStepper(attribute)
                            }
                        }

                        respecCard {
                            detailRow("Preview Max HP", "\(previewMaxHP(hero))")
                            detailRow("Preview Max Focus", "\(LevelUpEngine.maxFocus(for: hero.path, attributes: attributes, level: hero.level))")
                            Toggle("Restore to full HP/Focus", isOn: $restoreFull)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                            presetButton("Reset to 8", value: 8)
                            presetButton("All 12", value: 12)
                            presetButton("All 16", value: 16)
                            presetButton("All 20", value: 20)
                        }

                        Button {
                            message = saveStore.updateDeveloperAttributes(attributes, slotID: slotID, restoreFull: restoreFull)
                        } label: {
                            Text("Confirm Respec")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(QuestboundTheme.accent)

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
        .navigationTitle("Respec")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let hero {
                attributes = hero.attributes
            }
        }
    }

    private func attributeStepper(_ attribute: AttributeType) -> some View {
        Stepper(value: binding(for: attribute), in: 8...GameConstants.versionOneAttributeCap) {
            HStack {
                Text(attribute.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(attributes.score(for: attribute)) (\(signed(attributes.modifier(for: attribute))))")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func presetButton(_ title: String, value: Int) -> some View {
        Button(title) {
            attributes = Attributes(might: value, agility: value, endurance: value, mind: value, instinct: value, presence: value)
        }
        .buttonStyle(.bordered)
    }

    private func binding(for attribute: AttributeType) -> Binding<Int> {
        Binding {
            attributes.score(for: attribute)
        } set: { value in
            switch attribute {
            case .might: attributes.might = value
            case .agility: attributes.agility = value
            case .endurance: attributes.endurance = value
            case .mind: attributes.mind = value
            case .instinct: attributes.instinct = value
            case .presence: attributes.presence = value
            }
        }
    }

    private func previewMaxHP(_ hero: Hero) -> Int {
        guard let pathDefinition = CharacterCreationData.paths.first(where: { $0.path == hero.path }) else {
            return hero.maxHealth
        }
        let enduranceModifier = attributes.modifier(for: .endurance)
        let startingHP = max(1, pathDefinition.startingHPBase + enduranceModifier)
        let perLevel = max(1, pathDefinition.hpPerLevelBase + enduranceModifier)
        return startingHP + max(0, hero.level - 1) * perLevel
    }

    private func respecCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
