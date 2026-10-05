import SwiftUI

/// A reusable grid view for picking hex colors from the preset palette.
struct ColorPickerGridView: View {
    @Binding var selectedHex: String
    var columns: Int = 5

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: columns), spacing: 14) {
            ForEach(Color.presetPalette, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle()
                            .stroke(Color.primary, lineWidth: selectedHex.uppercased() == color.hexString.uppercased() ? 3 : 0)
                            .padding(-3)
                    )
                    .contentShape(Circle())
                    .onTapGesture {
                        selectedHex = color.hexString
                    }
                    .accessibilityIdentifier("colorPicker_\(color.hexString)")
            }
        }
        .padding(.vertical, 8)
    }
}
