import SwiftUI

struct HeroCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var saveStore: SaveStore

    let slotID: Int

    @State private var heroName = ""
    @State private var origin: Origin = .hearthborn
    @State private var path: Path = .bladeguard
    @State private var portrait: Portrait = .bladeguardBaseMale
    @State private var baseAttributes = Attributes()
    @State private var selectedAttribute: AttributeType?

    private var trimmedName: String {
        heroName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var originDefinition: OriginDefinition {
        CharacterCreationData.originDefinition(for: origin)
    }

    private var pathDefinition: PathDefinition {
        CharacterCreationData.pathDefinition(for: path)
    }

    private var pointsRemaining: Int {
        72 - baseAttributes.total
    }

    private var finalAttributes: Attributes {
        Attributes(
            might: finalScore(for: .might),
            agility: finalScore(for: .agility),
            endurance: finalScore(for: .endurance),
            mind: finalScore(for: .mind),
            instinct: finalScore(for: .instinct),
            presence: finalScore(for: .presence)
        )
    }

    private var startingHP: Int {
        max(1, pathDefinition.startingHPBase + finalAttributes.modifier(for: .endurance))
    }

    private var startingFocus: Int {
        guard let focusBase = pathDefinition.focusBase,
              let focusAttribute = pathDefinition.focusAttribute else { return 0 }
        return max(1, focusBase + finalAttributes.modifier(for: focusAttribute) + 1)
    }

    private var startingStamina: Int {
        LevelUpEngine.maxStamina(for: path, level: 1)
    }

    private var validationMessages: [String] {
        var messages: [String] = []
        let scores = AttributeType.allCases.map { baseAttributes.score(for: $0) }

        if trimmedName.isEmpty {
            messages.append("Enter a hero name.")
        }
        if pointsRemaining > 0 {
            messages.append("Spend all 24 extra attribute points.")
        }
        if pointsRemaining < 0 {
            messages.append("Remove \(-pointsRemaining) attribute point(s).")
        }
        if scores.contains(where: { $0 > 16 }) {
            messages.append("No base attribute can be higher than 16.")
        }
        if scores.filter({ $0 == 16 }).count > 1 {
            messages.append("Only one attribute can start at 16.")
        }
        if scores.filter({ $0 >= 15 }).count > 2 {
            messages.append("Only two attributes can start at 15 or higher.")
        }
        if scores.allSatisfy({ $0 > 10 }) {
            messages.append("At least one attribute must remain 10 or lower.")
        }
        if AttributeType.allCases.contains(where: { finalScore(for: $0) > GameConstants.versionOneAttributeCap }) {
            messages.append("Origin bonuses cannot push an attribute above 20.")
        }
        if !CharacterCreationData.basePortraits(for: path).contains(where: { $0.portrait == portrait }) {
            messages.append("Choose a base portrait for the selected Path.")
        }

        return messages
    }

    private var weakBuildWarning: String? {
        pathDefinition.weakBuildWarning(baseAttributes)
    }

    private var canConfirm: Bool {
        validationMessages.isEmpty
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Create Hero")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    creationCard(title: "Help") {
                        Text("Build choices are preview-only until Confirm Hero. Attribute points are assigned before Origin bonuses, and the final review shows HP, Focus, trained skills, abilities and starting gear.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    creationCard(title: "1. Hero Name") {
                        TextField("Hero name", text: $heroName)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)
                    }

                    originSection
                    pathSection
                    subpathPreviewSection
                    portraitSection
                    attributeSection
                    reviewSection
                    confirmationSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Slot \(slotID)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: path) { _, newPath in
            portrait = CharacterCreationData.firstBasePortrait(for: newPath)
        }
        .sheet(item: $selectedAttribute) { attribute in
            AttributeInfoSheet(attribute: attribute)
                .presentationDetents([.medium])
        }
    }

    private var originSection: some View {
        creationCard(title: "2. Origin") {
            Picker("Origin", selection: $origin) {
                ForEach(CharacterCreationData.origins) { definition in
                    Text(definition.origin.rawValue).tag(definition.origin)
                }
            }
            .pickerStyle(.menu)

            Text(origin.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            labeledText("Bonuses", bonusSummary(originDefinition.bonuses))
            labeledText("Feature", "\(originDefinition.feature.name): \(originDefinition.feature.summary)")
            labeledText("Recommended", originDefinition.recommendedPaths.map(\.rawValue).joined(separator: ", "))
        }
    }

    private var pathSection: some View {
        creationCard(title: "3. Path") {
            Picker("Path", selection: $path) {
                ForEach(CharacterCreationData.paths) { definition in
                    Text(definition.path.rawValue).tag(definition.path)
                }
            }
            .pickerStyle(.menu)

            Text(path.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            labeledText("Role", pathDefinition.role)
            labeledText("Difficulty", pathDefinition.difficulty)
            labeledText("Primary", pathDefinition.primaryAttributes.map(\.displayName).joined(separator: ", "))
            labeledText("Secondary", pathDefinition.secondaryAttributes.map(\.displayName).joined(separator: ", "))
            labeledText("Useful", pathDefinition.usefulAttributes.map(\.displayName).joined(separator: ", "))

            Button {
                baseAttributes = Attributes(
                    might: pathDefinition.recommendedBuild[.might] ?? 8,
                    agility: pathDefinition.recommendedBuild[.agility] ?? 8,
                    endurance: pathDefinition.recommendedBuild[.endurance] ?? 8,
                    mind: pathDefinition.recommendedBuild[.mind] ?? 8,
                    instinct: pathDefinition.recommendedBuild[.instinct] ?? 8,
                    presence: pathDefinition.recommendedBuild[.presence] ?? 8
                )
            } label: {
                Label("Use Recommended Build", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(QuestboundTheme.accent)
        }
    }

    private var subpathPreviewSection: some View {
        creationCard(title: "4. Subpath Previews") {
            ForEach(pathDefinition.subpaths) { subpath in
                VStack(alignment: .leading, spacing: 4) {
                    Text(subpath.name)
                        .font(.subheadline.weight(.semibold))
                    Text(subpath.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var portraitSection: some View {
        creationCard(title: "5. Starting Portrait") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 116), spacing: 12)], spacing: 12) {
                ForEach(CharacterCreationData.basePortraits(for: path)) { definition in
                    Button {
                        portrait = definition.portrait
                    } label: {
                        VStack(spacing: 8) {
                            PortraitBadge(option: definition.portrait)
                            Text(definition.label)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(portrait == definition.portrait ? QuestboundTheme.accent.opacity(0.16) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var attributeSection: some View {
        creationCard(title: "6. Assign Attributes") {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(max(pointsRemaining, 0)) points remaining")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(pointsRemaining == 0 ? .secondary : QuestboundTheme.accent)

                ForEach(AttributeType.allCases) { attribute in
                    AttributeAssignmentRow(
                        attribute: attribute,
                        baseScore: binding(for: attribute),
                        originBonus: originBonus(for: attribute),
                        finalScore: finalScore(for: attribute),
                        modifier: finalAttributes.modifier(for: attribute),
                        canIncrease: canIncrease(attribute),
                        onInfo: { selectedAttribute = attribute }
                    )
                }

                if let weakBuildWarning {
                    Label(weakBuildWarning, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if !validationMessages.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(validationMessages, id: \.self) { message in
                            Label(message, systemImage: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private var reviewSection: some View {
        creationCard(title: "7. Review") {
            VStack(alignment: .leading, spacing: 12) {
                labeledText("Hero", trimmedName.isEmpty ? "Unnamed Hero" : trimmedName)
                labeledText("Origin", origin.rawValue)
                labeledText("Path", path.rawValue)
                labeledText("Portrait", portrait.rawValue)
                labeledText("HP", "\(startingHP)")
                if startingFocus > 0 {
                    labeledText("Focus", "\(startingFocus)")
                }
                if startingStamina > 0 {
                    labeledText("Stamina", "\(startingStamina)")
                }
                labeledText("Trained Skills", pathDefinition.startingSkills.map(\.displayName).joined(separator: ", "))
                labeledText("Starting Abilities", pathDefinition.startingAbilities.map(\.name).joined(separator: ", "))
                labeledText("Starting Gear", pathDefinition.startingGear.joined(separator: ", "))
                labeledText("Gold", "10")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Final Attributes")
                        .font(.subheadline.weight(.semibold))
                    ForEach(AttributeType.allCases) { attribute in
                        detailRow(
                            attribute.displayName,
                            "\(finalAttributes.score(for: attribute)) (\(signed(finalAttributes.modifier(for: attribute))))"
                        )
                    }
                }
            }
        }
    }

    private var confirmationSection: some View {
        Button {
            saveStore.createHero(makeHero(), in: slotID)
            dismiss()
        } label: {
            Label("Confirm Hero", systemImage: "checkmark.seal")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(QuestboundTheme.accent)
        .disabled(!canConfirm)
    }

    private func makeHero() -> Hero {
        let itemQuantities = Dictionary(grouping: pathDefinition.startingGear, by: { $0 })
            .mapValues(\.count)
        return Hero(
            name: trimmedName,
            origin: origin,
            originFeature: originDefinition.feature,
            path: path,
            portrait: portrait,
            attributes: finalAttributes,
            trainedSkills: pathDefinition.startingSkills,
            abilities: pathDefinition.startingAbilities,
            inventory: Inventory(itemQuantities: itemQuantities, gold: 10),
            equippedItems: EquippedItems(slots: pathDefinition.equippedItems),
            level: 1,
            xp: 0,
            maxHealth: startingHP,
            currentHealth: startingHP,
            focus: startingFocus,
            maxFocus: startingFocus,
            currentFocus: startingFocus,
            gold: 10,
            currentLocation: "Greywick"
        )
    }

    private func binding(for attribute: AttributeType) -> Binding<Int> {
        Binding(
            get: { baseAttributes.score(for: attribute) },
            set: { newValue in
                let clampedValue = min(max(newValue, 8), 16)
                guard clampedValue <= baseAttributes.score(for: attribute) || canIncrease(attribute) else { return }
                setBaseScore(clampedValue, for: attribute)
            }
        )
    }

    private func setBaseScore(_ value: Int, for attribute: AttributeType) {
        switch attribute {
        case .might:
            baseAttributes.might = value
        case .agility:
            baseAttributes.agility = value
        case .endurance:
            baseAttributes.endurance = value
        case .mind:
            baseAttributes.mind = value
        case .instinct:
            baseAttributes.instinct = value
        case .presence:
            baseAttributes.presence = value
        }
    }

    private func canIncrease(_ attribute: AttributeType) -> Bool {
        pointsRemaining > 0 && baseAttributes.score(for: attribute) < 16
    }

    private func originBonus(for attribute: AttributeType) -> Int {
        originDefinition.bonuses[attribute] ?? 0
    }

    private func finalScore(for attribute: AttributeType) -> Int {
        min(GameConstants.versionOneAttributeCap, baseAttributes.score(for: attribute) + originBonus(for: attribute))
    }

    private func bonusSummary(_ bonuses: [AttributeType: Int]) -> String {
        AttributeType.allCases
            .compactMap { attribute in
                guard let bonus = bonuses[attribute], bonus > 0 else { return nil }
                return "+\(bonus) \(attribute.displayName)"
            }
            .joined(separator: ", ")
    }

    private func creationCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
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

    private func labeledText(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
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
        .font(.subheadline)
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

private struct AttributeAssignmentRow: View {
    let attribute: AttributeType
    @Binding var baseScore: Int
    let originBonus: Int
    let finalScore: Int
    let modifier: Int
    let canIncrease: Bool
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: onInfo) {
                    Label(attribute.displayName, systemImage: "info.circle")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                Spacer()

                Stepper(value: binding, in: 8...16) {
                    EmptyView()
                }
                .labelsHidden()
            }

            HStack {
                scorePill("Base", "\(baseScore)")
                scorePill("Origin", originBonus > 0 ? "+\(originBonus)" : "+0")
                scorePill("Final", "\(finalScore)")
                scorePill("Mod", modifier >= 0 ? "+\(modifier)" : "\(modifier)")
            }
        }
        .padding(10)
        .background(.white.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var binding: Binding<Int> {
        Binding(
            get: { baseScore },
            set: { newValue in
                if newValue < baseScore || canIncrease {
                    baseScore = newValue
                }
            }
        )
    }

    private func scorePill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
        }
        .frame(maxWidth: .infinity)
    }
}

private extension AttributeType {
    var description: String {
        switch self {
        case .might:
            return "Melee attacks, melee damage, lifting, breaking, forcing doors and resisting knockback."
        case .agility:
            return "Ranged attacks, dagger attacks, stealth, thievery, initiative, dodging and some escape checks."
        case .endurance:
            return "HP, poison resistance, harsh conditions and physical strain."
        case .mind:
            return "Lore, puzzles, relics, arcana and most spell attacks."
        case .instinct:
            return "Awareness, survival, tracking, detecting danger and reading enemies."
        case .presence:
            return "Persuasion, intimidation, willpower, resisting fear and oath-based magic."
        }
    }
}
