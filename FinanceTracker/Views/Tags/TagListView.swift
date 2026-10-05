import SwiftUI
import SwiftData

/// Displays a list of all user‑defined tags.
///
/// Can be used as a tag picker (binding to `selectedTags`) or as a standalone tag management screen.
struct TagListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.sortOrder) private var tags: [Tag]

    @Binding var selectedTags: Set<Tag>
    var isEmbedded: Bool = false
    var onAddEditCompleted: (() -> Void)? = nil

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingTag: Tag? = nil

    init(
        selectedTags: Binding<Set<Tag>> = .constant([]),
        isEmbedded: Bool = false,
        onAddEditCompleted: (() -> Void)? = nil
    ) {
        self._selectedTags = selectedTags
        self.isEmbedded = isEmbedded
        self.onAddEditCompleted = onAddEditCompleted
    }

    var body: some View {
        if isEmbedded {
            mainContent
        } else {
            NavigationStack {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        Group {
            if tags.isEmpty {
                emptyState
            } else {
                tagList
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingTag = nil
                    showingAddEdit = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addTagButton")
            }
        }
        .sheet(isPresented: $showingAddEdit) {
            AddEditTagView(tag: $editingTag) {
                showingAddEdit = false
                onAddEditCompleted?()
            }
        }
    }

    private var tagList: some View {
        List {
            ForEach(tags) { tag in
                tagRow(tag)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row
    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            Image(systemName: tag.icon)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: tag.colorHex))
                .clipShape(Circle())
                .accessibilityIdentifier("tagIcon_\(tag.id)")

            Text(tag.name)
                .font(.body)

            if tag.isSystem {
                Text("Default")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !selectedTags.isEmpty || onAddEditCompleted != nil {
                Image(systemName: selectedTags.contains(tag) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedTags.contains(tag) ? Color.primary : .secondary)
                    .accessibilityIdentifier("tagSelect_\(tag.id)")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !selectedTags.isEmpty || onAddEditCompleted != nil {
                if selectedTags.contains(tag) {
                    selectedTags.remove(tag)
                } else {
                    selectedTags.insert(tag)
                }
            } else {
                editingTag = tag
                showingAddEdit = true
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !tag.isSystem {
                Button(role: .destructive) {
                    withAnimation {
                        modelContext.delete(tag)
                        try? modelContext.save()
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteTag_\(tag.id)")
            }

            Button {
                editingTag = tag
                showingAddEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
            .accessibilityIdentifier("editTag_\(tag.id)")
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tag.slash",
            title: "No tags yet",
            message: "Add custom labels to organize and cross-reference your spending.",
            buttonTitle: "Add Tag"
        ) {
            editingTag = nil
            showingAddEdit = true
        }
    }
}
