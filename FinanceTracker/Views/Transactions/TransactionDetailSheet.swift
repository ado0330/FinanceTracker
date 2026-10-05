import SwiftUI
import SwiftData

/// Modal detail sheet displaying high-resolution food/receipt photos, reviews,
/// and complete transaction metadata.
struct TransactionDetailSheet: View {

    let transaction: Transaction
    var onEdit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var currencyCode: String {
        transaction.ledger?.currency ?? "MYR"
    }

    private var amountString: String {
        let raw = transaction.amount
        let formatted = raw.currencyString(code: currencyCode)
        return transaction.type == .income ? "+\(formatted)" : formatted
    }

    private var amountColor: Color {
        transaction.type == .income ? Color(.systemGreen) : Color(.label)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Photo / Receipt Image ───────────────────────────────
                    if let data = transaction.receiptImageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                    }

                    // ── Title & Amount Card ─────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(transaction.displayName)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.primary)

                                HStack(spacing: 8) {
                                    if let cat = transaction.category {
                                        HStack(spacing: 4) {
                                            Image(systemName: cat.icon)
                                                .font(.caption)
                                            Text(cat.name)
                                                .font(.caption.weight(.semibold))
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color(hex: cat.colorHex).opacity(0.15))
                                        .foregroundStyle(Color(hex: cat.colorHex))
                                        .clipShape(Capsule())
                                    }

                                    if let acc = transaction.account {
                                        Text(acc.name)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color(.tertiarySystemFill))
                                            .clipShape(Capsule())
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(transaction.date.shortDisplay)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(amountString)
                                .font(.title.weight(.bold))
                                .foregroundStyle(amountColor)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    // ── Note / Food Review Card ─────────────────────────────
                    let trimmedNote = transaction.note.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedNote.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 5) {
                                Image(systemName: "quote.opening")
                                    .font(.subheadline.weight(.bold))
                                Text("Food Review / Note")
                                    .font(.caption.weight(.bold))
                                    .textCase(.uppercase)
                                    .tracking(0.8)
                            }
                            .foregroundStyle(.secondary)

                            Text(trimmedNote)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(4)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    // ── Tags ────────────────────────────────────────────────
                    if !transaction.tags.isEmpty {
                        HStack {
                            Text("Tags:")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(transaction.tags) { tag in
                                Text("#\(tag.name)")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Edit") {
                        dismiss()
                        onEdit()
                    }
                    .font(.subheadline.weight(.semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}
