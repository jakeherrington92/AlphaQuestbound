import SwiftUI

struct DiceRollerView: View {
    @EnvironmentObject private var saveStore: SaveStore

    let slotID: Int?

    @State private var selectedTab: DiceToolTab = .roller
    @State private var expressionText = "d20"
    @State private var modifier = 0
    @State private var hasAdvantage = false
    @State private var hasDisadvantage = false
    @State private var rollResult: DiceRollResult?
    @State private var rollHistory: [DiceRollResult] = []
    @State private var errorMessage: String?

    init(slotID: Int? = nil) {
        self.slotID = slotID
    }

    private var hero: Hero? {
        guard let slotID else {
            return saveStore.mostRecentlyPlayedSlot?.hero
        }
        return saveStore.slots.first(where: { $0.id == slotID })?.hero
    }

    var body: some View {
        ZStack {
            QuestboundTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Dice Tool", selection: $selectedTab) {
                        ForEach(DiceToolTab.allCases) { tab in
                            Text(tab.title).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case .roller:
                        rollerContent
                    case .skillCheck:
                        SkillCheckView(hero: hero)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Dice Roller")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var rollerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            diceCard("Quick Rolls") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 10)], spacing: 10) {
                    ForEach(DiceExpression.supportedDice, id: \.self) { dieSize in
                        Button("d\(dieSize)") {
                            quickRoll(dieSize)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            diceCard("Custom Roll") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Example: 2d6 + 1", text: $expressionText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    Stepper("Modifier: \(signed(modifier))", value: $modifier, in: -20...20)

                    Toggle("Advantage", isOn: $hasAdvantage)
                    Toggle("Disadvantage", isOn: $hasDisadvantage)

                    Button {
                        rollCustom()
                    } label: {
                        Label("Roll", systemImage: "die.face.5")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            if let rollResult {
                diceCard("Result") {
                    RollResultSummary(result: rollResult)
                }
            }

            diceCard("Roll History") {
                if rollHistory.isEmpty {
                    Text("No rolls yet.")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Button(role: .destructive) {
                            rollHistory.removeAll()
                        } label: {
                            Label("Clear History", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)

                        ForEach(rollHistory) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.summary)
                                    .font(.subheadline.weight(.semibold))
                                Text(result.rolledAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if result.id != rollHistory.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func quickRoll(_ dieSize: Int) {
        expressionText = "d\(dieSize)"
        modifier = 0
        do {
            let expression = try DiceExpression(dieSize: dieSize)
            store(DiceRoller.roll(expression, advantage: hasAdvantage, disadvantage: hasDisadvantage))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func rollCustom() {
        do {
            var expression = try DiceExpression(expressionText)
            expression.modifier += modifier
            store(DiceRoller.roll(expression, advantage: hasAdvantage, disadvantage: hasDisadvantage))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func store(_ result: DiceRollResult) {
        rollResult = result
        rollHistory.insert(result, at: 0)
        rollHistory = Array(rollHistory.prefix(20))
        errorMessage = nil
    }

    private func diceCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

private struct SkillCheckView: View {
    @State private var selectedSkill: SkillType = .awareness
    @State private var selectedDifficulty: SkillDifficulty = .standard
    @State private var selectedAttribute: AttributeType?
    @State private var selectedSkillInfo: SkillType?
    @State private var result: SkillCheckResult?

    let hero: Hero?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let hero {
                skillCard("Skill Check") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Skill", selection: $selectedSkill) {
                            ForEach(SkillType.allCases) { skill in
                                Text(skill.displayName).tag(skill)
                            }
                        }

                        Picker("Difficulty", selection: $selectedDifficulty) {
                            ForEach(SkillDifficulty.allCases) { difficulty in
                                Text("\(difficulty.displayName) \(difficulty.rawValue)").tag(difficulty)
                            }
                        }

                        skillSnapshot(hero)

                        Button {
                            result = SkillCheckHelper.check(
                                hero: hero,
                                skill: selectedSkill,
                                target: selectedDifficulty.rawValue
                            )
                        } label: {
                            Label("Roll Skill Check", systemImage: "checkmark.seal")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let result {
                    skillCard(result.success ? "Success" : "Failure") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(result.explanation)
                                .font(.subheadline.weight(.semibold))
                            if result.natural20 {
                                Text("Natural 20")
                                    .foregroundStyle(.green)
                            }
                            if result.natural1 {
                                Text("Natural 1")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            } else {
                skillCard("Skill Check") {
                    Text("Create or continue a hero to roll skill checks with attributes and training.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .alert(item: $selectedAttribute) { attribute in
            Alert(
                title: Text(attribute.displayName),
                message: Text(attribute.usageDescription),
                dismissButton: .default(Text("Done"))
            )
        }
        .alert(item: $selectedSkillInfo) { skill in
            Alert(
                title: Text(skill.displayName),
                message: Text("\(skill.usageDescription)\n\nLinked attribute: \(skill.linkedAttribute.displayName)."),
                dismissButton: .default(Text("Done"))
            )
        }
    }

    private func skillSnapshot(_ hero: Hero) -> some View {
        let attribute = selectedSkill.linkedAttribute
        let attributeModifier = hero.attributes.modifier(for: attribute)
        let isTrained = hero.trainedSkills.contains(selectedSkill)
        let trainingBonus = isTrained ? SkillCheckHelper.trainingBonus(for: hero) : 0
        let equipmentBonus = ItemData.skillBonus(for: selectedSkill, hero: hero)

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                selectedSkillInfo = selectedSkill
            } label: {
                Label(selectedSkill.displayName, systemImage: "info.circle")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)

            Button {
                selectedAttribute = attribute
            } label: {
                HStack {
                    Label(attribute.displayName, systemImage: "info.circle")
                    Spacer()
                    Text(signed(attributeModifier))
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.plain)

            detailRow("Training", isTrained ? "Trained" : "Untrained")
            if isTrained {
                detailRow("Training Bonus", signed(trainingBonus))
            }
            if equipmentBonus != 0 {
                detailRow("Equipment Bonus", signed(equipmentBonus))
            }
            detailRow("Target", "\(selectedDifficulty.rawValue)")
            Text("Formula: d20 + \(attribute.displayName) modifier\(isTrained ? " + training bonus" : "")\(equipmentBonus != 0 ? " + equipment bonus" : "")")
                .font(.caption)
                .foregroundStyle(.secondary)
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

    private func skillCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
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

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

private struct RollResultSummary: View {
    let result: DiceRollResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            detailRow("Expression", result.expression)
            detailRow("Dice", result.dice.map(String.init).joined(separator: ", "))
            if result.dice != result.keptDice {
                detailRow("Kept", result.keptDice.map(String.init).joined(separator: ", "))
            }
            if result.modifier != 0 {
                detailRow("Modifier", signed(result.modifier))
            }
            detailRow("Total", "\(result.total)")
            if result.natural20 {
                Text("Natural 20")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.semibold))
            }
            if result.natural1 {
                Text("Natural 1")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))
            }
            Text(result.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .multilineTextAlignment(.trailing)
        }
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}

private enum DiceToolTab: String, CaseIterable, Identifiable {
    case roller
    case skillCheck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .roller: return "Dice"
        case .skillCheck: return "Skill Check"
        }
    }
}
