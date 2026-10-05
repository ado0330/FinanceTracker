import SwiftUI
import SwiftData

/// View for creating or editing an isolated group (e.g., Trip, Roommates, Friend circle).
struct AddEditSplitGroupView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    @Query(sort: \SplitMember.createdAt, order: .reverse) private var allMembers: [SplitMember]

    let groupToEdit: SplitGroup?

    @State private var name = ""
    @State private var selectedIcon = "airplane"
    @State private var selectedColor = "#1C1C1E"
    @State private var isDefault = false

    // Initial member drafts to create alongside a new group
    struct GroupMemberDraft: Identifiable, Hashable {
        let id = UUID()
        var name: String
        var icon: String
        var colorHex: String
        var isCurrentUser: Bool
    }

    @State private var newMemberNameInput = ""
    @State private var initialMembers: [GroupMemberDraft] = [
        GroupMemberDraft(name: "You", icon: "person.fill", colorHex: "#1C1C1E", isCurrentUser: true)
    ]

    private var availableExistingFriends: [ExistingFriend] {
        let currentNames = Set(initialMembers.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        return allMembers.uniqueFriendProfiles(excludingNames: currentNames)
    }

    private let presetIcons = [
        "airplane", "beach.umbrella.fill", "car.fill", "tram.fill",
        "house.fill", "person.3.fill", "fork.knife", "cup.and.saucer.fill",
        "gamecontroller.fill", "film.fill", "sparkles", "gift.fill"
    ]

    private let presetColors = [
        "#1C1C1E", "#2C2C2E", "#3A3A3C", "#5856D6",
        "#007AFF", "#34C759", "#FF9500", "#FF2D55",
        "#AF52DE", "#5AC8FA", "#FFCC00", "#A2845E"
    ]

    private let presetMemberIcons = [
        "person.fill", "sparkles", "bolt.fill", "star.fill",
        "heart.fill", "leaf.fill", "crown.fill", "figure.walk"
    ]

    private let presetMemberColors = [
        "#1C1C1E", "#3A3A3C", "#5856D6", "#007AFF",
        "#34C759", "#FF9500", "#FF2D55", "#AF52DE"
    ]

    var body: some View {
        NavigationStack {
            Form {
                // ── 1. Group Details ─────────────────────────────────────────
                Section(header: Text("Group Info")) {
                    TextField("Group Name (e.g. Penang Trip)", text: $name)

                    Toggle("Set as Default Group", isOn: $isDefault)
                }

                // ── 2. Icon & Color ──────────────────────────────────────────
                Section(header: Text("Group Icon")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(presetIcons, id: \.self) { icon in
                                ZStack {
                                    Circle()
                                        .fill(selectedIcon == icon ? Color.primary : Color.primary.opacity(0.06))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: icon)
                                        .font(.subheadline)
                                        .foregroundStyle(selectedIcon == icon ? Color(uiColor: .systemBackground) : .primary)
                                }
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Theme Color")) {
                    HStack(spacing: 10) {
                        ForEach(presetColors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: selectedColor == hex ? 2.5 : 0)
                                )
                                .onTapGesture {
                                    selectedColor = hex
                                }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── 3. Quick Add Existing Friends (New Group Only) ───────────
                if groupToEdit == nil && !availableExistingFriends.isEmpty {
                    Section(header: Text("Add from Existing Friends")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(availableExistingFriends) { friend in
                                    Button {
                                        addExistingFriend(friend)
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

                // ── 4. Initial Members (New Group Only) ───────────────────────
                if groupToEdit == nil {
                    Section(header: Text("Group Members (\(initialMembers.count))"), footer: Text("You can also add or edit members at any time later.")) {
                        ForEach(initialMembers) { member in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: member.colorHex))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: member.icon)
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                }

                                Text(member.name)
                                    .fontWeight(member.isCurrentUser ? .semibold : .regular)

                                Spacer()

                                if member.isCurrentUser {
                                    Text("You")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.primary.opacity(0.08))
                                        .clipShape(Capsule())
                                } else {
                                    Button {
                                        withAnimation {
                                            initialMembers.removeAll { $0.id == member.id }
                                        }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        HStack {
                            TextField("Add friend name...", text: $newMemberNameInput)
                                .onSubmit {
                                    addInitialMember()
                                }
                            Button("Add") {
                                addInitialMember()
                            }
                            .disabled(newMemberNameInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationTitle(groupToEdit == nil ? "New Split Group" : "Edit Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGroup()
                    }
                    .bold()
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let existing = groupToEdit {
                    name = existing.name
                    selectedIcon = existing.icon
                    selectedColor = existing.colorHex
                    isDefault = existing.isDefault
                }
            }
        }
    }

    private func addExistingFriend(_ friend: ExistingFriend) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            initialMembers.append(
                GroupMemberDraft(
                    name: friend.name,
                    icon: friend.icon,
                    colorHex: friend.colorHex,
                    isCurrentUser: false
                )
            )
        }
    }

    private func addInitialMember() {
        let trimmed = newMemberNameInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        guard !initialMembers.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }) else { return }

        // If an existing friend has this exact name, reuse their icon & colorHex
        if let match = allMembers.uniqueFriendProfiles().first(where: { $0.name.lowercased() == lower }) {
            initialMembers.append(
                GroupMemberDraft(
                    name: match.name,
                    icon: match.icon,
                    colorHex: match.colorHex,
                    isCurrentUser: false
                )
            )
        } else {
            let idx = initialMembers.count
            let icon = presetMemberIcons[idx % presetMemberIcons.count]
            let color = presetMemberColors[idx % presetMemberColors.count]
            initialMembers.append(
                GroupMemberDraft(
                    name: trimmed,
                    icon: icon,
                    colorHex: color,
                    isCurrentUser: false
                )
            )
        }
        newMemberNameInput = ""
    }

    private func saveGroup() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let existing = groupToEdit {
            existing.name = trimmedName
            existing.icon = selectedIcon
            existing.colorHex = selectedColor
            existing.isDefault = isDefault
            try? modelContext.save()
            appState.selectedSplitGroup = existing
        } else {
            let newGroup = SplitGroup(
                name: trimmedName,
                icon: selectedIcon,
                colorHex: selectedColor,
                isDefault: isDefault,
                ledger: appState.selectedLedger
            )
            modelContext.insert(newGroup)

            // Create initial members with preserved avatars
            for draft in initialMembers {
                let m = SplitMember(
                    name: draft.name,
                    icon: draft.icon,
                    colorHex: draft.colorHex,
                    isCurrentUser: draft.isCurrentUser,
                    ledger: appState.selectedLedger,
                    group: newGroup
                )
                modelContext.insert(m)
            }

            try? modelContext.save()
            appState.selectedSplitGroup = newGroup
        }

        dismiss()
    }
}
