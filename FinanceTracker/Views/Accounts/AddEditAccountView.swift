import SwiftUI
import SwiftData

/// Form for creating or editing a financial Account (e.g. Bank Account, Credit Card, Cash Wallet).
struct AddEditAccountView: View {

    // MARK: - Bindings & Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    var accountToEdit: Account?

    // MARK: - Form State
    @State private var name: String = ""
    @State private var institution: String = ""
    @State private var accountType: AccountType = .bank
    @State private var accountNumberLast4: String = ""
    @State private var initialBalanceText: String = ""
    @State private var currency: String = "MYR"
    @State private var selectedColorHex: String = "#1C1C1E"
    @State private var selectedIcon: String = "building.columns.fill"
    @State private var isDefault: Bool = false
    @State private var note: String = ""

    // MARK: - Popular Bank Templates
    private struct BankTemplate: Identifiable {
        let id = UUID()
        let name: String
        let institution: String
        let defaultType: AccountType
        let colorHex: String
        let icon: String
    }

    private let popularBanks: [BankTemplate] = [
        BankTemplate(name: "Maybank Checking", institution: "Maybank", defaultType: .bank, colorHex: "#2C2C2E", icon: "building.columns.fill"),
        BankTemplate(name: "CIMB Current", institution: "CIMB", defaultType: .bank, colorHex: "#3A3A3C", icon: "building.columns.fill"),
        BankTemplate(name: "Public Bank Savings", institution: "Public Bank", defaultType: .savings, colorHex: "#1C1C1E", icon: "leaf.fill"),
        BankTemplate(name: "RHB Account", institution: "RHB", defaultType: .bank, colorHex: "#2C2C2E", icon: "building.columns.fill"),
        BankTemplate(name: "Hong Leong", institution: "Hong Leong", defaultType: .bank, colorHex: "#3A3A3C", icon: "building.columns.fill"),
        BankTemplate(name: "Touch 'n Go eWallet", institution: "Touch 'n Go", defaultType: .eWallet, colorHex: "#1C1C1E", icon: "wallet.pass.fill"),
        BankTemplate(name: "Cash Wallet", institution: "Cash", defaultType: .cash, colorHex: "#2C2C2E", icon: "banknote.fill"),
        BankTemplate(name: "Credit Card", institution: "Bank", defaultType: .creditCard, colorHex: "#1C1C1E", icon: "creditcard.fill"),
        BankTemplate(name: "Chase Checking", institution: "Chase", defaultType: .bank, colorHex: "#2C2C2E", icon: "building.columns.fill"),
        BankTemplate(name: "Bank of America", institution: "BofA", defaultType: .bank, colorHex: "#1C1C1E", icon: "building.columns.fill")
    ]

    private let curatedColors: [String] = [
        "#1C1C1E", // Obsidian
        "#2C2C2E", // Graphite
        "#3A3A3C", // Charcoal
        "#48484A", // Slate
        "#636366", // Steel
        "#1B263B", // Navy Black
        "#1E3D2F", // Forest Obsidian
        "#3D1E1E"  // Deep Wine
    ]

    private let availableIcons: [String] = [
        "building.columns.fill",
        "creditcard.fill",
        "banknote.fill",
        "wallet.pass.fill",
        "leaf.fill",
        "chart.line.uptrend.xyaxis",
        "chart.pie.fill",
        "dollarsign.circle.fill",
        "safe.fill"
    ]

    // MARK: - Computed
    private var isEditing: Bool { accountToEdit != nil }

    private var initialBalanceDouble: Double {
        Double(initialBalanceText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ── Preview Card ──────────────────────────────────────────
                Section {
                    previewCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                // ── Popular Quick Templates ───────────────────────────────
                if !isEditing {
                    Section(header: Text("Quick Bank / Account Templates")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(popularBanks) { template in
                                    Button {
                                        applyTemplate(template)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: template.icon)
                                                .font(.caption2)
                                            Text(template.institution)
                                                .font(.caption.weight(.medium))
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color(.secondarySystemGroupedBackground))
                                        .foregroundStyle(Color.primary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // ── Account Type ──────────────────────────────────────────
                Section(header: Text("Account Type")) {
                    Picker("Type", selection: $accountType) {
                        ForEach(AccountType.allCases) { type in
                            Label(type.displayName, systemImage: type.defaultIcon).tag(type)
                        }
                    }
                    .onChange(of: accountType) { _, newType in
                        selectedIcon = newType.defaultIcon
                    }
                }

                // ── Basic Details ─────────────────────────────────────────
                Section(header: Text("Account Details")) {
                    TextField("Account Name (e.g. Main Checking)", text: $name)

                    TextField("Bank / Institution (e.g. Maybank, CIMB, Cash)", text: $institution)

                    TextField("Last 4 Digits (optional, e.g. 4821)", text: $accountNumberLast4)
                        .keyboardType(.numberPad)
                }

                // ── Balance & Currency ────────────────────────────────────
                Section(
                    header: Text("Starting Balance"),
                    footer: Text(accountType == .creditCard ? "For credit cards, enter current outstanding balance." : "Enter your balance as of today. Future transactions linked to this account will update it automatically.")
                ) {
                    HStack {
                        Text(currency)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField("0.00", text: $initialBalanceText)
                            .keyboardType(.decimalPad)
                            .font(.body.weight(.semibold))
                    }

                    TextField("Currency Code (e.g. MYR, USD)", text: $currency)
                        .textInputAutocapitalization(.characters)
                }

                // ── Card Style ────────────────────────────────────────────
                Section(header: Text("Card Color & Icon")) {
                    // Color Palette
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Card Theme")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ForEach(curatedColors, id: \.self) { hex in
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColorHex == hex ? 2.5 : 0)
                                    )
                                    .overlay(
                                        selectedColorHex == hex ?
                                        Image(systemName: "checkmark")
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                        : nil
                                    )
                                    .onTapGesture {
                                        selectedColorHex = hex
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Icon Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableIcons, id: \.self) { iconName in
                                    Image(systemName: iconName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == iconName ? Color.primary : Color(.tertiarySystemFill))
                                        .foregroundStyle(selectedIcon == iconName ? Color(.systemBackground) : Color.primary)
                                        .clipShape(Circle())
                                        .onTapGesture {
                                            selectedIcon = iconName
                                        }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Preferences ───────────────────────────────────────────
                Section(header: Text("Preferences")) {
                    Toggle("Set as Default Account", isOn: $isDefault)

                    TextField("Notes (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "Edit Account" : "New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                }
            }
            .onAppear(perform: loadInitial)
        }
    }

    // MARK: - Preview Card
    private var previewCard: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: selectedColorHex), Color(hex: selectedColorHex).opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                .frame(height: 120)

            // Large Watermark Icon
            Image(systemName: selectedIcon)
                .font(.system(size: 70, weight: .bold))
                .foregroundStyle(.white.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8)
                .padding(.trailing, 12)
                .clipped()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(institution.isEmpty ? "BANK ACCOUNT" : institution.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    if !accountNumberLast4.isEmpty {
                        Text("•••• \(accountNumberLast4)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                Spacer()

                Text(name.isEmpty ? "Account Name" : name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(initialBalanceDouble.currencyString(code: currency))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(14)
        }
    }

    // MARK: - Actions
    private func applyTemplate(_ template: BankTemplate) {
        institution = template.institution
        name = template.name
        accountType = template.defaultType
        selectedColorHex = template.colorHex
        selectedIcon = template.icon
    }

    private func loadInitial() {
        if let acc = accountToEdit {
            name = acc.name
            institution = acc.institution
            accountType = acc.accountType
            accountNumberLast4 = acc.accountNumberLast4
            initialBalanceText = String(format: "%.2f", acc.initialBalance)
            currency = acc.currency
            selectedColorHex = acc.colorHex
            selectedIcon = acc.icon
            isDefault = acc.isDefault
            note = acc.note
        } else {
            currency = appState.selectedLedger?.currency ?? "MYR"
        }
    }

    private func save() {
        if let existing = accountToEdit {
            existing.name = name.trimmingCharacters(in: .whitespaces)
            existing.institution = institution.trimmingCharacters(in: .whitespaces)
            existing.accountType = accountType
            existing.accountNumberLast4 = accountNumberLast4.trimmingCharacters(in: .whitespaces)
            existing.initialBalance = initialBalanceDouble
            existing.currency = currency.trimmingCharacters(in: .whitespaces).uppercased()
            existing.colorHex = selectedColorHex
            existing.icon = selectedIcon
            existing.isDefault = isDefault
            existing.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            let newAcc = Account(
                name: name.trimmingCharacters(in: .whitespaces),
                institution: institution.trimmingCharacters(in: .whitespaces),
                accountType: accountType,
                accountNumberLast4: accountNumberLast4.trimmingCharacters(in: .whitespaces),
                initialBalance: initialBalanceDouble,
                currency: currency.trimmingCharacters(in: .whitespaces).uppercased(),
                colorHex: selectedColorHex,
                icon: selectedIcon,
                isDefault: isDefault,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            modelContext.insert(newAcc)
        }

        try? modelContext.save()
        dismiss()
    }
}
