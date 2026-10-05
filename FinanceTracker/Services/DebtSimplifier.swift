import Foundation

/// Data structure representing an optimized debt transfer between two members.
struct DebtTransfer: Identifiable, Equatable {
    let id: UUID
    let fromMemberID: UUID
    let fromMemberName: String
    let toMemberID: UUID
    let toMemberName: String
    let amount: Double

    init(
        id: UUID = UUID(),
        fromMemberID: UUID,
        fromMemberName: String,
        toMemberID: UUID,
        toMemberName: String,
        amount: Double
    ) {
        self.id = id
        self.fromMemberID = fromMemberID
        self.fromMemberName = fromMemberName
        self.toMemberID = toMemberID
        self.toMemberName = toMemberName
        self.amount = (amount * 100).rounded() / 100.0
    }
}

/// Overview statistics for an individual member in the group.
struct MemberBalanceSummary: Identifiable, Equatable {
    let id: UUID // memberID
    let name: String
    let icon: String
    let colorHex: String
    var totalPaid: Double
    var totalOwed: Double

    var netBalance: Double {
        let diff = totalPaid - totalOwed
        return (diff * 100).rounded() / 100.0
    }
}

/// Algorithm engine that aggregates split expenses and simplifies group debt into minimum transfers.
enum DebtSimplifier {

    /// Computes individual member balances (Paid vs Owed) from a list of expenses and paid settlements.
    static func calculateMemberSummaries(
        members: [SplitMember],
        expenses: [SplitExpense],
        settlements: [SplitSettlement]
    ) -> [MemberBalanceSummary] {
        var summaryMap: [UUID: MemberBalanceSummary] = [:]

        for member in members {
            summaryMap[member.id] = MemberBalanceSummary(
                id: member.id,
                name: member.name,
                icon: member.icon,
                colorHex: member.colorHex,
                totalPaid: 0.0,
                totalOwed: 0.0
            )
        }

        // Aggregate from unsettled expenses
        for expense in expenses where !expense.isSettled {
            // Add what each payer paid
            for payer in expense.payers {
                if summaryMap[payer.memberID] != nil {
                    summaryMap[payer.memberID]?.totalPaid += payer.amount
                }
            }

            // Add what each member owes (their split share)
            for share in expense.shares {
                if summaryMap[share.memberID] != nil {
                    summaryMap[share.memberID]?.totalOwed += share.amount
                }
            }
        }

        // Account for any individual settlements that were marked paid
        for settlement in settlements where settlement.isPaid {
            // fromMember paid money to toMember
            if summaryMap[settlement.fromMemberID] != nil {
                summaryMap[settlement.fromMemberID]?.totalPaid += settlement.amount
            }
            if summaryMap[settlement.toMemberID] != nil {
                summaryMap[settlement.toMemberID]?.totalOwed += settlement.amount
            }
        }

        return members.compactMap { summaryMap[$0.id] }
    }

    /// Solves the optimal minimum transactions using a greedy bipartite matching strategy.
    static func simplifyDebts(summaries: [MemberBalanceSummary]) -> [DebtTransfer] {
        var debtors: [(id: UUID, name: String, net: Double)] = []
        var creditors: [(id: UUID, name: String, net: Double)] = []

        for item in summaries {
            let net = item.netBalance
            if net < -0.009 {
                debtors.append((id: item.id, name: item.name, net: net))
            } else if net > 0.009 {
                creditors.append((id: item.id, name: item.name, net: net))
            }
        }

        // Sort debtors ascending (largest debt first: -50 before -20)
        debtors.sort { $0.net < $1.net }
        // Sort creditors descending (largest credit first: 50 before 20)
        creditors.sort { $0.net > $1.net }

        var transfers: [DebtTransfer] = []
        var dIdx = 0
        var cIdx = 0

        while dIdx < debtors.count && cIdx < creditors.count {
            let debtor = debtors[dIdx]
            let creditor = creditors[cIdx]

            let debtAmount = Swift.abs(debtor.net)
            let creditAmount = creditor.net

            let settledAmount = min(debtAmount, creditAmount)
            let roundedAmount = (settledAmount * 100).rounded() / 100.0

            if roundedAmount > 0.009 {
                transfers.append(DebtTransfer(
                    fromMemberID: debtor.id,
                    fromMemberName: debtor.name,
                    toMemberID: creditor.id,
                    toMemberName: creditor.name,
                    amount: roundedAmount
                ))
            }

            debtors[dIdx].net += settledAmount
            creditors[cIdx].net -= settledAmount

            if Swift.abs(debtors[dIdx].net) < 0.009 {
                dIdx += 1
            }
            if creditors[cIdx].net < 0.009 {
                cIdx += 1
            }
        }

        return transfers
    }
}
