import SwiftUI
import SwiftData
import PhotosUI

/// Quick-scan bookkeeping sheet triggered when user invokes iOS Back Tap.
///
/// Features:
/// - Instant automatic screenshot detection (from pasteboard or recent screenshots smart album)
/// - Gemini 3.5 Flash Lite multimodal extraction of merchant, amount, category, date, and line items
/// - Minimalist monochromatic black & white interface
/// - Tap-to-zoom receipt verification
/// - 1-tap save with haptic feedback
/// - Optional Splitter group forwarding
struct BackTapQuickScanView: View {

    // MARK: - Environment & State
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Ledger.createdAt) private var ledgers: [Ledger]
    @Query(sort: \Category.sortOrder) private var allCategories: [Category]
    @Query(sort: \SplitGroup.createdAt) private var splitGroups: [SplitGroup]
    @Query(filter: #Predicate<Account> { !$0.isArchived }, sort: \Account.createdAt) private var allAccounts: [Account]

    // MARK: - Scan Lifecycle State
    enum ScanState: Equatable {
        case searching
        case analyzing
        case review
        case saved
        case error(String)
    }

    @State private var scanState: ScanState = .searching
    @State private var scanBeamOffset: CGFloat = -120

    // MARK: - Receipt Image
    @State private var screenshotImage: UIImage? = nil
    @State private var showFullScreenReceipt = false
    @State private var selectedPhotoPickerItem: PhotosPickerItem? = nil

    // MARK: - Transaction Form Fields
    @State private var amountText: String = ""
    @State private var merchantText: String = ""
    @State private var selectedCategory: Category? = nil
    @State private var selectedLedger: Ledger? = nil
    @State private var selectedAccount: Account? = nil
    @State private var transactionDate: Date = .now
    @State private var noteText: String = ""

    // Line items & breakdown
    @State private var detectedItems: [ReceiptLineItem] = []
    @State private var detectedTax: Double = 0.0
    @State private var detectedServiceFee: Double = 0.0
    @State private var detectedRounding: Double = 0.0
    @State private var showItemBreakdown: Bool = false

    // MARK: - Computed Properties
    private var currencyCode: String {
        selectedLedger?.currency ?? appState.selectedLedger?.currency ?? "MYR"
    }

    private var parsedAmount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }

    private var expenseCategories: [Category] {
        allCategories.filter { $0.type != .income }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        switch scanState {
                        case .searching:
                            searchingCard
                        case .analyzing:
                            analyzingCard
                        case .review:
                            reviewContent
                        case .saved:
                            savedSuccessCard
                        case .error(let message):
                            errorCard(message: message)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Back Tap Quick Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if scanState == .review || scanState == .saved {
                        EmptyView()
                    } else {
                        Button("Cancel") {
                            dismiss()
                            appState.showBackTapScanner = false
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                        appState.showBackTapScanner = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
            }
            .task {
                await initiateScan()
            }
            .onChange(of: selectedPhotoPickerItem) { _, newItem in
                handlePhotoSelection(newItem)
            }
            .sheet(isPresented: $showFullScreenReceipt) {
                fullScreenReceiptView
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Subviews

    // ── Searching State ────────────────────────────────────────────────────────
    private var searchingCard: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.3)
                .padding(.top, 24)

            VStack(spacing: 6) {
                Text("Searching for Screenshot...")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Checking clipboard and recent screenshots")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // ── Analyzing State ────────────────────────────────────────────────────────
    private var analyzingCard: some View {
        VStack(spacing: 20) {
            if let image = screenshotImage {
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                        )

                    // Scanning light sweep beam
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color.primary.opacity(0.4), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 24)
                        .offset(y: scanBeamOffset)
                }
                .frame(height: 220)
                .clipped()
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                        scanBeamOffset = 100
                    }
                }
            }

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.bold())
                    Text("Gemini 3.5 Flash Lite")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08))
                .clipShape(Capsule())

                Text("Analyzing Receipt & Amounts...")
                    .font(.headline)

                Text("Extracting store name, items, tax, and Malaysian rounding adjustments.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 12)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── Review State ───────────────────────────────────────────────────────────
    private var reviewContent: some View {
        VStack(spacing: 16) {

            // 1. Receipt Thumbnail & Tap to Inspect
            if let image = screenshotImage {
                HStack(spacing: 14) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.primary)
                                .font(.caption.bold())
                            Text("Gemini Vision Analyzed")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            showFullScreenReceipt = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.caption2)
                                Text("View Full Receipt")
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }

                    Spacer()

                    PhotosPicker(selection: $selectedPhotoPickerItem, matching: .images) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(Circle())
                    }
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            // 2. Large Hero Amount Card
            VStack(spacing: 6) {
                Text("TOTAL AMOUNT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(currencyCode)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.secondary)

                    TextField("0.00", text: $amountText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if detectedRounding != 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "equal.circle")
                            .font(.caption2)
                        Text(String(format: "Includes Rounding: %@%.2f", detectedRounding > 0 ? "+" : "", detectedRounding))
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 3. Details Form Card
            VStack(spacing: 14) {
                // Store / Merchant
                HStack {
                    Label("Merchant", systemImage: "storefront")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    TextField("Store or payee name", text: $merchantText)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.trailing)
                }

                Divider()

                // Category
                HStack {
                    Label("Category", systemImage: "folder")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Spacer()

                    Menu {
                        ForEach(expenseCategories) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Label(cat.name, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let cat = selectedCategory {
                                Image(systemName: cat.icon)
                                    .font(.caption)
                                Text(cat.name)
                                    .font(.subheadline.weight(.semibold))
                            } else {
                                Text("Select Category")
                                    .font(.subheadline)
                            }
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Divider()

                // Ledger
                HStack {
                    Label("Ledger", systemImage: "book.closed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Spacer()

                    Menu {
                        ForEach(ledgers) { ledger in
                            Button {
                                selectedLedger = ledger
                            } label: {
                                Label(ledger.name, systemImage: ledger.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(selectedLedger?.name ?? "Select Ledger")
                                .font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                if !allAccounts.isEmpty {
                    Divider()

                    // Account
                    HStack {
                        Label("Account", systemImage: "building.columns")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)

                        Spacer()

                        Menu {
                            Button("No Account") {
                                selectedAccount = nil
                            }
                            ForEach(allAccounts) { acc in
                                Button {
                                    selectedAccount = acc
                                } label: {
                                    Label(acc.fullDisplayName, systemImage: acc.icon)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedAccount?.name ?? "Select Account")
                                    .font(.subheadline.weight(.semibold))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                }

                Divider()

                // Date
                HStack {
                    Label("Date", systemImage: "calendar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)

                    Spacer()

                    DatePicker("", selection: $transactionDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }

                Divider()

                // Note
                HStack(alignment: .top) {
                    Label("Note", systemImage: "pencil.line")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 100, alignment: .leading)
                        .padding(.top, 2)

                    TextField("Optional memo or items summary", text: $noteText, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(1...3)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // 4. Detected Items Collapsible Section
            if !detectedItems.isEmpty {
                DisclosureGroup(
                    isExpanded: $showItemBreakdown,
                    content: {
                        VStack(spacing: 8) {
                            ForEach(detectedItems) { item in
                                HStack {
                                    Text("\(item.quantity)× \(item.name)")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(item.totalPrice.currencyString(code: currencyCode))
                                        .font(.subheadline.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }

                            if detectedTax > 0 {
                                HStack {
                                    Text("Tax / SST")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("+\(detectedTax.currencyString(code: currencyCode))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if detectedServiceFee > 0 {
                                HStack {
                                    Text("Service Charge")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("+\(detectedServiceFee.currencyString(code: currencyCode))")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }

                            if detectedRounding != 0 {
                                HStack {
                                    Text("Malaysian Rounding")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(String(format: "%@%@", detectedRounding > 0 ? "+" : "", detectedRounding.currencyString(code: currencyCode)))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    },
                    label: {
                        HStack {
                            Image(systemName: "list.bullet.rectangle")
                                .foregroundStyle(.primary)
                            Text("Detected Items (\(detectedItems.count))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                )
                .padding(16)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            // 5. Action Buttons (Strictly Black & White Monochrome)
            VStack(spacing: 12) {
                Button {
                    saveTransaction()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.headline.bold())
                        Text("Save Transaction (\(parsedAmount.currencyString(code: currencyCode)))")
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(parsedAmount <= 0)
                .opacity(parsedAmount <= 0 ? 0.5 : 1.0)

                // Split Option
                if !splitGroups.isEmpty {
                    Button {
                        saveAndOpenSplitter()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "person.2.fill")
                                .font(.subheadline)
                            Text("Save & Open in Splitter")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.06))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // ── Saved Success State ───────────────────────────────────────────────────
    private var savedSuccessCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.top, 30)

            VStack(spacing: 6) {
                Text("Transaction Recorded!")
                    .font(.title2.weight(.bold))

                Text("\(parsedAmount.currencyString(code: currencyCode)) saved to \(selectedLedger?.name ?? "Ledger")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 30)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── Error State ───────────────────────────────────────────────────────────
    private func errorCard(message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .padding(.top, 20)

            VStack(spacing: 8) {
                Text("Could Not Scan Receipt")
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            VStack(spacing: 10) {
                // Paste from clipboard button
                Button {
                    if let clipImage = UIPasteboard.general.image {
                        self.screenshotImage = clipImage
                        Task { await analyzeImage(clipImage) }
                    } else {
                        scanState = .error("No image currently copied to clipboard. Please copy a receipt screenshot first.")
                    }
                } label: {
                    Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Choose from Photos
                PhotosPicker(selection: $selectedPhotoPickerItem, matching: .images) {
                    Label("Choose Photo from Library", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.primary.opacity(0.08))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Manual Entry Fallback
                Button {
                    switchToManualReview()
                } label: {
                    Text("Enter Manually")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // ── Full Screen Receipt Preview ───────────────────────────────────────────
    private var fullScreenReceiptView: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let img = screenshotImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .padding()
                }
            }
            .navigationTitle("Receipt Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFullScreenReceipt = false
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Logic & Actions

    private func initiateScan() async {
        // Pre-select active ledger
        if selectedLedger == nil {
            selectedLedger = appState.selectedLedger ?? ledgers.first(where: { $0.isDefault }) ?? ledgers.first
        }
        if selectedAccount == nil {
            selectedAccount = allAccounts.first { $0.isDefault } ?? allAccounts.first
        }

        // Check if an image was pre-injected
        if let initial = appState.backTapInitialImage {
            self.screenshotImage = initial
            appState.backTapInitialImage = nil
            await analyzeImage(initial)
            return
        }

        scanState = .searching
        if let screenshot = await BackTapScreenshotService.getLatestScreenshot() {
            self.screenshotImage = screenshot
            await analyzeImage(screenshot)
        } else {
            scanState = .error("No recent screenshot found. Please copy a screenshot to clipboard or pick one from Photos.")
        }
    }

    private func analyzeImage(_ image: UIImage) async {
        withAnimation {
            scanState = .analyzing
        }

        do {
            let result = try await GeminiReceiptScannerService.scanForAutoBookkeeping(image: image)

            self.amountText = String(format: "%.2f", result.totalAmount)
            self.merchantText = result.merchant
            self.transactionDate = result.date
            self.detectedItems = result.items
            self.detectedTax = result.tax
            self.detectedServiceFee = result.serviceFee
            self.detectedRounding = result.rounding

            // Set default note
            if !result.notes.isEmpty {
                self.noteText = result.notes
            } else if !result.merchant.isEmpty {
                self.noteText = result.merchant
            }

            // Auto-match category
            if let matchedCat = expenseCategories.first(where: {
                $0.name.localizedCaseInsensitiveContains(result.categoryName) ||
                result.categoryName.localizedCaseInsensitiveContains($0.name)
            }) {
                self.selectedCategory = matchedCat
            } else {
                self.selectedCategory = expenseCategories.first
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                scanState = .review
            }
        } catch {
            withAnimation {
                scanState = .error(error.localizedDescription)
            }
        }
    }

    private func saveTransaction() {
        guard parsedAmount > 0 else { return }

        let cleanMerchant = merchantText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)

        let finalNote: String
        if !cleanMerchant.isEmpty && !cleanNote.isEmpty && !cleanNote.contains(cleanMerchant) {
            finalNote = "\(cleanMerchant) · \(cleanNote)"
        } else if !cleanNote.isEmpty {
            finalNote = cleanNote
        } else {
            finalNote = cleanMerchant
        }

        let txnName = !cleanMerchant.isEmpty ? cleanMerchant : (selectedCategory?.name ?? "Scanned Receipt")
        let newTxn = Transaction(
            name: txnName,
            amount: parsedAmount,
            type: .expense,
            date: transactionDate,
            note: finalNote,
            ledger: selectedLedger ?? appState.selectedLedger,
            category: selectedCategory,
            account: selectedAccount,
            tags: [],
            receiptImageData: screenshotImage?.jpegData(compressionQuality: 0.8)
        )

        modelContext.insert(newTxn)
        try? modelContext.save()

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            scanState = .saved
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            dismiss()
            appState.showBackTapScanner = false
        }
    }

    private func saveAndOpenSplitter() {
        saveTransaction()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            appState.selectedTab = .splitter
        }
    }

    private func switchToManualReview() {
        if selectedCategory == nil {
            selectedCategory = expenseCategories.first
        }
        withAnimation {
            scanState = .review
        }
    }

    private func handlePhotoSelection(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                self.screenshotImage = image
                await analyzeImage(image)
            }
        }
    }
}
