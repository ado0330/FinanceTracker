import SwiftUI
import SwiftData

/// Form for creating a new `Ledger` or editing an existing one.
///
/// Fields: name, currency, icon, colour.
/// On save the new ledger is inserted and, if it's the first one, made default.
struct AddEditLedgerView: View {

    // MARK: - Bindings & Environment
    @Binding var ledger: Ledger?
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // Used to check "is this the first ledger ever?"
    @Query private var allLedgers: [Ledger]

    // MARK: - Form State
    @State private var name: String = ""
    @State private var currency: String = "MYR"
    @State private var icon: String = "creditcard.fill"
    @State private var colorHex: String = "#1C1C1E"

    // MARK: - Picker Data
    private let iconOptions: [String] = [
        "creditcard.fill", "banknote.fill", "briefcase.fill", "house.fill",
        "cart.fill", "airplane", "car.fill", "heart.fill",
        "globe.americas.fill", "building.columns.fill"
    ]

    private let popularCurrencies: [(code: String, label: String)] = [
        ("MYR", "🇲🇾 MYR – Malaysian Ringgit"),
        ("USD", "🇺🇸 USD – US Dollar"),
        ("SGD", "🇸🇬 SGD – Singapore Dollar"),
        ("EUR", "🇪🇺 EUR – Euro"),
        ("GBP", "🇬🇧 GBP – British Pound"),
        ("JPY", "🇯🇵 JPY – Japanese Yen"),
        ("SGD", "🇸🇬 SGD – Singapore Dollar"),
        ("AUD", "🇦🇺 AUD – Australian Dollar"),
        ("CAD", "🇨🇦 CAD – Canadian Dollar"),
        ("CNY", "🇨🇳 CNY – Chinese Yuan"),
        ("INR", "🇮🇳 INR – Indian Rupee"),
        ("THB", "🇹🇭 THB – Thai Baht"),
        ("IDR", "🇮🇩 IDR – Indonesian Rupiah"),
        ("KRW", "🇰🇷 KRW – Korean Won"),
        ("HKD", "🇭🇰 HKD – Hong Kong Dollar"),
        ("CHF", "🇨🇭 CHF – Swiss Franc"),
        ("NZD", "🇳🇿 NZD – New Zealand Dollar"),
        ("BRL", "🇧🇷 BRL – Brazilian Real"),
        ("ZAR", "🇿🇦 ZAR – South African Rand"),
    ]

    // MARK: - Init
    init(ledger: Binding<Ledger?>, onDismiss: @escaping () -> Void) {
        self._ledger = ledger
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {

                // ── Name ─────────────────────────────────────────────────
                Section(header: Text("Name")) {
                    TextField("e.g. Personal, Family, Travel", text: $name)
                        .accessibilityIdentifier("ledgerNameField")
                }

                // ── Currency ──────────────────────────────────────────────
                Section(header: Text("Currency")) {
                    Picker("Currency", selection: $currency) {
                        ForEach(popularCurrencies, id: \.code) { item in
                            Text(item.label).tag(item.code)
                        }
                    }
                    .accessibilityIdentifier("currencyPicker")
                }

                // ── Icon ──────────────────────────────────────────────────
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .font(.title2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(8)
                                .background(icon == symbol ? Color.primary.opacity(0.12) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture { icon = symbol }
                                .accessibilityIdentifier("icon_\(symbol)")
                        }
                    }
                }

                // ── Colour ────────────────────────────────────────────────
                Section(header: Text("Colour")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Color.presetPalette, id: \.self) { colour in
                            Circle()
                                .fill(colour)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle().stroke(
                                        Color.primary.opacity(colorHex == colour.hexString ? 1 : 0),
                                        lineWidth: 2
                                    )
                                )
                                .onTapGesture { colorHex = colour.hexString }
                                .accessibilityIdentifier("color_\(colour.hexString)")
                        }
                    }
                }

                // ── Preview ───────────────────────────────────────────────
                Section(header: Text("Preview")) {
                    HStack(spacing: 14) {
                        Image(systemName: icon)
                            .foregroundStyle(.white)
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 40, height: 40)
                            .background(Color(hex: colorHex))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Ledger Name" : name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(name.isEmpty ? .secondary : .primary)
                            Text(currency)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(ledger == nil ? "New Ledger" : "Edit Ledger")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveButton")
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    // MARK: - Helpers

    private func loadInitialValues() {
        guard let l = ledger else { return }
        name     = l.name
        currency = l.currency
        icon     = l.icon
        colorHex = l.colorHex
    }

    private func save() {
        if var existing = ledger {
            existing.name     = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.currency = currency
            existing.icon     = icon
            existing.colorHex = colorHex
        } else {
            let isFirst = allLedgers.isEmpty
            let new = Ledger(
                name:      name.trimmingCharacters(in: .whitespacesAndNewlines),
                icon:      icon,
                colorHex:  colorHex,
                currency:  currency,
                isDefault: isFirst
            )
            modelContext.insert(new)

            // Auto-select the very first ledger the user creates.
            if isFirst || appState.selectedLedger == nil {
                appState.selectedLedger = new
            }
        }
        try? modelContext.save()
        onDismiss()
    }
}
