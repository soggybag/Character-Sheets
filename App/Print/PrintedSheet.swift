import CharacterKit
import SwiftUI

/// The printed character sheet, as a list of blocks that the paginator packs
/// onto pages: the sheet first, then the notes. Black on white, sized in
/// points, independent of the on-screen layout.
@MainActor
struct PrintedSheet {
    let file: CharacterFile
    let analysis: RulesAnalysis
    let fallbackName: String

    init(file: CharacterFile, fallbackName: String) {
        self.file = file
        self.analysis = RulesAnalysis(file)
        self.fallbackName = fallbackName
    }

    var title: String { file.string(["name"]).flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName }

    /// Blocks in page order. A block marked `newPage` starts a fresh page.
    var blocks: [PrintBlock] {
        var blocks: [PrintBlock] = [
            PrintBlock(header),
            PrintBlock(abilitiesAndCombat),
            PrintBlock(saves),
        ]
        if !analysis.weapons.isEmpty { blocks.append(PrintBlock(weapons)) }
        blocks.append(PrintBlock(skillsAndLanguages))
        if showsThiefSkills { blocks.append(PrintBlock(thiefSkills)) }
        if hasSpells { blocks.append(PrintBlock(spells)) }
        if file.count(["equipment"]) > 0 { blocks.append(PrintBlock(equipment)) }
        blocks.append(PrintBlock(money))
        // Notes start a new page. Most bodies open with their own heading.
        let parsed = MarkdownBlock.parse(file.body)
        var notes: [PrintBlock] = []
        for (index, block) in parsed.enumerated() {
            let previous = index > 0 ? parsed[index - 1] : nil
            switch (block, previous) {
            case (.heading, _):
                notes.append(PrintBlock(PrintMarkdownBlock(block: block), spacing: 12, keepWithNext: true))
            case (.bullet, .bullet?):
                notes.append(PrintBlock(PrintMarkdownBlock(block: block), spacing: 3))
            default:
                notes.append(PrintBlock(PrintMarkdownBlock(block: block), spacing: 7))
            }
        }
        let hasText = parsed.contains { if case .heading = $0 { false } else { true } }
        if hasText {
            if case .heading = parsed[0] {} else {
                notes.insert(PrintBlock(PrintMarkdownBlock(block: .heading(1, "Notes")), keepWithNext: true), at: 0)
            }
            notes[0].newPage = true
            blocks += notes
        }
        return blocks
    }

    // MARK: Values

    /// The stored number, or the rules value when nothing is stored.
    private func number(_ path: NodePath) -> String {
        if let value = file.int(path) { return String(value) }
        if case let .int(value)? = analysis.suggestions[path] { return String(value) }
        return ""
    }

    private func text(_ path: NodePath) -> String { file.string(path) ?? "" }

    private var hasSpells: Bool {
        file.count(["spells", "spellbook"]) > 0 || file.count(["spells", "memorized"]) > 0
            || analysis.classRules?.spellcasting != nil
    }

    // MARK: Blocks

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
            HStack(alignment: .top, spacing: 14) {
                PrintField(label: "Class", value: text(["class"]), width: 110)
                PrintField(label: "Level", value: number(["level"]), width: 40)
                PrintField(label: "Alignment", value: text(["alignment"]), width: 80)
                PrintField(label: "XP", value: file.int(["xp"]).map { $0.formatted() } ?? "", width: 70,
                           note: analysis.xp?.nextLevel.map { "next \($0.formatted())" })
                PrintField(label: "Title", value: text(["title"]), width: 110)
                PrintField(label: "Player", value: text(["player"]))
            }
        }
    }

    private var abilitiesAndCombat: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                PrintHeading("Abilities")
                HStack(spacing: 5) {
                    ForEach(["str", "int", "wis", "dex", "con", "cha"], id: \.self) { key in
                        PrintBox(label: key.uppercased(), value: number(["abilityScores", .key(key)]), width: 38,
                                 note: file.int(["abilityScores", .key(key)]) == nil ? nil
                                     : analysis.abilities[key]?.headline)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                PrintHeading("Combat")
                HStack(spacing: 5) {
                    PrintBox(label: "HP", value: file.int(["hp", "current"]).map(String.init) ?? "", width: 44)
                    PrintBox(label: "Max HP", value: number(["hp", "max"]), width: 44,
                             note: analysis.hitDice.map { "HD \($0)" })
                    PrintBox(label: "AC", value: number(["combat", "ac"]), width: 38)
                    if file.usesAscendingAC {
                        PrintBox(label: "Attack", value: signedNumber(["combat", "attackBonus"]), width: 40)
                    } else {
                        PrintBox(label: "THAC0", value: number(["combat", "thac0"]), width: 40)
                    }
                    PrintBox(label: "Move", value: number(["movement"]).isEmpty ? "" : number(["movement"]) + "'",
                             width: 48, note: Int(number(["movement"])).map { "\($0 / 3)' / rd" })
                }
            }
        }
    }

    private func signedNumber(_ path: NodePath) -> String {
        guard let value = Int(number(path)) else { return "" }
        return value >= 0 ? "+\(value)" : "−\(-value)"
    }

    private var saves: some View {
        VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Saving Throws")
            HStack(alignment: .top, spacing: 6) {
                ForEach([("Death", "death"), ("Wands", "wands"), ("Paralysis", "paralysis"),
                         ("Breath", "breath"), ("Spells", "spells")], id: \.1) { label, key in
                    PrintBox(label: label, value: number(["saves", .key(key)]), width: 58)
                }
                if let wis = analysis.abilities["wis"]?.headline, wis != "+0" {
                    Text("\(wis) vs. magic (WIS)")
                        .font(.system(size: 8))
                        .foregroundStyle(PrintStyle.faint)
                        .padding(.top, 14)
                }
            }
        }
    }

    private var weapons: some View {
        VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Weapons")
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 3) {
                GridRow {
                    Text("Weapon"); Text("Melee"); Text("Missile"); Text("Range")
                }
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(PrintStyle.faint)
                ForEach(analysis.weapons, id: \.itemIndex) { weapon in
                    GridRow {
                        Text(weapon.name)
                        Text(weapon.melee.map { "\($0.notation)  \($0.damage)" } ?? "—")
                        Text(weapon.missile.map { "\($0.notation)  \($0.damage)" } ?? "—")
                        Text(weapon.range.map { "\($0.short) / \($0.medium) / \($0.long)'" } ?? "")
                    }
                    .font(.system(size: 9.5).monospacedDigit())
                }
            }
            Text("THAC0 [attack bonus] and damage, including STR for melee and DEX for missiles.")
                .font(.system(size: 7.5))
                .foregroundStyle(PrintStyle.faint)
        }
    }

    private var skillsAndLanguages: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                PrintHeading("Exploration (in 6)")
                HStack(spacing: 6) {
                    ForEach([("Listen", "listen"), ("Secret", "secretDoors"), ("Doors", "openDoors"),
                             ("Traps", "findTraps")], id: \.1) { label, key in
                        PrintBox(label: label, value: number(["exploration", .key(key)]), width: 40)
                    }
                    if !number(["exploration", "constructionTricks"]).isEmpty {
                        PrintBox(label: "Constr.", value: number(["exploration", "constructionTricks"]), width: 40)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                PrintHeading("Languages")
                Text(file.strings(["languages"]).joined(separator: ", "))
                    .font(.system(size: 9.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var showsThiefSkills: Bool {
        analysis.classRules?.name == "Thief" || file.count(["thiefSkills"]) > 0
    }

    private var thiefSkills: some View {
        VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Thief Skills")
            HStack(spacing: 5) {
                ForEach([("Climb", "climb", "%"), ("Traps", "traps", "%"), ("Hear", "hearNoise", ""),
                         ("Hide", "hide", "%"), ("Move", "moveSilently", "%"), ("Locks", "openLocks", "%"),
                         ("Pockets", "pickPockets", "%")], id: \.1) { label, key, unit in
                    let value = number(["thiefSkills", .key(key)])
                    PrintBox(label: label, value: value.isEmpty ? "" : value + unit, width: 46)
                }
            }
        }
    }

    private var spells: some View {
        VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Spells")
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 3) {
                    PrintLabel("Per day")
                    let slots = (0..<file.count(["spells", "slots"])).compactMap { file.int(["spells", "slots", .index($0)]) }
                    let shown = slots.isEmpty ? suggestedSlots : slots
                    Text(shown.isEmpty ? "—" : shown.enumerated().map { "L\($0.offset + 1): \($0.element)" }.joined(separator: "  "))
                        .font(.system(size: 9.5).monospacedDigit())
                }
                VStack(alignment: .leading, spacing: 3) {
                    PrintLabel("Spells (level) · a box per memorized copy, ticked when cast")
                    ForEach(file.spellRows.indices, id: \.self) { index in
                        let row = file.spellRows[index]
                        HStack(spacing: 4) {
                            Text(row.name + (row.level.map { "  (\($0))" } ?? ""))
                                .font(.system(size: 9.5))
                            ForEach(row.memorized, id: \.self) { copy in
                                PrintCheckbox(checked: file.isCast(memorized: copy))
                            }
                        }
                    }
                }
            }
        }
    }

    private var suggestedSlots: [Int] {
        if case let .ints(values)? = analysis.suggestions[["spells", "slots"]] { return values }
        return []
    }

    private var equipment: some View {
        let count = file.count(["equipment"])
        let half = (count + 1) / 2
        return VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Equipment")
            HStack(alignment: .top, spacing: 24) {
                ForEach([0..<half, half..<count], id: \.lowerBound) { range in
                    VStack(alignment: .leading, spacing: 2.5) {
                        ForEach(Array(range), id: \.self) { index in
                            equipmentLine(index)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func equipmentLine(_ index: Int) -> some View {
        let path: NodePath = ["equipment", .index(index)]
        var details: [String] = []
        if let damage = file.string(path + ["damage"]) { details.append(damage) }
        if let notes = file.string(path + ["notes"]) { details.append(notes) }
        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(file.bool(path + ["equipped"]) == true ? "●" : "○")
                .font(.system(size: 6))
                .foregroundStyle(PrintStyle.faint)
            Text(text(path + ["name"]) + (file.int(path + ["qty"]).map { " ×\($0)" } ?? ""))
                .font(.system(size: 9.5))
            if !details.isEmpty {
                Text(details.joined(separator: " · "))
                    .font(.system(size: 8))
                    .foregroundStyle(PrintStyle.faint)
            }
        }
    }

    private var money: some View {
        VStack(alignment: .leading, spacing: 4) {
            PrintHeading("Money")
            HStack(spacing: 6) {
                ForEach(["pp", "gp", "ep", "sp", "cp"], id: \.self) { key in
                    PrintBox(label: key.uppercased(), value: file.int(["money", .key(key)]).map { $0.formatted() } ?? "",
                             width: 64)
                }
                Text("● equipped")
                    .font(.system(size: 7.5))
                    .foregroundStyle(PrintStyle.faint)
                    .padding(.leading, 12)
                    .padding(.top, 14)
            }
        }
    }
}

// MARK: - Building blocks

struct PrintBlock {
    let view: AnyView
    var newPage = false
    /// Space above the block when it isn't first on its page.
    var spacing: CGFloat = 14
    /// Moves to the next page with the block after it rather than end a page (headings).
    var keepWithNext = false

    init(_ view: some View, newPage: Bool = false, spacing: CGFloat = 14, keepWithNext: Bool = false) {
        self.view = AnyView(view)
        self.newPage = newPage
        self.spacing = spacing
        self.keepWithNext = keepWithNext
    }
}

enum PrintStyle {
    static let ink = Color.black
    static let faint = Color(white: 0.4)
    static let rule = Color(white: 0.7)
}

struct PrintHeading: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold))
            .tracking(1)
            .foregroundStyle(PrintStyle.faint)
    }
}

struct PrintLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 7.5, weight: .semibold))
            .foregroundStyle(PrintStyle.faint)
    }
}

/// A boxed number with a label above and an optional note below.
struct PrintBox: View {
    let label: String
    let value: String
    var width: CGFloat = 44
    var note: String?

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(PrintStyle.faint)
                .lineLimit(1)
            Text(value.isEmpty ? " " : value)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .frame(width: width, height: 24)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(PrintStyle.rule, lineWidth: 0.75))
            Text(note.flatMap { $0.isEmpty ? nil : $0 } ?? " ")
                .font(.system(size: 7.5).monospacedDigit())
                .foregroundStyle(PrintStyle.faint)
                .lineLimit(1)
        }
    }
}

/// A label over a value on a line, like a form field.
struct PrintField: View {
    let label: String
    let value: String
    var width: CGFloat?
    var note: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            PrintLabel(label)
            Text(value.isEmpty ? " " : value)
                .font(.system(size: 11))
                .lineLimit(1)
            Rectangle().fill(PrintStyle.rule).frame(height: 0.75)
            if let note {
                Text(note).font(.system(size: 7.5)).foregroundStyle(PrintStyle.faint)
            }
        }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}

struct PrintCheckbox: View {
    let checked: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .stroke(PrintStyle.ink, lineWidth: 0.75)
            .frame(width: 8, height: 8)
            .overlay { if checked { Image(systemName: "checkmark").font(.system(size: 6, weight: .bold)) } }
    }
}

/// One block of the notes, in print sizes.
struct PrintMarkdownBlock: View {
    let block: MarkdownBlock

    var body: some View {
        switch block {
        case let .heading(level, text):
            Text(inline(text))
                .font(.system(size: level == 1 ? 15 : level == 2 ? 12.5 : 11, weight: .semibold, design: .serif))
                .padding(.top, 4)
        case let .paragraph(text):
            Text(inline(text)).font(.system(size: 10)).lineSpacing(1.5)
        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•")
                Text(inline(text)).lineSpacing(1.5)
            }
            .font(.system(size: 10))
            .padding(.leading, 4)
        case let .code(text):
            Text(text).font(.system(size: 9, design: .monospaced))
        case .rule:
            Rectangle().fill(PrintStyle.rule).frame(height: 0.75)
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
