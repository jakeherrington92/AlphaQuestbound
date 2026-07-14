import SwiftUI

struct LevelUpFlowView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int

    private var hero: Hero? {
        saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            if let hero, let nextLevel = LevelUpEngine.pendingNextLevel(for: hero) {
                LevelUpView(slotID: slotID, hero: hero, targetLevel: nextLevel)
                    .id("\(hero.id)-\(hero.level)-\(nextLevel)")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Level Up Complete")
                        .font(.title.bold())
                    if let hero {
                        Text("\(hero.name) is now Level \(hero.level).")
                            .foregroundStyle(.secondary)
                        if hero.level >= GameConstants.versionOneLevelCap {
                            Text("Version 1 level cap reached.")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle("Level Up")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LevelUpView: View {
    @EnvironmentObject private var saveStore: SaveStore

    let slotID: Int
    let hero: Hero
    let targetLevel: Int

    @State private var increaseMode: AttributeIncreaseMode = .oneAttributePlusTwo
    @State private var primaryAttribute: AttributeType = .might
    @State private var secondaryAttribute: AttributeType = .agility
    @State private var selectedSubpath: Subpath?
    @State private var selectedPortrait: Portrait?
    @State private var showSubpathConfirm = false
    @State private var showLevelConfirm = false
    @State private var message: String?

    private var attributeIncreases: [AttributeType: Int] {
        guard requiresAttributeIncrease else { return [:] }
        switch increaseMode {
        case .oneAttributePlusTwo:
            return [primaryAttribute: 2]
        case .twoAttributesPlusOne:
            guard primaryAttribute != secondaryAttribute else { return [:] }
            return [primaryAttribute: 1, secondaryAttribute: 1]
        }
    }

    private var preview: LevelUpPreview {
        LevelUpEngine.preview(hero: hero, targetLevel: targetLevel, attributeIncreases: attributeIncreases)
    }

    private var requiresAttributeIncrease: Bool {
        ProgressionRules.versionOne.attributeIncreaseLevels.contains(targetLevel)
    }

    private var requiresSubpathSelection: Bool {
        targetLevel == 3 && hero.selectedSubpath == nil
    }

    private var canConfirm: Bool {
        if requiresAttributeIncrease, attributeIncreases.isEmpty {
            return false
        }
        if attributeIncreases.contains(where: { hero.attributes.score(for: $0.key) + $0.value > GameConstants.versionOneAttributeCap }) {
            return false
        }
        if requiresSubpathSelection, selectedSubpath == nil {
            return false
        }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TutorialTipView(tip: .levelUp)
                levelSummaryCard
                unlocksCard
                resourcesCard
                if requiresAttributeIncrease {
                    attributeIncreaseCard
                }
                if requiresSubpathSelection {
                    subpathSelectionCard
                    if selectedSubpath != nil {
                        portraitSelectionCard
                    }
                }
                confirmButton
            }
            .padding(20)
        }
        .background(QuestboundTheme.background.ignoresSafeArea())
        .alert("Lock In Subpath?", isPresented: $showSubpathConfirm) {
            Button("Confirm") {
                applyLevelUp()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Subpath choice is permanent in Version 1.")
        }
        .alert("Confirm Level \(targetLevel)?", isPresented: $showLevelConfirm) {
            Button("Confirm") {
                applyLevelUp()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Apply the selected attribute increase, HP and Focus changes, and new abilities.")
        }
        .alert("Level Up", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .onAppear {
            if selectedPortrait == nil {
                selectedPortrait = hero.portrait
            }
            primaryAttribute = recommendedPrimaryAttribute()
            secondaryAttribute = AttributeType.allCases.first { $0 != primaryAttribute } ?? .agility
        }
    }

    private var levelSummaryCard: some View {
        levelCard("Level \(preview.oldLevel) -> \(preview.newLevel)") {
            detailRow("XP Total", "\(hero.xp)")
            if hero.level >= GameConstants.versionOneLevelCap {
                Text("Version 1 level cap reached.")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var unlocksCard: some View {
        levelCard("Unlocked") {
            ForEach(preview.unlocks, id: \.self) { unlock in
                Label(unlock, systemImage: "sparkle")
                    .font(.subheadline)
            }
        }
    }

    private var resourcesCard: some View {
        levelCard("Resources") {
            detailRow("Max HP", "\(preview.oldMaxHealth) + \(preview.hpGain) = \(preview.newMaxHealth)")
            if hero.maxFocus > 0 || preview.newMaxFocus > 0 {
                detailRow("Focus", "\(preview.oldMaxFocus) + \(preview.focusGain) = \(preview.newMaxFocus)")
            }
            if hero.maxStamina > 0 || preview.newMaxStamina > 0 {
                detailRow("Stamina", "\(preview.oldMaxStamina) + \(preview.staminaGain) = \(preview.newMaxStamina)")
            }
            if preview.oldTrainingBonus != preview.newTrainingBonus {
                detailRow("Training Bonus", "+\(preview.oldTrainingBonus) -> +\(preview.newTrainingBonus)")
            } else {
                detailRow("Training Bonus", "+\(preview.newTrainingBonus)")
            }
        }
    }

    private var attributeIncreaseCard: some View {
        levelCard("Attribute Increase") {
            Picker("Increase", selection: $increaseMode) {
                ForEach(AttributeIncreaseMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Primary Attribute", selection: $primaryAttribute) {
                ForEach(AttributeType.allCases) { attribute in
                    Text(attribute.displayName).tag(attribute)
                }
            }

            if increaseMode == .twoAttributesPlusOne {
                Picker("Second Attribute", selection: $secondaryAttribute) {
                    ForEach(AttributeType.allCases) { attribute in
                        Text(attribute.displayName).tag(attribute)
                    }
                }
            }

            ForEach(AttributeType.allCases) { attribute in
                let increase = attributeIncreases[attribute] ?? 0
                let oldScore = hero.attributes.score(for: attribute)
                let newScore = LevelUpEngine.attributes(hero.attributes, applying: attributeIncreases).score(for: attribute)
                HStack {
                    Text(attribute.displayName)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(increase > 0 ? "\(oldScore) + \(increase) = \(newScore)" : "\(oldScore)")
                        .fontWeight(increase > 0 ? .bold : .regular)
                }
            }

            if !canConfirm {
                Text("Choose valid attributes. Attributes cannot exceed \(GameConstants.versionOneAttributeCap), and the two +1 option needs two different attributes.")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    private var subpathSelectionCard: some View {
        levelCard("Choose Subpath") {
            Text("Subpath choice is permanent in Version 1.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(CharacterCreationData.pathDefinition(for: hero.path).subpaths) { subpath in
                Button {
                    selectedSubpath = subpath
                    selectedPortrait = hero.portrait
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(subpath.name)
                                .font(.headline)
                            Spacer()
                            if selectedSubpath?.id == subpath.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        Text(subpath.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(selectedSubpath?.id == subpath.id ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var portraitSelectionCard: some View {
        levelCard("Portrait") {
            if let subpath = selectedSubpath {
                let options = [PortraitDefinition(portrait: hero.portrait, path: hero.path, subpathID: nil, label: "Keep Current Portrait", isBasePortrait: true)]
                    + CharacterCreationData.subpathPortraits(for: subpath)
                ForEach(options) { option in
                    Button {
                        selectedPortrait = option.portrait
                    } label: {
                        HStack(spacing: 12) {
                            PortraitBadge(option: option.portrait)
                            Text(option.label)
                                .fontWeight(.semibold)
                            Spacer()
                            if selectedPortrait == option.portrait {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(10)
                        .background(selectedPortrait == option.portrait ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var confirmButton: some View {
        Button {
            if requiresSubpathSelection {
                showSubpathConfirm = true
            } else {
                showLevelConfirm = true
            }
        } label: {
            Text("Confirm Level \(targetLevel)")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canConfirm)
    }

    private func applyLevelUp() {
        guard canConfirm else {
            message = "Complete the required level-up choices first."
            return
        }
        let updated = LevelUpEngine.applyLevelUp(
            hero: hero,
            targetLevel: targetLevel,
            attributeIncreases: attributeIncreases,
            selectedSubpath: selectedSubpath,
            selectedPortrait: selectedPortrait
        )
        saveStore.updateHero(updated, in: slotID)
    }

    private func recommendedPrimaryAttribute() -> AttributeType {
        CharacterCreationData.pathDefinition(for: hero.path).primaryAttributes.first ?? .might
    }

    private func levelCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
}

struct DeveloperSubpathSelectionView: View {
    @EnvironmentObject private var saveStore: SaveStore
    @Environment(\.dismiss) private var dismiss

    let slotID: Int

    @State private var selectedSubpath: Subpath?
    @State private var selectedPortrait: Portrait?
    @State private var showConfirmation = false
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
                        Text("Choose Subpath")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("This choice is permanent in Version 1. Abilities appropriate to the hero's current level unlock after confirmation.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.76))

                        selectionCard("Subpaths") {
                            ForEach(CharacterCreationData.pathDefinition(for: hero.path).subpaths) { subpath in
                                Button {
                                    selectedSubpath = subpath
                                    selectedPortrait = hero.portrait
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack {
                                            Text(subpath.name)
                                                .font(.headline)
                                            Spacer()
                                            if selectedSubpath?.id == subpath.id {
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                        }
                                        Text(subpath.summary)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(selectedSubpath?.id == subpath.id ? QuestboundTheme.accent.opacity(0.14) : QuestboundTheme.cardText.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let subpath = selectedSubpath {
                            selectionCard("Portrait") {
                                let options = [PortraitDefinition(
                                    portrait: hero.portrait,
                                    path: hero.path,
                                    subpathID: nil,
                                    label: "Keep Current Portrait",
                                    isBasePortrait: true
                                )] + CharacterCreationData.subpathPortraits(for: subpath)
                                ForEach(options) { option in
                                    Button {
                                        selectedPortrait = option.portrait
                                    } label: {
                                        HStack(spacing: 12) {
                                            PortraitBadge(option: option.portrait)
                                            Text(option.label)
                                                .fontWeight(.semibold)
                                            Spacer()
                                            if selectedPortrait == option.portrait {
                                                Image(systemName: "checkmark.circle.fill")
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Button {
                            showConfirmation = true
                        } label: {
                            Text("Confirm Subpath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(QuestboundTheme.accent)
                        .disabled(selectedSubpath == nil || selectedPortrait == nil)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Subpath")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Lock In Subpath?", isPresented: $showConfirmation) {
            Button("Confirm") {
                guard let selectedSubpath, let selectedPortrait else { return }
                message = saveStore.selectDeveloperSubpath(selectedSubpath, portrait: selectedPortrait, slotID: slotID)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Subpath choice is permanent in Version 1.")
        }
        .alert("Subpath Selected", isPresented: Binding(
            get: { message != nil },
            set: { if !$0 { message = nil; dismiss() } }
        )) {
            Button("Done") {
                message = nil
                dismiss()
            }
        } message: {
            Text(message ?? "")
        }
        .onAppear {
            selectedPortrait = hero?.portrait
        }
    }

    private func selectionCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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
}
