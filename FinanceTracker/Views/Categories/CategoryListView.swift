import SwiftUI
import SwiftData

/// Displays and manages spending and income categories.
struct CategoryListView: View {

    // MARK: - Environment & Query
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.sortOrder) private var categories: [Category]

    // MARK: - UI State
    @State private var showingAddEdit = false
    @State private var editingCategory: Category? = nil
    @State private var selectedFilter: CategoryTypeFilter = .all
    @State private var searchText = ""

    var isEmbedded: Bool = false

    enum CategoryTypeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case expense = "Expense"
        case income = "Income"

        var id: String { rawValue }
    }

    // MARK: - Filtered Categories
    private var filteredCategories: [Category] {
        categories.filter { cat in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .expense:
                matchesFilter = cat.type == .expense || cat.type == .both
            case .income:
                matchesFilter = cat.type == .income || cat.type == .both
            }

            if searchText.isEmpty {
                return matchesFilter
            } else {
                return matchesFilter && cat.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // MARK: - Body
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
            if categories.isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
        .navigationTitle("Categories")
        .searchable(text: $searchText, prompt: "Search categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    editingCategory = nil
                    showingAddEdit = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addCategoryButton")
            }
        }
        .sheet(isPresented: $showingAddEdit) {
            AddEditCategoryView(category: $editingCategory) {
                showingAddEdit = false
            }
        }
    }

    // MARK: - Subviews

    private var categoryList: some View {
        List {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(CategoryTypeFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

            ForEach(filteredCategories) { cat in
                categoryRow(cat)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func categoryRow(_ cat: Category) -> some View {
        HStack(spacing: 12) {
            Image(systemName: cat.icon)
                .foregroundStyle(.white)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(Color(hex: cat.colorHex))
                .clipShape(Circle())
                .accessibilityIdentifier("categoryIcon_\(cat.id)")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(cat.name)
                        .font(.body.weight(.medium))
                    if cat.isSystem {
                        Text("Default")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12), in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                }

                Text(cat.type.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !cat.transactions.isEmpty {
                Text("\(cat.transactions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingCategory = cat
            showingAddEdit = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !cat.isSystem {
                Button(role: .destructive) {
                    withAnimation {
                        deleteCategory(cat)
                    }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .accessibilityIdentifier("deleteCategory_\(cat.id)")
            }

            Button {
                editingCategory = cat
                showingAddEdit = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.orange)
            .accessibilityIdentifier("editCategory_\(cat.id)")
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "tag.slash",
            title: "No categories found",
            message: "Create categories to organize your expenses and income.",
            buttonTitle: "Add Category"
        ) {
            editingCategory = nil
            showingAddEdit = true
        }
    }

    // MARK: - Actions

    private func deleteCategory(_ cat: Category) {
        modelContext.delete(cat)
        try? modelContext.save()
    }
}
