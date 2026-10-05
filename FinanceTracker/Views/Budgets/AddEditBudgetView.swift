import SwiftUI
import SwiftData

/// Form for creating or editing a `Budget`.
///
/// Fields:
///   - Category picker (expense categories only)
///   - Spending limit (amount)
///   - Period (Weekly / Monthly)
///   - Start date
struct AddEditBudgetView: View {

    // MARK: - Bindings & Environment
    @Binding var budget: Budget?
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \Category.sortOrder) private var allCategories: [Category]

    // MARK: - Form State
    @State private var amountText: String = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var startDate: Date = .now
    @State private var selectedCategory: Category? = nil
    @State private var showCategoryPicker = false

    // MARK: - Computed
    private var isEditing: Bool { budget != nil }

    private var amountDouble: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isFormValid: Bool {
        amountDouble > 0 && selectedCategory != nil
    }

    private var currency: String {
        appState.selectedLedger?.currency ?? "USD"
    }

    /// Only expense categories make sense for a spending budget.
    private var expenseCategories: [Category] {
        allCategories.filter { $0.type == .expense || $0.type == .both }
    }

    // MARK: - Init
    init(budget: Binding<Budget?>, onDismiss: @escaping () -> Void) {
        self._budget = budget
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {

                // ── Category ──────────────────────────────────────────
                Section(header: Text("Category")) {
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
                                Text(cat.name)
                                    .foregroundStyle(.primary)
                            } else {
                                Image(systemName: "tag")
                                    .foregroundStyle(.secondary)
                                Text("Select a category")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("categoryPickerButton")
                }

                // ── Spending limit ─────────────────────────────────────
                Section(header: Text("Spending Limit (\(currency))")) {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("amountField")
                }

                // ── Period ─────────────────────────────────────────────
                Section(header: Text("Resets Every")) {
                    Picker("Period", selection: $period) {
                        ForEach(BudgetPeriod.allCases) { p in
                            Text(p.displayName).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("periodPicker")
                }

                // ── Start date ─────────────────────────────────────────
                Section(header: Text("Start Date")) {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .accessibilityIdentifier("startDatePicker")
                }

                // ── Preview card ───────────────────────────────────────
                if amountDouble > 0, let cat = selectedCategory {
                    Section(header: Text("Preview")) {
                        HStack {
                            Image(systemName: cat.icon)
                                .foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color(hex: cat.colorHex))
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cat.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(period.displayName + " budget")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(amountDouble.currencyString(code: currency))
                                .font(.subheadline.weight(.bold))
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Budget" : "New Budget")
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
            List(expenseCategories) { cat in
                HStack {
                    Image(systemName: cat.icon)
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color(hex: cat.colorHex))
                        .clipShape(Circle())
                    Text(cat.name)
                    Spacer()
                    if selectedCategory?.id == cat.id {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.primary)
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
        guard let b = budget else { return }
        amountText       = String(format: "%.2f", b.amount)
        period           = b.period
        startDate        = b.startDate
        selectedCategory = b.category
    }

    private func save() {
        if var existing = budget {
            existing.amount    = amountDouble
            existing.period    = period
            existing.startDate = startDate
            existing.category  = selectedCategory
        } else {
            let new = Budget(
                amount:    amountDouble,
                period:    period,
                startDate: startDate,
                ledger:    appState.selectedLedger,
                category:  selectedCategory
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        onDismiss()
    }
}
