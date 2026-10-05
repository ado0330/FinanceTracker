import SwiftUI
import SwiftData

/// Modal sheet for selecting, creating, and managing split groups (e.g. Trips, Roommates).
struct SplitGroupSwitcherView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitGroup.createdAt) private var allGroups: [SplitGroup]

    @State private var showNewGroupSheet = false
    @State private var groupToEdit: SplitGroup?
    @State private var groupToDelete: SplitGroup?

    private var groups: [SplitGroup] {
        guard let ledger = appState.selectedLedger else { return allGroups }
        return allGroups.filter { $0.ledger?.id == ledger.id || $0.ledger == nil }
    }

    private var currencyCode: String {
        appState.selectedLedger?.currency ?? "MYR"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(groups) { group in
                        let isSelected = appState.selectedSplitGroup?.id == group.id

                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: group.colorHex))
                                    .frame(width: 44, height: 44)
                                Image(systemName: group.icon)
                                    .font(.title3)
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(group.name)
                                        .font(.body.weight(.semibold))
                                    if group.isDefault {
                                        Text("Default")
                                            .font(.system(size: 10, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.primary.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                }

                                HStack(spacing: 6) {
                                    Label("\(group.members.count) members", systemImage: "person.2")
                                    Text("•")
                                    Text("Unsettled: \(group.unsettledTotal.currencyString(code: currencyCode))")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectedSplitGroup = group
                            dismiss()
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                groupToEdit = group
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Color(.systemGray))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if groups.count > 1 {
                                Button(role: .destructive) {
                                    groupToDelete = group
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                } header: {
                    Text("Your Split Groups (\(groups.count))")
                } footer: {
                    Text("Each group maintains its own isolated members, expenses, and debt settlement plans.")
                }

                Section {
                    Button {
                        showNewGroupSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.primary)
                            Text("Create New Group")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .navigationTitle("Switch Split Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showNewGroupSheet) {
                AddEditSplitGroupView(groupToEdit: nil)
            }
            .sheet(item: $groupToEdit) { grp in
                AddEditSplitGroupView(groupToEdit: grp)
            }
            .alert("Delete Group?", isPresented: Binding(
                get: { groupToDelete != nil },
                set: { if !$0 { groupToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    if let grp = groupToDelete {
                        deleteGroup(grp)
                    }
                }
            } message: {
                if let grp = groupToDelete {
                    Text("Are you sure you want to delete '\(grp.name)'? All associated expenses and member records for this group will be removed.")
                }
            }
        }
    }

    private func deleteGroup(_ group: SplitGroup) {
        if appState.selectedSplitGroup?.id == group.id {
            appState.selectedSplitGroup = groups.first(where: { $0.id != group.id })
        }
        modelContext.delete(group)
        try? modelContext.save()
        groupToDelete = nil
    }
}
