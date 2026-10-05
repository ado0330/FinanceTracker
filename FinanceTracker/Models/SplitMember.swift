import Foundation
import SwiftData

/// Represents a participant in group expenses.
@Model
final class SplitMember {

    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var isCurrentUser: Bool
    var createdAt: Date

    var ledger: Ledger?
    var group: SplitGroup?

    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "person.fill",
        colorHex: String = "#1C1C1E",
        isCurrentUser: Bool = false,
        createdAt: Date = .now,
        ledger: Ledger? = nil,
        group: SplitGroup? = nil
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.isCurrentUser = isCurrentUser
        self.createdAt = createdAt
        self.ledger = ledger
        self.group = group
    }

    /// Initials for fallback avatar badge
    var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: " ")
        if parts.count >= 2, let first = parts.first?.first, let second = parts.last?.first {
            return "\(first)\(second)".uppercased()
        } else if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "?"
    }
}
