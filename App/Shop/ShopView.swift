import CharacterKit
import SwiftUI

/// The ruleset's equipment lists: search, pick, and add to a character,
/// paying from their money or not. Stays open for buying several things.
/// Items the class can't normally use are marked, never hidden.
struct ShopView: View {
    /// The rules the character is played with: their items and restrictions.
    let rules: OSERuleset
    let classRules: ClassRules?
    /// The money available; the shop shows it and checks costs against it.
    let purse: Purse
    /// Adds `count` of the item, paying if asked. Returns false if the
    /// money doesn't cover it.
    let buy: (_ item: ShopItem, _ count: Int, _ pay: Bool) -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var selection: ShopItem.ID?
    @State private var count = 1
    @State private var pay = true
    @State private var lastAdded: String?

    @State private var store = EquipmentListStore.shared
    /// The list chosen in Settings, or nil for the rules list.
    private var customList: EquipmentList? { store.list }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $search, prompt: Text("Search equipment"))
                .textFieldStyle(.roundedBorder)
                .padding(12)
            if store.url != nil { listBanner }
            list
            Divider()
            footer
        }
        .frame(width: 560, height: 560)
        .onChange(of: selection) { count = 1 }
        .onAppear { store.reload() }
    }

    /// Which list the prices come from, and whether it has problems.
    private var listBanner: some View {
        HStack(alignment: .firstTextBaseline) {
            if store.list != nil {
                Label("Prices from \(store.name ?? "a custom list")", systemImage: "bag")
            } else {
                Label("Rules prices: the custom list can't be used", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            Spacer()
            if !store.problems.isEmpty {
                Text(store.problems.count == 1 ? "1 problem" : "\(store.problems.count) problems")
                    .foregroundStyle(.orange)
                    .help(store.problems.joined(separator: "\n"))
            }
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var items: [ShopItem] {
        let all = rules.shopItems(with: customList)
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return all }
        return all.filter { $0.name.localizedStandardContains(query) || $0.details.localizedStandardContains(query) }
    }

    private var list: some View {
        let items = items
        return List(selection: $selection) {
            ForEach(ShopItem.Category.allCases, id: \.self) { category in
                let inCategory = items.filter { $0.category == category }
                if !inCategory.isEmpty {
                    Section(category.rawValue) {
                        ForEach(inCategory) { item in
                            row(item).tag(item.id)
                        }
                    }
                }
            }
        }
        .contextMenu(forSelectionType: ShopItem.ID.self) { _ in
        } primaryAction: { ids in
            if let id = ids.first, let item = items.first(where: { $0.id == id }) { add(item) }
        }
    }

    private func row(_ item: ShopItem) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.name)
                    if item.origin == .house {
                        Text("House")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .background(.quaternary, in: .capsule)
                            .help("Not in the rules: from \(customList?.name ?? "the custom list")")
                    }
                    if let restriction = rules.restriction(of: item, for: classRules) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .help(restriction)
                            .accessibilityLabel("Class warning")
                            .accessibilityValue(restriction)
                    }
                }
                if !item.details.isEmpty {
                    Text(item.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(cost(item))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .help(rulesPriceHelp(item))
        }
        .padding(.vertical, 2)
    }

    private func cost(_ item: ShopItem, count: Int = 1) -> String {
        Purse.priceText(item.price * count)
    }

    private func rulesPriceHelp(_ item: ShopItem) -> String {
        guard case let .changed(rulesPrice) = item.origin else { return "" }
        return "Rules price: \(Purse.priceText(rulesPrice))"
    }

    // MARK: Footer

    private var selected: ShopItem? {
        rules.shopItems(with: customList).first { $0.id == selection }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Money: \(purse.description)")
                    .monospacedDigit()
                Spacer()
                if let lastAdded {
                    Label(lastAdded, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green, .secondary)
                        .lineLimit(1)
                }
            }
            .font(.callout)
            if let selected {
                if let restriction = rules.restriction(of: selected, for: classRules) {
                    Label(restriction + " You can still add it.", systemImage: "exclamationmark.triangle")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Stepper(value: $count, in: 1...99) {
                        Text("Buy \(count) × \(selected.name)")
                            .lineLimit(1)
                    }
                    .fixedSize()
                    Spacer()
                    Toggle("Pay \(cost(selected, count: count))", isOn: $pay)
                        .disabled(selected.price == 0)
                }
                if pay, !canAfford(selected) {
                    Text("Not enough money. Untick Pay to add it anyway (found, looted or a gift).")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Choose an item, then Add (or double-click it). Items marked ⚠︎ aren't normally used by this class.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { if let selected { add(selected) } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.map { pay && !canAfford($0) } ?? true)
            }
        }
        .padding(12)
    }

    private func canAfford(_ item: ShopItem) -> Bool {
        item.price * count <= purse.totalCP
    }

    private func add(_ item: ShopItem) {
        let paying = pay && item.price > 0
        guard buy(item, count, paying) else {
            NSSound.beep()
            return
        }
        let amount = (item.quantity ?? 1) * count
        lastAdded = "Added \(item.itemName)\(amount > 1 ? " × \(amount)" : "")"
            + (paying ? ", paid \(cost(item, count: count))" : "")
        count = 1
    }
}
