import SwiftUI

/// A reusable grid view for picking an SF Symbol icon from a curated list of financial & lifestyle icons.
struct IconPickerView: View {
    @Binding var selectedIcon: String
    var columns: Int = 5

    static let curatedIcons: [String] = [
        "cart.fill", "fork.knife", "car.fill", "house.fill", "bolt.fill",
        "bag.fill", "ticket.fill", "cross.fill", "book.fill", "airplane",
        "briefcase.fill", "laptopcomputer", "chart.line.uptrend.xyaxis", "gift.fill", "creditcard.fill",
        "dollarsign.circle.fill", "banknote.fill", "film.fill", "gamecontroller.fill", "cup.and.saucer.fill",
        "fuelpump.fill", "bed.double.fill", "tshirt.fill", "dumbbell.fill", "pawprint.fill",
        "heart.fill", "music.note", "leaf.fill", "tag.fill", "ellipsis.circle.fill"
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 12) {
            ForEach(Self.curatedIcons, id: \.self) { icon in
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(selectedIcon == icon ? Color.primary.opacity(0.12) : Color(.secondarySystemFill))
                    .foregroundStyle(selectedIcon == icon ? Color.primary : Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(selectedIcon == icon ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedIcon = icon
                    }
                    .accessibilityIdentifier("iconPicker_\(icon)")
            }
        }
        .padding(.vertical, 8)
    }
}
