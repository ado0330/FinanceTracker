import SwiftUI
import SwiftData

/// The primary container view for the Expense Splitter module.
/// Supports switching between multiple groups (e.g. Trips, Roommates, Friends)
/// and features top segmented tabs: 'List' (expense history) and 'Settle' (settlement plan).
struct SplitterMainView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitGroup.createdAt) private var allGroups: [SplitGroup]
    @Query(sort: \SplitMember.createdAt) private var allMembers: [SplitMember]
    @Query private var allExpenses: [SplitExpense]
    @Query private var allSettlements: [SplitSettlement]

    @State private var activeTab: SplitterTab = .list
    @State private var showAddExpense = false
    @State private var showMemberManagement = false
    @State private var showGroupSwitcher = false

    enum SplitterTab: String, CaseIterable, Identifiable {
        case list = "List"
        case settle = "Settle"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .list:   return "list.bullet.rectangle"
            case .settle: return "arrow.left.arrow.right"
            }
        }
    }

    private var groups: [SplitGroup] {
        guard let ledger = appState.selectedLedger else { return allGroups }
        return allGroups.filter { $0.ledger?.id == ledger.id || $0.ledger == nil }
    }

    private var activeGroup: SplitGroup? {
        appState.selectedSplitGroup ?? groups.first(where: { $0.isDefault }) ?? groups.first
    }

    private var groupMembers: [SplitMember] {
        guard let group = activeGroup else { return [] }
        return allMembers.filter { $0.group?.id == group.id }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // ── Top Segmented Tabs: List & Settle ─────────────────────────
                Picker("Tab", selection: $activeTab) {
                    ForEach(SplitterTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(uiColor: .systemGroupedBackground))

                // ── Active Tab Content ────────────────────────────────────────
                TabView(selection: $activeTab) {
                    SplitExpenseListView()
                        .tag(SplitterTab.list)

                    SettlementView()
                        .tag(SplitterTab.settle)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // ── Center: Group Switcher Pill ───────────────────────────────
                ToolbarItem(placement: .principal) {
                    Button {
                        showGroupSwitcher = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: activeGroup?.icon ?? "person.3.fill")
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Text(activeGroup?.name ?? "Select Group")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .tint(.primary)
                    .accessibilityIdentifier("groupSwitcherButton")
                }

                // ── Leading: Members of this Group ────────────────────────────
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showMemberManagement = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                            Text("\(groupMembers.count)")
                                .font(.caption.bold())
                        }
                        .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("manageMembersButton")
                }

                // ── Trailing: Add Expense ─────────────────────────────────────
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                    .accessibilityIdentifier("addSplitExpenseButton")
                }
            }
            .sheet(isPresented: $showGroupSwitcher) {
                SplitGroupSwitcherView()
            }
            .sheet(isPresented: $showAddExpense) {
                AddEditSplitExpenseView(expenseToEdit: nil)
            }
            .sheet(isPresented: $showMemberManagement) {
                SplitMemberManagementView()
            }
            .task {
                bootstrapSplitGroupsAndMembers()
            }
            .onChange(of: groups) { _, _ in
                if appState.selectedSplitGroup == nil {
                    appState.selectedSplitGroup = groups.first(where: { $0.isDefault }) ?? groups.first
                }
            }
        }
    }

    // MARK: - Auto Seed & Migration

    private func bootstrapSplitGroupsAndMembers() {
        if groups.isEmpty {
            // Seed first default group
            let defaultGroup = SplitGroup(
                name: "Trip & Friends",
                icon: "airplane",
                colorHex: "#1C1C1E",
                isDefault: true,
                ledger: appState.selectedLedger
            )
            modelContext.insert(defaultGroup)

            // Associate any existing unassigned members / expenses / settlements
            for m in allMembers where m.group == nil {
                m.group = defaultGroup
            }
            for e in allExpenses where e.group == nil {
                e.group = defaultGroup
            }
            for s in allSettlements where s.group == nil {
                s.group = defaultGroup
            }

            // If still no members exist, seed initial participants
            if allMembers.isEmpty {
                let defaultMembers = [
                    SplitMember(name: "You", icon: "person.fill", colorHex: "#1C1C1E", isCurrentUser: true, ledger: appState.selectedLedger, group: defaultGroup),
                    SplitMember(name: "Alex", icon: "sparkles", colorHex: "#3A3A3C", isCurrentUser: false, ledger: appState.selectedLedger, group: defaultGroup),
                    SplitMember(name: "Sam", icon: "bolt.fill", colorHex: "#5856D6", isCurrentUser: false, ledger: appState.selectedLedger, group: defaultGroup)
                ]
                for m in defaultMembers {
                    modelContext.insert(m)
                }
            }

            try? modelContext.save()
            appState.selectedSplitGroup = defaultGroup
        } else {
            // Select default or first group if none active
            if appState.selectedSplitGroup == nil {
                appState.selectedSplitGroup = groups.first(where: { $0.isDefault }) ?? groups.first
            }

            // Ensure any unassigned items are linked to the active group
            if let active = appState.selectedSplitGroup {
                var needsSave = false
                for m in allMembers where m.group == nil {
                    m.group = active
                    needsSave = true
                }
                for e in allExpenses where e.group == nil {
                    e.group = active
                    needsSave = true
                }
                for s in allSettlements where s.group == nil {
                    s.group = active
                    needsSave = true
                }
                if needsSave {
                    try? modelContext.save()
                }
            }
        }
    }
}
