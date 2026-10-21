import CharacterKit
import SwiftUI

struct IdentitySection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    let placeholderName: String
    let levelUp: () -> Void
    let levelDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CommitTextField("Name", text: $file.string(["name"]), prompt: placeholderName)
                .textFieldStyle(.plain)
                .zoomFont(size: 30, weight: .semibold, design: .serif)
            // One line when there's room; in a narrow window, level and XP
            // move under class and alignment.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .fieldLine, spacing: 20) {
                    classAndAlignment
                    levelAndXP
                }
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .fieldLine, spacing: 20) { classAndAlignment }
                    HStack(alignment: .fieldLine, spacing: 20) {
                        levelAndXP
                        Spacer(minLength: 0)
                    }
                }
            }
            HStack(spacing: 20) {
                LineField(label: "Title", text: $file.string(["title"]))
                LineField(label: "Player", text: $file.string(["player"]))
            }
        }
    }

    @ViewBuilder private var classAndAlignment: some View {
        LineField(label: "Class", text: $file.string(["class"]), suggestions: analysis.rules.classes.map(\.name))
            .zoomFrame(minWidth: 110)
        LineField(label: "Alignment", text: $file.string(["alignment"]), suggestions: analysis.rules.alignments)
            .zoomFrame(minWidth: 110)
    }

    @ViewBuilder private var levelAndXP: some View {
        LineNumberField(label: "Level", value: $file.int(["level"]))
            .zoomFrame(width: 60)
        LineNumberField(label: "XP", value: $file.int(["xp"]), caption: xpCaption)
            .zoomFrame(width: 110)
            .help(xpHelp)
        levelUpButton
            .alignmentGuide(.fieldLine) { $0[VerticalAlignment.center] }
    }

    private var xpCaption: String? {
        guard let xp = analysis.xp else { return nil }
        let next = xp.nextLevel.map { "next \($0.formatted())" } ?? "max level"
        return xp.bonusPercent == 0 ? next : "\(next) · \(xp.bonusPercent.signedText)%"
    }

    private var xpHelp: String {
        guard let xp = analysis.xp else { return "Experience points" }
        var lines = ["Experience points"]
        if let next = xp.nextLevel { lines.append("Next level at \(next.formatted()) XP") }
        if xp.bonusPercent != 0 { lines.append("Prime requisite: \(xp.bonusPercent.signedText)% to XP awards") }
        return lines.joined(separator: "\n")
    }

    /// Level Up…, with Level Down… in its menu: losing a level is rare
    /// (energy drain) and shouldn't sit beside the everyday button.
    @ViewBuilder private var levelUpButton: some View {
        let button = Menu("Level Up…") {
            Button("Level Down…", action: levelDown)
                .disabled((analysis.level ?? 0) <= 1)
        } primaryAction: {
            levelUp()
        }
            .menuStyle(.button)
            .fixedSize()
            .disabled(analysis.classRules == nil || analysis.level == nil)
            .help(analysis.xp?.readyToLevelUp == true
                ? "Enough XP for the next level. Use the arrow to lose a level."
                : "Go up a level. Use the arrow to lose a level (energy drain).")
        if analysis.xp?.readyToLevelUp == true {
            button.buttonStyle(.borderedProminent)
        } else {
            button
        }
    }
}

struct AbilityScoresSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis

    private let scores = [("STR", "str", "Strength"), ("INT", "int", "Intelligence"), ("WIS", "wis", "Wisdom"),
                          ("DEX", "dex", "Dexterity"), ("CON", "con", "Constitution"), ("CHA", "cha", "Charisma")]

    var body: some View {
        SheetSection(title: "Ability Scores") {
            FlowLayout {
                ForEach(scores, id: \.1) { label, key, name in
                    let effects = analysis.abilities[key]
                    StatBox(label: label, value: $file.int(["abilityScores", .key(key)]), help: name,
                            caption: effects.map { $0.headline.isEmpty ? " " : $0.headline },
                            captionHelp: effects?.effects.map { "\($0.label): \($0.value)" }.joined(separator: "\n"))
                }
            }
        }
    }
}
