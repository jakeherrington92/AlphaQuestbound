import Foundation

enum DiceRollError: LocalizedError, Equatable {
    case unsupportedDie
    case invalidExpression
    case invalidDiceCount

    var errorDescription: String? {
        switch self {
        case .unsupportedDie:
            return "Supported dice are d4, d6, d8, d10, d12, d20 and d100."
        case .invalidExpression:
            return "Use a simple expression like d20, 1d8 + 2 or 2d6 - 1."
        case .invalidDiceCount:
            return "Roll between 1 and 20 dice at a time."
        }
    }
}

struct DiceExpression: Equatable, Hashable {
    static let supportedDice = [4, 6, 8, 10, 12, 20, 100]
    static let d20 = DiceExpression(uncheckedDiceCount: 1, dieSize: 20, modifier: 0)

    var diceCount: Int
    var dieSize: Int
    var modifier: Int

    var displayText: String {
        let diceText = diceCount == 1 ? "d\(dieSize)" : "\(diceCount)d\(dieSize)"
        guard modifier != 0 else {
            return diceText
        }
        return "\(diceText) \(modifier > 0 ? "+" : "-") \(abs(modifier))"
    }

    init(diceCount: Int = 1, dieSize: Int, modifier: Int = 0) throws {
        guard Self.supportedDice.contains(dieSize) else {
            throw DiceRollError.unsupportedDie
        }
        guard (1...20).contains(diceCount) else {
            throw DiceRollError.invalidDiceCount
        }
        self.diceCount = diceCount
        self.dieSize = dieSize
        self.modifier = modifier
    }

    init(_ rawExpression: String) throws {
        let expression = rawExpression
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
        let pattern = #"^(\d*)d(4|6|8|10|12|20|100)([+-]\d+)?$"#

        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: expression, range: NSRange(expression.startIndex..., in: expression))
        else {
            throw DiceRollError.invalidExpression
        }

        func matchedText(at index: Int) -> String {
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: expression) else {
                return ""
            }
            return String(expression[swiftRange])
        }

        let countText = matchedText(at: 1)
        let dieText = matchedText(at: 2)
        let modifierText = matchedText(at: 3)

        let count = countText.isEmpty ? 1 : Int(countText) ?? 0
        let die = Int(dieText) ?? 0
        let modifier = modifierText.isEmpty ? 0 : Int(modifierText) ?? 0
        try self.init(diceCount: count, dieSize: die, modifier: modifier)
    }

    private init(uncheckedDiceCount diceCount: Int, dieSize: Int, modifier: Int) {
        self.diceCount = diceCount
        self.dieSize = dieSize
        self.modifier = modifier
    }
}

struct DiceRollResult: Identifiable, Equatable {
    let id = UUID()
    var expression: String
    var dice: [Int]
    var keptDice: [Int]
    var modifier: Int
    var total: Int
    var hasAdvantage: Bool
    var hasDisadvantage: Bool
    var natural20: Bool
    var natural1: Bool
    var rolledAt: Date

    var summary: String {
        var parts = ["\(expression): \(dice.map(String.init).joined(separator: ", "))"]
        if dice != keptDice {
            parts.append("kept \(keptDice.map(String.init).joined(separator: ", "))")
        }
        if modifier != 0 {
            parts.append(modifier > 0 ? "+ \(modifier)" : "- \(abs(modifier))")
        }
        parts.append("= \(total)")
        if natural20 {
            parts.append("Natural 20")
        } else if natural1 {
            parts.append("Natural 1")
        }
        return parts.joined(separator: " ")
    }
}

enum DiceRoller {
    static func roll(
        _ expression: DiceExpression,
        advantage: Bool = false,
        disadvantage: Bool = false
    ) -> DiceRollResult {
        let advantageState = expression.dieSize == 20 && expression.diceCount == 1 && advantage != disadvantage
        let rollCount = advantageState ? 2 : expression.diceCount
        let dice = (0..<rollCount).map { _ in Int.random(in: 1...expression.dieSize) }
        let keptDice: [Int]

        if advantageState, advantage {
            keptDice = [dice.max() ?? 1]
        } else if advantageState, disadvantage {
            keptDice = [dice.min() ?? 1]
        } else {
            keptDice = dice
        }

        let total = keptDice.reduce(0, +) + expression.modifier
        let naturalDie = keptDice.first ?? 0

        return DiceRollResult(
            expression: expression.displayText,
            dice: dice,
            keptDice: keptDice,
            modifier: expression.modifier,
            total: total,
            hasAdvantage: advantageState && advantage,
            hasDisadvantage: advantageState && disadvantage,
            natural20: expression.dieSize == 20 && expression.diceCount == 1 && naturalDie == 20,
            natural1: expression.dieSize == 20 && expression.diceCount == 1 && naturalDie == 1,
            rolledAt: Date()
        )
    }
}

enum SkillDifficulty: Int, CaseIterable, Identifiable {
    case simple = 8
    case standard = 12
    case testing = 13
    case challenging = 14
    case difficult = 15
    case severe = 18
    case heroic = 22
    case mythic = 26

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .simple: return "Simple"
        case .standard: return "Standard"
        case .testing: return "Testing"
        case .challenging: return "Challenging"
        case .difficult: return "Difficult"
        case .severe: return "Severe"
        case .heroic: return "Heroic"
        case .mythic: return "Mythic"
        }
    }
}

struct SkillCheckResult: Identifiable, Equatable {
    let id = UUID()
    var skill: SkillType
    var linkedAttribute: AttributeType
    var dieRoll: Int
    var attributeModifier: Int
    var trainingBonus: Int
    var equipmentBonus: Int
    var target: Int
    var total: Int
    var isTrained: Bool
    var success: Bool
    var natural20: Bool
    var natural1: Bool

    var explanation: String {
        let trainingText = isTrained ? " + training bonus \(trainingBonus)" : ""
        let equipmentText = equipmentBonus == 0 ? "" : " + equipment bonus \(equipmentBonus)"
        let outcome = success ? "Success." : "Failure."
        return "\(skill.displayName) check: d20 \(dieRoll) + \(linkedAttribute.displayName) modifier \(attributeModifier)\(trainingText)\(equipmentText) = \(total) vs Target \(target). \(outcome)"
    }
}

enum SkillCheckHelper {
    static func trainingBonus(for hero: Hero) -> Int {
        ProgressionRules.versionOne.trainingBonus(for: hero.level) ?? 0
    }

    static func check(hero: Hero, skill: SkillType, target: Int) -> SkillCheckResult {
        let linkedAttribute = skill.linkedAttribute
        let dieRoll = Int.random(in: 1...20)
        let attributeModifier = hero.attributes.modifier(for: linkedAttribute)
        let isTrained = hero.trainedSkills.contains(skill)
        let trainingBonus = isTrained ? trainingBonus(for: hero) : 0
        let equipmentBonus = ItemData.skillBonus(for: skill, hero: hero)
        let total = dieRoll + attributeModifier + trainingBonus + equipmentBonus

        return SkillCheckResult(
            skill: skill,
            linkedAttribute: linkedAttribute,
            dieRoll: dieRoll,
            attributeModifier: attributeModifier,
            trainingBonus: trainingBonus,
            equipmentBonus: equipmentBonus,
            target: target,
            total: total,
            isTrained: isTrained,
            success: total >= target,
            natural20: dieRoll == 20,
            natural1: dieRoll == 1
        )
    }
}
