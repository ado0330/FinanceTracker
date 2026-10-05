import SwiftUI
import SwiftData

/// View for creating or editing a shared group expense.
/// Supports inline math expression evaluation, multi-payer contributions,
/// and three split modes: Equal, Custom, and Itemized Receipt.
struct AddEditSplitExpenseView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    let expenseToEdit: SplitExpense?

    @Query(sort: \SplitMember.createdAt) private var allMembers: [SplitMember]

    private var members: [SplitMember] {
        guard let group = appState.selectedSplitGroup else { return allMembers }
        return allMembers.filter { $0.group?.id == group.id }
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    // MARK: - Form State
    @State private var title = ""
    @State private var amountInput = ""
    @State private var evaluatedAmount: Double? = nil
    @State private var date: Date = .now
    @State private var note = ""

    // Paid By
    @State private var isMultiPayer = false
    @State private var singlePayerID: UUID?
    @State private var payerAmounts: [UUID: String] = [:]

    // Split Mode
    @State private var selectedSplitMode: SplitMode = .equal
    @State private var equalSelectedMemberIDs: Set<UUID> = []

    // Custom Mode
    enum CustomSplitType: String, CaseIterable {
        case amount = "By Amount"
        case percentage = "By %"
    }
    @State private var customSplitType: CustomSplitType = .amount
    @State private var customMemberInputs: [UUID: String] = [:]

    // Receipt Mode
    @State private var receiptItems: [ReceiptLineItem] = []
    @State private var receiptTax: Double = 0.0
    @State private var receiptServiceFee: Double = 0.0
    @State private var receiptRounding: Double = 0.0
    @State private var receiptImageData: Data? = nil
    @State private var showReceiptItemAssignment = false

    // Validation Alert
    @State private var showValidationError = false
    @State private var validationErrorMessage = ""
    @State private var showDeleteConfirmation = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ── 1. Basic Info & Math Amount ─────────────────────────────────
                basicInfoSection

                // ── 2. Paid By ──────────────────────────────────────────────────
                paidBySection

                // ── 3. Split Mode Selector ──────────────────────────────────────
                splitModeSection

                // ── 4. Split Mode Details ───────────────────────────────────────
                splitDetailsSection

                // ── 5. Note ─────────────────────────────────────────────────────
                Section(header: Text("Note (optional)")) {
                    TextField("Add a note...", text: $note)
                }

                // ── 6. Delete Expense (Only when editing) ───────────────────────
                if expenseToEdit != nil {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Delete Expense")
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(expenseToEdit == nil ? "New Shared Expense" : "Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showReceiptItemAssignment) {
                ReceiptItemAssignmentView(
                    items: $receiptItems,
                    tax: $receiptTax,
                    serviceFee: $receiptServiceFee,
                    rounding: $receiptRounding,
                    receiptImageData: $receiptImageData,
                    members: members,
                    currencyCode: currencyCode
                ) { calculatedShares, calculatedTotal in
                    self.amountInput = String(format: "%.2f", calculatedTotal)
                    self.evaluatedAmount = calculatedTotal
                }
            }
            .alert("Incomplete Details", isPresented: $showValidationError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationErrorMessage)
            }
            .alert("Delete Expense?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let expense = expenseToEdit {
                        modelContext.delete(expense)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this shared expense? This action cannot be undone.")
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        Section(header: Text("Expense Details")) {
            TextField("What was this for? (e.g. Team Dinner)", text: $title)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Amount")
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("e.g. 50 + 12.50", text: $amountInput)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .font(.body.weight(.semibold))
                        .onChange(of: amountInput) { _, newVal in
                            evaluatedAmount = MathExpressionEvaluator.evaluate(newVal)
                        }
                }

                // Inline math expression evaluation display
                if let eval = evaluatedAmount, containsMathOperators(amountInput) {
                    HStack {
                        Spacer()
                        Label("= \(eval.currencyString(code: currencyCode))", systemImage: "function")
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }

            DatePicker("Date", selection: $date, displayedComponents: [.date])
        }
    }

    private var paidBySection: some View {
        Section(header: Text("Paid By")) {
            Picker("Payer Mode", selection: $isMultiPayer) {
                Text("Single Payer").tag(false)
                Text("Multiple Payers").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)

            if !isMultiPayer {
                Picker("Who Paid?", selection: $singlePayerID) {
                    ForEach(members) { member in
                        HStack {
                            Circle()
                                .fill(Color(hex: member.colorHex))
                                .frame(width: 14, height: 14)
                            Text(member.name + (member.isCurrentUser ? " (You)" : ""))
                        }
                        .tag(Optional(member.id))
                    }
                }
            } else {
                ForEach(members) { member in
                    HStack {
                        Circle()
                            .fill(Color(hex: member.colorHex))
                            .frame(width: 16, height: 16)
                        Text(member.name)

                        Spacer()

                        TextField("0.00", text: Binding(
                            get: { payerAmounts[member.id] ?? "" },
                            set: { payerAmounts[member.id] = $0 }
                        ))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                    }
                }

                let currentTotal = totalExpenseAmount
                let sumPaid = members.reduce(0.0) { $0 + (Double(payerAmounts[$1.id] ?? "") ?? 0.0) }
                let diff = currentTotal - sumPaid

                HStack {
                    Text("Total Paid: \(sumPaid.currencyString(code: currencyCode))")
                        .font(.caption)
                        .foregroundStyle(Swift.abs(diff) < 0.01 ? .green : .red)
                    Spacer()
                    if Swift.abs(diff) >= 0.01 && currentTotal > 0 {
                        Button("Split Paid Evenly") {
                            let perPayer = (currentTotal / Double(max(1, members.count)) * 100).rounded() / 100.0
                            for m in members {
                                payerAmounts[m.id] = String(format: "%.2f", perPayer)
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private var splitModeSection: some View {
        Section(header: Text("Split Mode")) {
            Picker("Split Mode", selection: $selectedSplitMode) {
                ForEach(SplitMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.icon)
                        .tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var splitDetailsSection: some View {
        switch selectedSplitMode {
        case .equal:
            equalSplitView
        case .custom:
            customSplitView
        case .receipt:
            receiptSplitView
        }
    }

    // ── Equal Split Mode View ────────────────────────────────────────────────
    private var equalSplitView: some View {
        Section(header: Text("Split Evenly Between")) {
            let activeCount = equalSelectedMemberIDs.count
            let total = totalExpenseAmount
            let perPerson = activeCount > 0 ? (total / Double(activeCount)) : 0.0

            ForEach(members) { member in
                let isSelected = equalSelectedMemberIDs.contains(member.id)
                Button {
                    if isSelected {
                        if equalSelectedMemberIDs.count > 1 {
                            equalSelectedMemberIDs.remove(member.id)
                        }
                    } else {
                        equalSelectedMemberIDs.insert(member.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isSelected ? .primary : .secondary)

                        Circle()
                            .fill(Color(hex: member.colorHex))
                            .frame(width: 14, height: 14)

                        Text(member.name + (member.isCurrentUser ? " (You)" : ""))
                            .foregroundStyle(.primary)

                        Spacer()

                        if isSelected && total > 0 {
                            Text(perPerson.currencyString(code: currencyCode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            if total > 0 && activeCount > 0 {
                HStack {
                    Text("Total: \(activeCount) people")
                    Spacer()
                    Text("\(perPerson.currencyString(code: currencyCode)) each")
                        .bold()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    // ── Custom Split Mode View ───────────────────────────────────────────────
    private var customSplitView: some View {
        Section(header: Text("Custom Split Shares")) {
            Picker("Custom By", selection: $customSplitType) {
                ForEach(CustomSplitType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            ForEach(members) { member in
                HStack {
                    Circle()
                        .fill(Color(hex: member.colorHex))
                        .frame(width: 14, height: 14)
                    Text(member.name)

                    Spacer()

                    TextField(customSplitType == .amount ? "0.00" : "0%", text: Binding(
                        get: { customMemberInputs[member.id] ?? "" },
                        set: { customMemberInputs[member.id] = $0 }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)

                    if customSplitType == .percentage {
                        let pct = Double(customMemberInputs[member.id] ?? "") ?? 0.0
                        let amt = totalExpenseAmount * (pct / 100.0)
                        Text("(\(amt.currencyString(code: currencyCode)))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 65, alignment: .trailing)
                    }
                }
            }
        }
    }

    // ── Receipt Mode View ────────────────────────────────────────────────────
    private var receiptSplitView: some View {
        Section(header: Text("Itemized Receipt Split")) {
            Button {
                showReceiptItemAssignment = true
            } label: {
                HStack(spacing: 12) {
                    if let data = receiptImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(receiptItems.isEmpty ? "Tap to Scan / Assign Items" : "\(receiptItems.count) Items Assigned")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(receiptItems.isEmpty ? "Use camera or photo OCR to split items" : "Tax: \(receiptTax.currencyString(code: currencyCode)) | Svc: \(receiptServiceFee.currencyString(code: currencyCode))\(receiptRounding != 0 ? " | Rounding: " + String(format: "%+.2f", receiptRounding) : "")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var totalExpenseAmount: Double {
        evaluatedAmount ?? Double(amountInput) ?? 0.0
    }

    private func containsMathOperators(_ str: String) -> Bool {
        str.contains("+") || str.contains("-") || str.contains("*") || str.contains("/")
            || str.contains("×") || str.contains("÷") || str.contains("−")
    }

    private func setupInitialValues() {
        // Default members selection
        equalSelectedMemberIDs = Set(members.map { $0.id })
        singlePayerID = members.first(where: { $0.isCurrentUser })?.id ?? members.first?.id

        if let existing = expenseToEdit {
            title = existing.title
            amountInput = String(format: "%.2f", existing.totalAmount)
            evaluatedAmount = existing.totalAmount
            date = existing.date
            note = existing.note
            selectedSplitMode = existing.splitMode
            receiptTax = existing.taxAmount
            receiptServiceFee = existing.serviceFeeAmount
            receiptRounding = existing.roundingAmount
            receiptImageData = existing.receiptImageData
            receiptItems = existing.receiptItems

            // Payers setup
            if existing.payers.count > 1 {
                isMultiPayer = true
                for p in existing.payers {
                    payerAmounts[p.memberID] = String(format: "%.2f", p.amount)
                }
            } else if let first = existing.payers.first {
                isMultiPayer = false
                singlePayerID = first.memberID
            }

            // Shares setup
            if existing.splitMode == .custom {
                for s in existing.shares {
                    customMemberInputs[s.memberID] = String(format: "%.2f", s.amount)
                }
            } else if existing.splitMode == .equal {
                equalSelectedMemberIDs = Set(existing.shares.map { $0.memberID })
            }
        }
    }

    // MARK: - Save Logic

    private func saveExpense() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            validationErrorMessage = "Please enter an expense title."
            showValidationError = true
            return
        }

        let total = totalExpenseAmount
        guard total > 0 else {
            validationErrorMessage = "Please enter a valid amount greater than 0."
            showValidationError = true
            return
        }

        // 1. Build Payers
        var payers: [SplitPayer] = []
        if isMultiPayer {
            var sumPaid = 0.0
            for member in members {
                let amt = Double(payerAmounts[member.id] ?? "") ?? 0.0
                if amt > 0 {
                    payers.append(SplitPayer(memberID: member.id, amount: amt))
                    sumPaid += amt
                }
            }
            if Swift.abs(sumPaid - total) > 0.05 {
                validationErrorMessage = "The sum of paid amounts (\(sumPaid.currencyString(code: currencyCode))) must equal the total expense amount (\(total.currencyString(code: currencyCode)))."
                showValidationError = true
                return
            }
        } else {
            guard let payerID = singlePayerID else {
                validationErrorMessage = "Please select who paid for this expense."
                showValidationError = true
                return
            }
            payers.append(SplitPayer(memberID: payerID, amount: total))
        }

        // 2. Build Shares
        var shares: [SplitShare] = []
        switch selectedSplitMode {
        case .equal:
            guard !equalSelectedMemberIDs.isEmpty else {
                validationErrorMessage = "Please select at least one member to share the expense."
                showValidationError = true
                return
            }
            let perPerson = (total / Double(equalSelectedMemberIDs.count) * 100).rounded() / 100.0
            for mID in equalSelectedMemberIDs {
                shares.append(SplitShare(memberID: mID, amount: perPerson, percentage: 100.0 / Double(equalSelectedMemberIDs.count)))
            }

        case .custom:
            var sumShare = 0.0
            for member in members {
                let rawVal = Double(customMemberInputs[member.id] ?? "") ?? 0.0
                if customSplitType == .amount {
                    if rawVal > 0 {
                        shares.append(SplitShare(memberID: member.id, amount: rawVal))
                        sumShare += rawVal
                    }
                } else {
                    if rawVal > 0 {
                        let computed = (total * (rawVal / 100.0) * 100).rounded() / 100.0
                        shares.append(SplitShare(memberID: member.id, amount: computed, percentage: rawVal))
                        sumShare += rawVal
                    }
                }
            }

            if customSplitType == .amount && Swift.abs(sumShare - total) > 0.05 {
                validationErrorMessage = "The sum of split shares (\(sumShare.currencyString(code: currencyCode))) must equal total amount (\(total.currencyString(code: currencyCode)))."
                showValidationError = true
                return
            } else if customSplitType == .percentage && Swift.abs(sumShare - 100.0) > 0.5 {
                validationErrorMessage = "The sum of percentages (\(sumShare)%) must equal 100%."
                showValidationError = true
                return
            }

        case .receipt:
            // Calculate from receipt items & tax & rounding
            var memberItemTotals: [UUID: Double] = [:]
            for m in members { memberItemTotals[m.id] = 0.0 }

            for item in receiptItems {
                let assigned = item.assignedMemberIDs.isEmpty ? members.map { $0.id } : item.assignedMemberIDs
                let split = item.totalPrice / Double(assigned.count)
                for id in assigned { memberItemTotals[id, default: 0.0] += split }
            }

            let itemSum = memberItemTotals.values.reduce(0.0, +)
            let extras = receiptTax + receiptServiceFee + receiptRounding
            for m in members {
                let itemSub = memberItemTotals[m.id] ?? 0.0
                let ratio = itemSum > 0 ? (itemSub / itemSum) : (1.0 / Double(max(1, members.count)))
                let shareAmt = ((itemSub + extras * ratio) * 100).rounded() / 100.0
                if shareAmt > 0 {
                    shares.append(SplitShare(memberID: m.id, amount: shareAmt, percentage: ratio * 100.0))
                }
            }

            // Cent-reconciliation: ensure sum of shares equals exact expense total
            let sharesSum = shares.reduce(0.0) { $0 + $1.amount }
            let centDiff = ((total - sharesSum) * 100).rounded() / 100.0
            if abs(centDiff) > 0.001 && !shares.isEmpty {
                if let maxIdx = shares.indices.max(by: { shares[$0].amount < shares[$1].amount }) {
                    shares[maxIdx].amount = ((shares[maxIdx].amount + centDiff) * 100).rounded() / 100.0
                }
            }
        }

        // 3. Persist to SwiftData
        if let existing = expenseToEdit {
            existing.title = trimmedTitle
            existing.totalAmount = total
            existing.date = date
            existing.note = note
            existing.splitMode = selectedSplitMode
            existing.taxAmount = receiptTax
            existing.serviceFeeAmount = receiptServiceFee
            existing.roundingAmount = receiptRounding
            existing.receiptImageData = receiptImageData
            existing.payers = payers
            existing.shares = shares
            existing.receiptItems = receiptItems
        } else {
            let newExpense = SplitExpense(
                title: trimmedTitle,
                totalAmount: total,
                date: date,
                note: note,
                splitMode: selectedSplitMode,
                taxAmount: receiptTax,
                serviceFeeAmount: receiptServiceFee,
                roundingAmount: receiptRounding,
                receiptImageData: receiptImageData,
                payers: payers,
                shares: shares,
                receiptItems: receiptItems,
                ledger: appState.selectedLedger,
                group: appState.selectedSplitGroup
            )
            modelContext.insert(newExpense)
        }

        try? modelContext.save()
        dismiss()
    }
}
