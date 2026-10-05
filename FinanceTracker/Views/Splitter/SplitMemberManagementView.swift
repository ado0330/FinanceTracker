import SwiftUI
import SwiftData

/// View for managing participants/members in group splitting.
struct SplitMemberManagementView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitMember.createdAt, order: .reverse) private var allMembers: [SplitMember]

    @State private var showAddMemberSheet = false
    @State private var memberToEdit: SplitMember?
    @State private var nameInput = ""
    @State private var selectedColor = "#1C1C1E"
    @State private var selectedIcon = "person.fill"
    @State private var isCurrentUser = false

    private var members: [SplitMember] {
        guard let group = appState.selectedSplitGroup else { return allMembers }
        return allMembers.filter { $0.group?.id == group.id }
    }

    private var availableFriendsToAdd: [ExistingFriend] {
        let currentMemberNames = Set(members.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return allMembers.uniqueFriendProfiles(excludingNames: currentMemberNames)
    }

    private let presetColors = [
        "#1C1C1E", "#3A3A3C", "#5856D6", "#007AFF",
        "#34C759", "#FF9500", "#FF2D55", "#AF52DE"
    ]

    private let presetIcons = [
        "person.fill", "person.crop.circle.fill", "star.fill", "heart.fill",
        "bolt.fill", "leaf.fill", "crown.fill", "figure.walk"
    ]

    var body: some View {
        NavigationStack {
            List {
                // ── 1. Quick Add Friends from Other Groups ───────────────────
                if !availableFriendsToAdd.isEmpty {
                    Section(header: Text("Add from Other Groups"), footer: Text("Tap a friend to add them to '\(appState.selectedSplitGroup?.name ?? "this group")' with their saved avatar.")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableFriendsToAdd) { friend in
                                    Button {
                                        quickAddMember(friend)
                                    } label: {
                                        HStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: friend.colorHex))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: friend.icon)
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                            }
                                            Text(friend.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            Image(systemName: "plus.circle.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // ── 2. Current Group Members ─────────────────────────────────
                Section(header: Text("\(appState.selectedSplitGroup?.name ?? "Group") Members (\(members.count))"), footer: Text("Members are specific to this group and shared across its expenses.")) {
                    if members.isEmpty {
                        Text("No members yet. Add your group members to get started.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(members) { member in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: member.colorHex))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: member.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(member.name)
                                            .font(.body.weight(.medium))
                                        if member.isCurrentUser {
                                            Text("You")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.primary.opacity(0.08))
                                                .clipShape(Capsule())
                                        }
                                    }
                                }

                                Spacer()

                                Button {
                                    editMember(member)
                                } label: {
                                    Image(systemName: "pencil")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteMembers)
                    }
                }
            }
            .navigationTitle("Manage Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        resetForm()
                        showAddMemberSheet = true
                    } label: {
                        Label("Add Member", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddMemberSheet) {
                memberFormSheet
            }
        }
    }

    private var memberFormSheet: some View {
        NavigationStack {
            Form {
                // ── Pick from Existing Friends ───────────────────────────────
                if memberToEdit == nil && !availableFriendsToAdd.isEmpty {
                    Section(header: Text("Pick from Existing Friends")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableFriendsToAdd) { friend in
                                    let isSelected = nameInput.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == friend.name.lowercased()
                                    Button {
                                        selectFriendInForm(friend)
                                    } label: {
                                        HStack(spacing: 8) {
                                            ZStack {
                                                Circle()
                                                    .fill(Color(hex: friend.colorHex))
                                                    .frame(width: 28, height: 28)
                                                Image(systemName: friend.icon)
                                                    .font(.caption2.bold())
                                                    .foregroundStyle(.white)
                                            }
                                            Text(friend.name)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(.primary)
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(isSelected ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(header: Text("Member Details")) {
                    TextField("Name (e.g. Alex)", text: $nameInput)

                    Toggle("Mark as Myself (You)", isOn: $isCurrentUser)
                }

                Section(header: Text("Avatar Color")) {
                    HStack(spacing: 10) {
                        ForEach(presetColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Icon")) {
                    HStack(spacing: 14) {
                        ForEach(presetIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(width: 34, height: 34)
                                .background(selectedIcon == icon ? Color.primary.opacity(0.12) : Color.clear)
                                .clipShape(Circle())
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(memberToEdit == nil ? "New Member" : "Edit Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAddMemberSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMember()
                        showAddMemberSheet = false
                    }
                    .disabled(nameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func quickAddMember(_ friend: ExistingFriend) {
        let newMember = SplitMember(
            name: friend.name,
            icon: friend.icon,
            colorHex: friend.colorHex,
            isCurrentUser: false,
            ledger: appState.selectedLedger,
            group: appState.selectedSplitGroup
        )
        modelContext.insert(newMember)
        try? modelContext.save()
    }

    private func selectFriendInForm(_ friend: ExistingFriend) {
        nameInput = friend.name
        selectedIcon = friend.icon
        selectedColor = friend.colorHex
        isCurrentUser = false
    }

    private func resetForm() {
        memberToEdit = nil
        nameInput = ""
        selectedColor = presetColors.randomElement() ?? "#1C1C1E"
        selectedIcon = "person.fill"
        isCurrentUser = members.isEmpty // First member defaults to "You"
    }

    private func editMember(_ member: SplitMember) {
        memberToEdit = member
        nameInput = member.name
        selectedColor = member.colorHex
        selectedIcon = member.icon
        isCurrentUser = member.isCurrentUser
        showAddMemberSheet = true
    }

    private func saveMember() {
        let trimmedName = nameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        // If marking this as current user, unset others
        if isCurrentUser {
            for m in members {
                m.isCurrentUser = false
            }
        }

        if let existing = memberToEdit {
            existing.name = trimmedName
            existing.colorHex = selectedColor
            existing.icon = selectedIcon
            existing.isCurrentUser = isCurrentUser
        } else {
            let newMember = SplitMember(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor,
                isCurrentUser: isCurrentUser,
                ledger: appState.selectedLedger,
                group: appState.selectedSplitGroup
            )
            modelContext.insert(newMember)
        }
        try? modelContext.save()
    }

    private func deleteMembers(at offsets: IndexSet) {
        for index in offsets {
            let member = members[index]
            modelContext.delete(member)
        }
        try? modelContext.save()
    }
}
