import Foundation

/// The method used to divide an expense among group members.
enum SplitMode: String, Codable, CaseIterable, Identifiable {
    case equal = "equal"
    case custom = "custom"
    case receipt = "receipt"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .equal:   return "Equal"
        case .custom:  return "Custom"
        case .receipt: return "Receipt"
        }
    }

    var icon: String {
        switch self {
        case .equal:   return "equal.circle.fill"
        case .custom:  return "slider.horizontal.3"
        case .receipt: return "doc.text.viewfinder"
        }
    }
}

/// Represents a member who contributed to paying the expense.
struct SplitPayer: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var memberID: UUID
    var amount: Double
}

/// Represents an individual member's share/liability for an expense.
struct SplitShare: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var memberID: UUID
    var amount: Double
    var percentage: Double?
}

/// An itemized line from a receipt parsed by Vision OCR or entered manually.
struct ReceiptLineItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var unitPrice: Double
    var quantity: Int
    var assignedMemberIDs: [UUID]

    var totalPrice: Double {
        (unitPrice * Double(max(1, quantity)) * 100).rounded() / 100.0
    }
}
