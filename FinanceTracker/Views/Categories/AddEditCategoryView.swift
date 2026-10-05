import SwiftUI
import SwiftData

/// UI for creating a new `Category` or editing an existing one.
///
/// - Parameters:
///   - category: A binding to an optional `Category`. `nil` means *add* mode;
///               a non‑nil value means *edit* mode.
///   - onDismiss: Called when the user taps *Cancel* or *Save* to close the sheet.
struct AddEditCategoryView: View {

    // MARK: - Bindings & Environment
    @Binding var category: Category?          // passed from the list view
    var onDismiss: () -> Void                // called to close the sheet

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local State (mirrors the model while editing)
    @State private var name: String = ""
    @State private var icon: String = "tag.fill"
    @State private var colorHex: String = "#A0A0A0"
    @State private var type: CategoryType = .expense

    // MARK: - Init
    init(category: Binding<Category?>, onDismiss: @escaping () -> Void) {
        self._category = category
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ---- Name ---------------------------------------------------
                Section(header: Text("Name")) {
                    TextField("Category name", text: $name)
                        .accessibilityIdentifier("categoryNameField")
                }

                // ---- Type ----------------------------------------------------
                Section(header: Text("Type")) {
                    Picker("Type", selection: $type) {
                        ForEach(CategoryType.allCases) { ct in
                            Text(ct.displayName).tag(ct)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("categoryTypePicker")
                }

                // ---- Icon ----------------------------------------------------
                Section(header: Text("Icon")) {
                    // A tiny grid of common SF Symbols – can be expanded later.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(["tag.fill", "cart.fill", "fork.knife", "car.fill", "house.fill", "gift.fill", "heart.fill", "music.note", "book.fill", "leaf.fill"], id: \.self) { symbol in
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

                // ---- Colour --------------------------------------------------
                Section(header: Text("Colour")) {
                    // Use the preset palette defined in Color+Hex.swift.
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Color.presetPalette, id: \.self) { colour in
                            Circle()
                                .fill(colour)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary.opacity(colorHex == colour.hexString ? 1 : 0), lineWidth: 2)
                                )
                                .onTapGesture { colorHex = colour.hexString }
                                .accessibilityIdentifier("color_\(colour.hexString)")
                        }
                    }
                }
            }
            .navigationTitle(category == nil ? "Add Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("saveButton")
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    // MARK: - Helpers

    private func loadInitialValues() {
        guard let cat = category else { return }
        name = cat.name
        icon = cat.icon
        colorHex = cat.colorHex
        type = cat.type
    }

    /// Persists a new or edited Category into the model context.
    private func saveCategory() {
        if var existing = category {
            // Edit mode – mutate the existing object.
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.icon = icon
            existing.colorHex = colorHex
            existing.type = type
            // `existing` is a reference‑type model, so changes are already tracked.
        } else {
            // Add mode – create a fresh model and insert it.
            let new = Category(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                colorHex: colorHex,
                type: type,
                isSystem: false,
                sortOrder: (try? modelContext.fetchCount(FetchDescriptor<Category>())) ?? 0
            )
            modelContext.insert(new)
        }
        // Persist immediately – this keeps the list view in sync.
        try? modelContext.save()
        onDismiss()
    }
}
