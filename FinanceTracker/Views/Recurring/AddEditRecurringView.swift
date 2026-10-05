import SwiftUI
import SwiftData

/// Form for creating or editing a `RecurringRule`.
///
/// Fields:
///   - Type toggle (Income / Expense)
///   - Amount
///   - Category picker (filtered to match type)
///   - Note / description
///   - Frequency (Daily → Yearly)
///   - Start date
///   - Optional end date (with toggle)
struct AddEditRecurringView: View {

    // MARK: - Bindings & Environment
    @Binding var rule: RecurringRule?
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self)  private var appState

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    // MARK: - Form State
    @State private var type: TransactionType = .expense
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var startDate: Date = .now
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: .now) ?? .now
    @State private var selectedCategory: Category? = nil
    @State private var showCategoryPicker = false

    // MARK: - Computed
    private var isEditing: Bool { rule != nil }
    private var currency: String { appState.selectedLedger?.currency ?? "USD" }
    private var amountDouble: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }
    private var isFormValid: Bool { amountDouble > 0 }

    private var filteredCategories: [Category] {
        allCategories.filter {
            $0.type == .both || $0.type == CategoryType(transactionType: type)
        }
    }

    // MARK: - Init
    init(rule: Binding<RecurringRule?>, onDismiss: @escaping () -> Void) {
        self._rule = rule
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {

                // ── Type ──────────────────────────────────────────────
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { t in
                            Label(t.displayName, systemImage: t.systemImage).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in
                        // Reset category when type changes
                        if let cat = selectedCategory,
                           cat.type != .both,
                           cat.type != CategoryType(transactionType: type) {
                            selectedCategory = nil
                        }
                    }
                }

                // ── Amount ────────────────────────────────────────────
                Section(header: Text("Amount (\(currency))")) {
                    HStack {
                        Text(type == .income ? "+" : "−")
                            .foregroundStyle(type == .income ? .green : .primary)
                            .font(.title2.weight(.semibold))
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .font(.title2.weight(.semibold))
                            .accessibilityIdentifier("amountField")
                    }
                }

                // ── Category ──────────────────────────────────────────
                Section(header: Text("Category (optional)")) {
                    Button {
                        showCategoryPicker = true
                    } label: {
                        HStack {
                            if let cat = selectedCategory {
                                Image(systemName: cat.icon)
                                    .foregroundStyle(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color(hex: cat.colorHex))
                                    .clipShape(Circle())
                                Text(cat.name).foregroundStyle(.primary)
                            } else {
                                Image(systemName: "tag").foregroundStyle(.secondary)
                                Text("Select category").foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("categoryPickerButton")

                    // Clear button
                    if selectedCategory != nil {
                        Button(role: .destructive) {
                            selectedCategory = nil
                        } label: {
                            Label("Clear category", systemImage: "xmark.circle")
                                .font(.subheadline)
                        }
                        .accessibilityIdentifier("clearCategoryButton")
                    }
                }

                // ── Note ──────────────────────────────────────────────
                Section(header: Text("Description")) {
                    TextField("e.g. Netflix, Gym, Salary", text: $note)
                        .accessibilityIdentifier("noteField")
                }

                // ── Frequency ─────────────────────────────────────────
                Section(header: Text("Repeats")) {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .accessibilityIdentifier("frequencyPicker")
                }

                // ── Start date ────────────────────────────────────────
                Section(header: Text("Start Date")) {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("startDatePicker")
                }

                // ── End date (optional) ───────────────────────────────
                Section(header: Text("End Date")) {
                    Toggle("Set end date", isOn: $hasEndDate.animation())
                        .accessibilityIdentifier("endDateToggle")
                    if hasEndDate {
                        DatePicker(
                            "Ends",
                            selection: $endDate,
                            in: startDate...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .accessibilityIdentifier("endDatePicker")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Recurring" : "New Recurring Rule")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onDismiss)
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                        .accessibilityIdentifier("saveButton")
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                categorySheet
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    // MARK: - Category picker sheet

    private var categorySheet: some View {
        NavigationStack {
            List(filteredCategories) { cat in
                HStack {
                    Image(systemName: cat.icon)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: cat.colorHex))
                        .clipShape(Circle())
                    Text(cat.name)
                    Spacer()
                    if selectedCategory?.id == cat.id {
                        Image(systemName: "checkmark").foregroundStyle(.primary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCategory = cat
                    showCategoryPicker = false
                }
                .accessibilityIdentifier("catOption_\(cat.id)")
            }
            .navigationTitle("Select Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showCategoryPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Helpers

    private func loadInitialValues() {
        guard let r = rule else { return }
        type             = r.type
        amountText       = String(format: "%.2f", r.amount)
        note             = r.note
        frequency        = r.frequency
        startDate        = r.startDate
        selectedCategory = r.category
        if let end = r.endDate {
            hasEndDate = true
            endDate    = end
        }
    }

    private func save() {
        if var existing = rule {
            existing.type        = type
            existing.amount      = amountDouble
            existing.note        = note
            existing.frequency   = frequency
            existing.startDate   = startDate
            existing.endDate     = hasEndDate ? endDate : nil
            existing.category    = selectedCategory
        } else {
            let new = RecurringRule(
                amount:    amountDouble,
                type:      type,
                note:      note,
                frequency: frequency,
                startDate: startDate,
                endDate:   hasEndDate ? endDate : nil,
                ledger:    appState.selectedLedger,
                category:  selectedCategory
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        onDismiss()
    }
}

// MARK: - CategoryType convenience (reused from AddEditTransactionView)

private extension CategoryType {
    init(transactionType: TransactionType) {
        self = transactionType == .income ? .income : .expense
    }
}
