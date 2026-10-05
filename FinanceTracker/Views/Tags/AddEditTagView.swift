import SwiftUI
import SwiftData

/// UI for creating a new `Tag` or editing an existing one.
///
/// - Parameters:
///   - tag: A binding to an optional `Tag`. `nil` => add mode; non‑nil => edit mode.
///   - onDismiss: Called when the user finishes (Cancel or Save).
struct AddEditTagView: View {

    // MARK: - Bindings & Environment
    @Binding var tag: Tag?
    var onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - Local State (mirrors the model while editing)
    @State private var name: String = ""
    @State private var icon: String = "tag.fill"
    @State private var colorHex: String = "#A0A0A0"

    // MARK: - Init
    init(tag: Binding<Tag?>, onDismiss: @escaping () -> Void) {
        self._tag = tag
        self.onDismiss = onDismiss
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // ---- Name ---------------------------------------------------
                Section(header: Text("Name")) {
                    TextField("Tag name", text: $name)
                        .accessibilityIdentifier("tagNameField")
                }

                // ---- Icon ----------------------------------------------------
                Section(header: Text("Icon")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(["tag.fill", "star.fill", "heart.fill", "bookmark.fill", "flame.fill", "leaf.fill", "bolt.fill", "gift.fill", "music.note", "paperplane.fill"], id: \.self) { symbol in
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
            .navigationTitle(tag == nil ? "Add Tag" : "Edit Tag")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onDismiss() }
                        .accessibilityIdentifier("cancelButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveTag() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("saveButton")
                }
            }
            .onAppear(perform: loadInitialValues)
        }
    }

    // MARK: - Helpers
    private func loadInitialValues() {
        guard let t = tag else { return }
        name = t.name
        icon = t.icon
        colorHex = t.colorHex
    }

    private func saveTag() {
        if var existing = tag {
            // Edit mode – mutate directly.
            existing.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            existing.icon = icon
            existing.colorHex = colorHex
        } else {
            // Add mode – create new Tag.
            let new = Tag(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                icon: icon,
                colorHex: colorHex,
                isSystem: false,
                sortOrder: (try? modelContext.fetchCount(FetchDescriptor<Tag>())) ?? 0
            )
            modelContext.insert(new)
        }
        // Persist immediately.
        try? modelContext.save()
        onDismiss()
    }
}
