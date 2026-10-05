import SwiftUI
import SwiftData
import PhotosUI

/// Full-featured form for creating or editing a `Transaction`, supporting receipt photos.
///
/// - Parameters:
///   - transaction: Binding to an optional existing transaction (`nil` = add mode).
///   - onDismiss: Closure called after Cancel or Save to close the sheet.
struct AddEditTransactionView: View {

    // MARK: - Bindings & Environment
    @Binding var transaction: Transaction?
    var onDismiss: () -> Void


    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    // MARK: - SwiftData fetches (needed for pickers)
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \Tag.sortOrder)      private var allTags: [Tag]
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt) private var allAccounts: [Account]

    // MARK: - Form State
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var type: TransactionType = .expense
    @State private var selectedCategory: Category? = nil
    @State private var selectedAccount: Account? = nil
    @State private var selectedTags: Set<Tag> = []

    // MARK: - Photo / Receipt State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var receiptImageData: Data? = nil
    @State private var showFullScreenPhoto = false

    // MARK: - Sheet toggles
    @State private var showCategoryPicker = false
    @State private var showTagPicker = false

    // MARK: - Computed
    private var isEditing: Bool { transaction != nil }

    private var filteredCategories: [Category] {
        allCategories.filter {
            $0.type == .both || $0.type == CategoryType(transactionType: type)
        }
    }

    private var amountDouble: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && amountDouble > 0
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    // MARK: - Init
    init(transaction: Binding<Transaction?> = .constant(nil), onDismiss: @escaping () -> Void = {}) {
        self._transaction = transaction
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ── Type toggle ───────────────────────────────────────────
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(TransactionType.allCases) { t in
                            Label(t.displayName, systemImage: t.systemImage).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in
                        if let cat = selectedCategory,
                           cat.type != .both,
                           cat.type != CategoryType(transactionType: type) {
                            selectedCategory = nil
                        }
                    }
                }

                // ── Transaction Name (Required) ───────────────────────────
                Section(header: Text("Transaction Name *")) {
                    TextField("e.g. Curry Laksa, Starbucks, Uniqlo", text: $name)
                        .font(.body)
                        .accessibilityIdentifier("nameField")
                }

                // ── Amount ────────────────────────────────────────────────
                Section(header: Text("Amount (\(currencyCode)) *")) {
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

                // ── Date ──────────────────────────────────────────────────
                Section(header: Text("Date")) {
                    DatePicker(
                        "Date",
                        selection: $date,
                        displayedComponents: [.date]
                    )
                    .labelsHidden()
                    .accessibilityIdentifier("datePicker")
                }

                // ── Account ───────────────────────────────────────────────
                if !allAccounts.isEmpty {
                    Section(header: Text("Account")) {
                        Picker("Account", selection: $selectedAccount) {
                            Text("No Account").tag(Account?.none)
                            ForEach(allAccounts) { acc in
                                HStack {
                                    Image(systemName: acc.icon)
                                    Text(acc.fullDisplayName)
                                }
                                .tag(Account?.some(acc))
                            }
                        }
                    }
                }

                // ── Category ──────────────────────────────────────────────
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
                                Text("Select category")
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("categoryPickerButton")
                }

                // ── Tags ──────────────────────────────────────────────────
                Section(header: Text("Tags (optional)")) {
                    Button {
                        showTagPicker = true
                    } label: {
                        HStack {
                            if selectedTags.isEmpty {
                                Image(systemName: "number")
                                    .foregroundStyle(.secondary)
                                Text("Add tags")
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        ForEach(Array(selectedTags), id: \.id) { tag in
                                            tagChip(tag)
                                        }
                                    }
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("tagPickerButton")
                }

                // ── Receipt / Attachment ──────────────────────────────────
                Section(header: Text("Receipt / Photo")) {
                    if let data = receiptImageData, let uiImage = UIImage(data: data) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    showFullScreenPhoto = true
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )

                            HStack {
                                Button(role: .destructive) {
                                    withAnimation {
                                        receiptImageData = nil
                                        selectedPhotoItem = nil
                                    }
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                        .font(.caption)
                                }

                                Spacer()

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label("Change Photo", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 12) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.title2)
                                    .foregroundStyle(.primary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Add Receipt / Photo")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(.primary)

                                    Text("Attach a receipt, bill, or invoice image")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .accessibilityIdentifier("addReceiptButton")
                    }
                }

                // ── Note / Food Review ───────────────────────────────────
                Section(header: Text("Note / Review (optional)")) {
                    TextField("Write your food review, rating, or extra notes...", text: $note, axis: .vertical)
                        .lineLimit(3...5)
                        .accessibilityIdentifier("noteField")
                }
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "New Transaction")
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
            // Category picker sheet
            .sheet(isPresented: $showCategoryPicker) {
                categoryPickerSheet
            }
            // Tag picker sheet
            .sheet(isPresented: $showTagPicker) {
                tagPickerSheet
            }
            // Fullscreen photo sheet
            .sheet(isPresented: $showFullScreenPhoto) {
                if let data = receiptImageData, let uiImage = UIImage(data: data) {
                    NavigationStack {
                        ZStack {
                            Color.black.ignoresSafeArea()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                        .navigationTitle("Receipt")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") { showFullScreenPhoto = false }
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            self.receiptImageData = data
                        }
                    }
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    // MARK: - Category Picker Sheet

    private var categoryPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(filteredCategories) { cat in
                    HStack(spacing: 12) {
                        Image(systemName: cat.icon)
                            .foregroundStyle(.white)
                            .font(.system(size: 13, weight: .semibold))
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
            }
            .navigationTitle("Choose Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showCategoryPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tag Picker Sheet

    private var tagPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(allTags) { tag in
                    HStack {
                        Image(systemName: tag.icon)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(Color(hex: tag.colorHex))
                            .clipShape(Circle())
                        Text(tag.name)
                        Spacer()
                        Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTags.contains(tag) ? Color.primary : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                    .accessibilityIdentifier("tagOption_\(tag.id)")
                }
            }
            .navigationTitle("Choose Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { showTagPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Tag Chip

    private func tagChip(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.caption2)
            Text(tag.name)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(hex: tag.colorHex).opacity(0.2))
        .foregroundStyle(Color(hex: tag.colorHex))
        .clipShape(Capsule())
    }

    // MARK: - Data Helpers

    private func loadInitialValues() {
        if let txn = transaction {
            if let rawName = txn.name?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty {
                name = rawName
            } else {
                name = txn.note
            }
            amountText        = String(format: "%.2f", txn.amount)
            note              = txn.note
            date              = txn.date
            type              = txn.type
            selectedCategory  = txn.category
            selectedAccount   = txn.account
            selectedTags      = Set(txn.tags)
            receiptImageData  = txn.receiptImageData
        } else {
            if selectedAccount == nil {
                selectedAccount = allAccounts.first { $0.isDefault } ?? allAccounts.first
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if var existing = transaction {
            existing.name             = trimmedName
            existing.amount           = amountDouble
            existing.type             = type
            existing.date             = date
            existing.note             = trimmedNote
            existing.category         = selectedCategory
            existing.account          = selectedAccount
            existing.tags             = Array(selectedTags)
            existing.receiptImageData = receiptImageData
        } else {
            let new = Transaction(
                name:             trimmedName,
                amount:           amountDouble,
                type:             type,
                date:             date,
                note:             trimmedNote,
                ledger:           appState.selectedLedger,
                category:         selectedCategory,
                account:          selectedAccount,
                tags:             Array(selectedTags),
                receiptImageData: receiptImageData
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        onDismiss()
    }
}

// MARK: - CategoryType convenience init

private extension CategoryType {
    init(transactionType: TransactionType) {
        self = transactionType == .income ? .income : .expense
    }
}
