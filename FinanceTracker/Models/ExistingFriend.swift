import Foundation

/// Lightweight snapshot of a friend profile across groups (for quick reuse with preserved icon & color).
struct ExistingFriend: Identifiable, Hashable {
    var id: String { name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    let name: String
    let icon: String
    let colorHex: String
}

extension Collection where Element == SplitMember {
    /// Extracts unique friend profiles across groups, excluding current user / "You",
    /// preserving the most recently used icon and color.
    func uniqueFriendProfiles(excludingNames excluded: Set<String> = []) -> [ExistingFriend] {
        var seen = Set<String>()
        var profiles: [ExistingFriend] = []

        // Sort descending by createdAt so the most recent avatar configuration is used
        let sortedMembers = self.sorted { $0.createdAt > $1.createdAt }

        for member in sortedMembers {
            let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = trimmed.lowercased()
            if member.isCurrentUser || lower == "you" || trimmed.isEmpty { continue }
            if excluded.contains(lower) { continue }

            if !seen.contains(lower) {
                seen.insert(lower)
                profiles.append(
                    ExistingFriend(
                        name: trimmed,
                        icon: member.icon,
                        colorHex: member.colorHex
                    )
                )
            }
        }

        return profiles
    }
}
