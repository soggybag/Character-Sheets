import CharacterKit
import SwiftUI
import UniformTypeIdentifiers

struct EquipmentSection: View {
    @Binding var file: CharacterFile
    let analysis: RulesAnalysis
    @State private var isShopping = false
    /// Marks drags from this sheet, so a row dropped from another sheet's
    /// list isn't taken for one of these.
    @State private var dragToken = UUID().uuidString
    /// How many cells of each row a drag is over. A row's cells report
    /// separately, so a count keeps the line steady moving across them.
    @State private var dragOver: [Int: Int] = [:]

    var body: some View {
        SheetSection(title: "Equipment") {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("")
                    Image(systemName: "hand.raised").help("Equipped").accessibilityLabel("Equipped")
                    Text("Item")
                    Text("Qty")
                    Text("Damage")
                    Text("Notes")
                    Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                }
                .zoomFont(.caption)
                .foregroundStyle(.secondary)

                ForEach(0..<file.count(["equipment"]), id: \.self) { index in
                    let path: NodePath = ["equipment", .index(index)]
                    GridRow {
                        dragHandle(index)
                        Toggle("Equipped", isOn: $file.flag(path + ["equipped"]))
                            .labelsHidden()
                            .help("Equipped")
                            .accessibilityLabel("Equipped: \(file.string(path + ["name"]) ?? "")")
                        CommitTextField("Item", text: $file.string(path + ["name"]), prompt: "Item")
                            .zoomFrame(minWidth: 120)
                        HStack(spacing: 2) {
                            NumberField(label: "Qty", value: $file.int(path + ["qty"]), prompt: "1")
                                .zoomFrame(width: 40)
                            if let quantity = file.int(path + ["qty"]), quantity > 0 {
                                ListButton(title: "Use one", systemImage: "minus.square") {
                                    file.useOne(ofItemAt: index)
                                }
                            }
                        }
                        .zoomFrame(width: 64, alignment: .leading)
                        // The rules damage, shown in grey when none is typed.
                        let damage = analysis.itemDamage[index] ?? ""
                        CommitTextField("Damage", text: $file.string(path + ["damage"]), prompt: damage,
                                        fillOnReturn: damage)
                            .help(damage.isEmpty ? "Damage" : "Damage. The rules give \(damage); press Return to fill it in.")
                            .zoomFrame(width: 60)
                        // What the item is, from the rules or the custom list.
                        let details = analysis.itemDetails[index] ?? ""
                        CommitTextField("Notes", text: $file.string(path + ["notes"]), prompt: details,
                                        fillOnReturn: details)
                            .help(details.isEmpty ? "Notes"
                                  : "Notes. In grey: \(details.trimmingCharacters(in: ["."])). Press Return to keep it in the file.")
                            .zoomFrame(minWidth: 100)
                        ListButton(title: "Remove item", systemImage: "minus.circle") {
                            file.removeItem(at: path)
                        }
                    }
                    .textFieldStyle(.plain)
                    .overlay(alignment: .top) {
                        if dragOver[index, default: 0] > 0 {
                            Rectangle().fill(Color.accentColor).frame(height: 2).offset(y: -4)
                        }
                    }
                    .dropDestination(for: EquipmentRowDrag.self) { items, _ in
                        dragOver = [:]
                        guard let drag = items.first, drag.token == dragToken,
                              drag.index < file.count(["equipment"]) else { return false }
                        file.moveItem(in: ["equipment"], from: drag.index, to: index)
                        return true
                    } isTargeted: { over in
                        dragOver[index, default: 0] += over ? 1 : -1
                    }
                }
            }
            HStack(spacing: 12) {
                ListButton(title: "Add item", systemImage: "plus.circle") {
                    file.appendItem(to: ["equipment"])
                }
                Button("Add from List…") { isShopping = true }
                    .help("Buy or add weapons, armour and gear from the rules")
            }
        }
        .sheet(isPresented: $isShopping) {
            ShopView(rules: analysis.rules, classRules: analysis.classRules,
                     purse: Purse(file)) { item, count, pay in
                file.buy(item, count: count, pay: pay)
            }
        }
    }

    /// Drag to reorder; right-click to move up, down, to the top or bottom.
    private func dragHandle(_ index: Int) -> some View {
        let count = file.count(["equipment"])
        let name = file.string(["equipment", .index(index), "name"]) ?? "Item"
        return Image(systemName: "line.3.horizontal")
            .foregroundStyle(.tertiary)
            .frame(width: 14, height: 18)
            .contentShape(.rect)
            .help("Drag to move \(name). Right-click for more.")
            .draggable(EquipmentRowDrag(token: dragToken, index: index)) {
                Text(name).padding(4)
            }
            .contextMenu {
                Button("Move Up") { move(index, to: index - 1) }.disabled(index == 0)
                Button("Move Down") { move(index, to: index + 1) }.disabled(index == count - 1)
                Divider()
                Button("Move to Top") { move(index, to: 0) }.disabled(index == 0)
                Button("Move to Bottom") { move(index, to: count - 1) }.disabled(index == count - 1)
            }
            .accessibilityLabel("Move \(name)")
    }

    private func move(_ from: Int, to: Int) {
        file.moveItem(in: ["equipment"], from: from, to: to)
    }
}

/// An equipment row being dragged. Its own type, so text fields don't take
/// it as text, and a token so another sheet's rows aren't moved here.
struct EquipmentRowDrag: Codable, Transferable {
    let token: String
    let index: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .equipmentRow)
    }
}

extension UTType {
    static let equipmentRow = UTType(exportedAs: "com.mitchellhudson.CharacterSheets.equipment-row")
}

struct MoneySection: View {
    @Binding var file: CharacterFile

    private let coins = [("PP", "pp", "Platinum"), ("GP", "gp", "Gold"), ("EP", "ep", "Electrum"),
                         ("SP", "sp", "Silver"), ("CP", "cp", "Copper")]

    var body: some View {
        SheetSection(title: "Money") {
            FlowLayout {
                ForEach(coins, id: \.1) { label, key, name in
                    StatBox(label: label, value: $file.int(["money", .key(key)]), width: 80, help: "\(name) pieces")
                }
            }
        }
    }
}
