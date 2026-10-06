import SwiftUI
import PhotosUI

/// Interactive view for itemized receipt splitting.
/// Allows OCR scanning via Vision, item-level member assignment, and proportional tax/fee distribution.
struct ReceiptItemAssignmentView: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var items: [ReceiptLineItem]
    @Binding var tax: Double
    @Binding var serviceFee: Double
    @Binding var rounding: Double
    @Binding var receiptImageData: Data?

    let members: [SplitMember]
    let currencyCode: String
    let onApply: (_ calculatedShares: [SplitShare], _ calculatedTotal: Double) -> Void

    // MARK: - State
    @AppStorage("geminiApiKey") private var userGeminiApiKey = ""
    @AppStorage("geminiModel") private var userGeminiModel = ""


    @State private var isScanning = false
    @State private var scanErrorMessage: String?
    @State private var showCameraPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var capturedImage: UIImage?

    // Manual item addition
    @State private var showAddItemSheet = false
    @State private var newItemName = ""
    @State private var newItemPrice = ""
    @State private var newItemQty = 1

    // Editing existing item
    @State private var showEditItemSheet = false
    @State private var editIndex: Int?
    @State private var editItemName = ""
    @State private var editItemPrice = ""
    @State private var editItemQty = 1

    // Fullscreen receipt image viewer
    @State private var showReceiptImageViewer = false

    // Editing Tax, Service Fee & Rounding text
    @State private var taxInput = ""
    @State private var serviceFeeInput = ""
    @State private var roundingInput = ""

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // ── 1. Receipt Capture / OCR Section ─────────────────────────────
                scanSection

                // ── 2. Line Items List ───────────────────────────────────────────
                lineItemsSection

                // ── 3. Additional Charges (Tax & Service Fee) ────────────────────
                additionalChargesSection

                // ── 4. Live Proportional Distribution Summary ───────────────────
                breakdownSummarySection
            }
            .navigationTitle("Itemized Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyCalculationsAndDismiss()
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                CameraPickerView(selectedImage: $capturedImage)
            }
            .sheet(isPresented: $showAddItemSheet) {
                addItemSheet
            }
            .sheet(isPresented: $showEditItemSheet) {
                editItemSheet
            }
            .sheet(isPresented: $showReceiptImageViewer) {
                if let data = receiptImageData, let uiImage = UIImage(data: data) {
                    ReceiptImageViewer(image: uiImage)
                }
            }
            .onChange(of: capturedImage) { _, newImage in
                if let image = newImage {
                    processImageWithOCR(image)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            processImageWithOCR(image)
                        }
                    }
                }
            }
            .onAppear {
                if tax > 0 { taxInput = String(format: "%.2f", tax) }
                if serviceFee > 0 { serviceFeeInput = String(format: "%.2f", serviceFee) }
                if abs(rounding) > 0.0001 { roundingInput = String(format: "%+.2f", rounding) }
            }
        }
    }

    // MARK: - Subviews

    private var scanSection: some View {
        Section {
            if isScanning {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Scanning receipt...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 12) {
                    Button {
                        showCameraPicker = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.subheadline.weight(.semibold))
                            Text("Camera")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.subheadline.weight(.semibold))
                            Text("Gallery")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                }
            }

            if let error = scanErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let data = receiptImageData, let uiImage = UIImage(data: data) {
                HStack(spacing: 12) {
                    Button {
                        showReceiptImageViewer = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                                )

                            Image(systemName: "plus.magnifyingglass")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                                .offset(x: -3, y: -3)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Receipt Scanned")
                            .font(.subheadline.weight(.semibold))
                        Button {
                            showReceiptImageViewer = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                                Text("Tap to view & zoom receipt")
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.primary)
                        }
                    }

                    Spacer()

                    Button("Clear") {
                        withAnimation {
                            receiptImageData = nil
                            items.removeAll()
                            tax = 0
                            serviceFee = 0
                            rounding = 0
                            taxInput = ""
                            serviceFeeInput = ""
                            roundingInput = ""
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Receipt Image & Scanning")
        } footer: {
            Text("Capture or upload a receipt to auto-extract items. Tap the photo to zoom and verify.")
        }
    }

    private var lineItemsSection: some View {
        Section {
            if items.isEmpty {
                VStack(spacing: 6) {
                    Text("No line items yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Scan a receipt above or tap '+ Add Item' below to enter items manually.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(items.indices, id: \.self) { idx in
                    let item = items[idx]
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            startEditingItem(at: idx)
                        } label: {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(item.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .multilineTextAlignment(.leading)
                                        Image(systemName: "pencil")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if item.quantity > 1 {
                                        Text("\(item.quantity) × \(item.unitPrice.currencyString(code: currencyCode))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(item.totalPrice.currencyString(code: currencyCode))
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Edit")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Member Selection & Select All Controls
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                let assignedCount = item.assignedMemberIDs.count
                                Text("Assign to (\(assignedCount)/\(members.count)):")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button {
                                    toggleSelectAll(itemIndex: idx)
                                } label: {
                                    let isAll = !members.isEmpty && item.assignedMemberIDs.count == members.count
                                    HStack(spacing: 4) {
                                        Image(systemName: isAll ? "checkmark.circle.fill" : "circle")
                                            .font(.caption2)
                                        Text(isAll ? "Deselect All" : "Select All")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(isAll ? Color.primary : Color.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("selectAllBtn_\(idx)")
                            }

                            // Adaptive Multi-Column Grid (all members visible at a glance, no scrolling)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                                ForEach(members) { member in
                                    let isAssigned = item.assignedMemberIDs.contains(member.id)
                                    let assignedCount = max(1, item.assignedMemberIDs.count)
                                    let perPerson = item.totalPrice / Double(assignedCount)

                                    Button {
                                        toggleMemberAssignment(itemIndex: idx, memberID: member.id)
                                    } label: {
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color(hex: member.colorHex))
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Image(systemName: isAssigned ? "checkmark" : member.icon)
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(member.name)
                                                    .font(.caption.weight(isAssigned ? .semibold : .regular))
                                                    .lineLimit(1)

                                                if isAssigned {
                                                    Text(perPerson.currencyString(code: currencyCode))
                                                        .font(.system(size: 9))
                                                        .foregroundStyle(.secondary)
                                                }
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isAssigned ? Color.primary.opacity(0.12) : Color.primary.opacity(0.04))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(isAssigned ? Color.primary : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("memberChip_\(idx)_\(member.id)")
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deleteItem)
            }

            Button {
                resetNewItemForm()
                showAddItemSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.body.weight(.bold))
                    Text("Add Line Item")
                        .font(.body.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)
        } header: {
            HStack {
                Text("Receipt Line Items (\(items.count))")
                Spacer()
                Text("Tap item to edit • Tap avatar to split")
                    .font(.caption2)
                    .textCase(nil)
            }
        }
    }

    private var additionalChargesSection: some View {
        Section {
            HStack {
                Text("Tax / SST / GST")
                Spacer()
                TextField("0.00", text: $taxInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: taxInput) { _, newVal in
                        tax = Double(newVal) ?? 0.0
                    }
            }

            HStack {
                Text("Service Fee / Tip")
                Spacer()
                TextField("0.00", text: $serviceFeeInput)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: serviceFeeInput) { _, newVal in
                        serviceFee = Double(newVal) ?? 0.0
                    }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rounding Adjustment")
                    Text("e.g. -0.02 or +0.01")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TextField("0.00", text: $roundingInput)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 100)
                    .onChange(of: roundingInput) { _, newVal in
                        let cleaned = newVal.replacingOccurrences(of: " ", with: "")
                        rounding = Double(cleaned) ?? 0.0
                    }
            }

            if currencyCode == "MYR" {
                Button {
                    let preRounding = items.reduce(0.0) { $0 + $1.totalPrice } + tax + serviceFee
                    let autoAdj = MalaysianRounding.adjustment(for: preRounding)
                    rounding = autoAdj
                    roundingInput = autoAdj == 0 ? "0.00" : String(format: "%+.2f", autoAdj)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Auto-Apply 5-Sen Rounding (MYR)")
                    }
                    .font(.caption.weight(.medium))
                }
            }
        } header: {
            Text("Additional Charges & Rounding")
        } footer: {
            Text("Tax, Service Charges, and Rounding adjustments are distributed proportionally among members according to their item subtotal.")
        }
    }

    private var breakdownSummarySection: some View {
        let calculations = computeShares()
        let itemsSubtotal = items.reduce(0.0) { $0 + $1.totalPrice }
        let grandTotal = ((itemsSubtotal + tax + serviceFee + rounding) * 100).rounded() / 100.0

        return Section {
            HStack {
                Text("Items Subtotal")
                Spacer()
                Text(itemsSubtotal.currencyString(code: currencyCode))
                    .foregroundStyle(.secondary)
            }

            if tax > 0 {
                HStack {
                    Text("Tax / SST")
                    Spacer()
                    Text("+\(tax.currencyString(code: currencyCode))")
                        .foregroundStyle(.secondary)
                }
            }

            if serviceFee > 0 {
                HStack {
                    Text("Service Fee")
                    Spacer()
                    Text("+\(serviceFee.currencyString(code: currencyCode))")
                        .foregroundStyle(.secondary)
                }
            }

            if abs(rounding) > 0.0001 {
                HStack {
                    Text("Rounding (5-sen)")
                    Spacer()
                    Text(String(format: "%@%@%.2f", rounding < 0 ? "-" : "+", currencyCode == "MYR" ? "RM " : "", abs(rounding)))
                        .foregroundStyle(rounding < 0 ? Color(.systemGreen) : .secondary)
                }
            }

            HStack {
                Text("Grand Total")
                    .font(.headline)
                Spacer()
                Text(grandTotal.currencyString(code: currencyCode))
                    .font(.headline.weight(.bold))
            }

            ForEach(calculations) { share in
                if let member = members.first(where: { $0.id == share.memberID }) {
                    HStack {
                        Circle()
                            .fill(Color(hex: member.colorHex))
                            .frame(width: 12, height: 12)
                        Text(member.name)
                            .font(.subheadline)
                        Spacer()
                        Text(share.amount.currencyString(code: currencyCode))
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        } header: {
            Text("Proportional Split Summary")
        }
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                TextField("Item Name (e.g. Coffee)", text: $newItemName)
                TextField("Total Price", text: $newItemPrice)
                    .keyboardType(.decimalPad)
                Stepper("Quantity: \(newItemQty)", value: $newItemQty, in: 1...99)
            }
            .navigationTitle("Add Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddItemSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let price = Double(newItemPrice), !newItemName.trimmingCharacters(in: .whitespaces).isEmpty {
                            let unitPrice = (price / Double(newItemQty) * 100).rounded() / 100.0
                            // Default: unassigned
                            items.append(ReceiptLineItem(
                                name: newItemName.trimmingCharacters(in: .whitespaces),
                                unitPrice: unitPrice,
                                quantity: newItemQty,
                                assignedMemberIDs: []
                            ))
                            showAddItemSheet = false
                        }
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty || Double(newItemPrice) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var editItemSheet: some View {
        NavigationStack {
            Form {
                Section(header: Text("Item Information")) {
                    TextField("Item Name (e.g. Chicken Chop)", text: $editItemName)
                    TextField("Total Price", text: $editItemPrice)
                        .keyboardType(.decimalPad)
                    Stepper("Quantity: \(editItemQty)", value: $editItemQty, in: 1...99)
                }
            }
            .navigationTitle("Edit Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditItemSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let idx = editIndex, items.indices.contains(idx),
                           let price = Double(editItemPrice), !editItemName.trimmingCharacters(in: .whitespaces).isEmpty {
                            let unitPrice = (price / Double(editItemQty) * 100).rounded() / 100.0
                            items[idx].name = editItemName.trimmingCharacters(in: .whitespaces)
                            items[idx].unitPrice = unitPrice
                            items[idx].quantity = editItemQty
                            showEditItemSheet = false
                        }
                    }
                    .bold()
                    .disabled(editItemName.trimmingCharacters(in: .whitespaces).isEmpty || Double(editItemPrice) == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func startEditingItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        let item = items[index]
        editIndex = index
        editItemName = item.name
        editItemPrice = String(format: "%.2f", item.totalPrice)
        editItemQty = item.quantity
        showEditItemSheet = true
    }

    // MARK: - Logic

    private func processImageWithOCR(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        receiptImageData = data
        isScanning = true
        scanErrorMessage = nil

        Task {
            let key = GeminiReceiptScannerService.effectiveApiKey(userKey: userGeminiApiKey)
            let model = GeminiReceiptScannerService.effectiveModel(userModel: userGeminiModel)
            if !key.isEmpty {
                do {
                    let result = try await GeminiReceiptScannerService.scanWithGemini(
                        image: image,
                        apiKey: key,
                        model: model
                    )
                    await MainActor.run {
                        applyScannedResult(result)
                        self.isScanning = false
                    }
                    return
                } catch {
                    await MainActor.run {
                        self.scanErrorMessage = "Gemini AI: \(error.localizedDescription). Falling back to Apple Vision..."
                    }
                }
            }

            // Fallback to offline Apple Vision OCR
            do {
                let result = try await ReceiptScannerService.scanReceipt(image: image)
                await MainActor.run {
                    applyScannedResult(result)
                    self.isScanning = false
                }
            } catch {
                await MainActor.run {
                    self.scanErrorMessage = "Scanning failed: \(error.localizedDescription)"
                    self.isScanning = false
                }
            }
        }
    }

    private func applyScannedResult(_ result: ParsedReceiptResult) {
        var recognizedItems = result.items
        for i in 0..<recognizedItems.count {
            // Default to unselected per user preference
            recognizedItems[i].assignedMemberIDs = []
        }

        self.items = recognizedItems
        if result.tax > 0 {
            self.tax = result.tax
            self.taxInput = String(format: "%.2f", result.tax)
        }
        if result.serviceFee > 0 {
            self.serviceFee = result.serviceFee
            self.serviceFeeInput = String(format: "%.2f", result.serviceFee)
        }
        self.rounding = result.rounding
        if abs(result.rounding) > 0.0001 {
            self.roundingInput = String(format: "%+.2f", result.rounding)
        } else {
            self.roundingInput = "0.00"
        }
    }

    private func toggleMemberAssignment(itemIndex: Int, memberID: UUID) {
        guard items.indices.contains(itemIndex) else { return }
        var assigned = items[itemIndex].assignedMemberIDs
        if let idx = assigned.firstIndex(of: memberID) {
            assigned.remove(at: idx)
        } else {
            assigned.append(memberID)
        }
        items[itemIndex].assignedMemberIDs = assigned
    }

    private func toggleSelectAll(itemIndex: Int) {
        guard items.indices.contains(itemIndex) else { return }
        if items[itemIndex].assignedMemberIDs.count == members.count {
            items[itemIndex].assignedMemberIDs = []
        } else {
            items[itemIndex].assignedMemberIDs = members.map { $0.id }
        }
    }

    private func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func resetNewItemForm() {
        newItemName = ""
        newItemPrice = ""
        newItemQty = 1
    }

    /// Computes individual member shares including proportional tax, service fee, and rounding distribution.
    private func computeShares() -> [SplitShare] {
        var memberItemTotals: [UUID: Double] = [:]
        for member in members {
            memberItemTotals[member.id] = 0.0
        }

        for item in items {
            let assigned = item.assignedMemberIDs
            guard !assigned.isEmpty else { continue }
            let splitPerPerson = item.totalPrice / Double(assigned.count)
            for mID in assigned {
                memberItemTotals[mID, default: 0.0] += splitPerPerson
            }
        }

        let totalItemSum = memberItemTotals.values.reduce(0.0, +)
        let totalExtraCharges = tax + serviceFee + rounding
        let grandTotal = ((totalItemSum + totalExtraCharges) * 100).rounded() / 100.0

        var result: [SplitShare] = []
        for member in members {
            let itemSub = memberItemTotals[member.id] ?? 0.0
            let ratio = totalItemSum > 0 ? (itemSub / totalItemSum) : (1.0 / Double(max(1, members.count)))
            let extra = totalExtraCharges * ratio
            let finalMemberShare = ((itemSub + extra) * 100).rounded() / 100.0

            result.append(SplitShare(
                memberID: member.id,
                amount: finalMemberShare,
                percentage: (ratio * 100).rounded() / 100.0
            ))
        }

        // Penny-reconciliation: ensure sum of shares equals exact grandTotal down to the cent
        let sharesSum = result.reduce(0.0) { $0 + $1.amount }
        let centDiff = ((grandTotal - sharesSum) * 100).rounded() / 100.0
        if abs(centDiff) > 0.001 && !result.isEmpty {
            if let maxIdx = result.indices.max(by: { result[$0].amount < result[$1].amount }) {
                result[maxIdx].amount = ((result[maxIdx].amount + centDiff) * 100).rounded() / 100.0
            }
        }

        return result
    }

    private func applyCalculationsAndDismiss() {
        let shares = computeShares()
        let itemsSubtotal = items.reduce(0.0) { $0 + $1.totalPrice }
        let calculatedTotal = ((itemsSubtotal + tax + serviceFee + rounding) * 100).rounded() / 100.0
        onApply(shares, calculatedTotal)
        dismiss()
    }
}
