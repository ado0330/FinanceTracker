import SwiftUI
import UIKit

// MARK: - Color ← Hex String

extension Color {

    /// Create a Color from a hex string.
    /// Accepts: `"#RRGGBB"`, `"#RRGGBBAA"`, `"RRGGBB"` (with or without `#`).
    /// Falls back to a neutral indigo if the string is malformed.
    init(hex: String) {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        switch cleaned.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >>  8) & 0xFF) / 255
            b = Double( value        & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >>  8) & 0xFF) / 255
            a = Double( value        & 0xFF) / 255
        default:
            // Fallback — indigo
            r = 0.353; g = 0.545; b = 0.878; a = 1.0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    // MARK: - Color → Hex String

    /// Returns `"#RRGGBB"` (no alpha channel). Safe to persist in SwiftData.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int((r * 255).rounded()),
                      Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }

    // MARK: - Preset Palette
    //
    // Used by ColorPickerGridView (T-05 onwards) and DataSeeder.
    // 15 curated, HSL-balanced colours that all look great on both light & dark backgrounds.

    static let presetPalette: [Color] = [
        Color(hex: "#1C1C1E"),   // Obsidian / Pure Charcoal
        Color(hex: "#2C2C2E"),   // Deep Graphite
        Color(hex: "#3A3A3C"),   // Slate Gray
        Color(hex: "#48484A"),   // Dark Stone
        Color(hex: "#636366"),   // Medium Gray
        Color(hex: "#8E8E93"),   // Silver Slate
        Color(hex: "#5A8BDF"),   // Minimal Blue
        Color(hex: "#2ECC71"),   // Muted Emerald
        Color(hex: "#FF6B6B"),   // Soft Coral
        Color(hex: "#F39C12"),   // Amber
        Color(hex: "#8B5CF6"),   // Violet
        Color(hex: "#4ECDC4"),   // Teal
        Color(hex: "#E74C3C"),   // Crimson
        Color(hex: "#45B7D1"),   // Sky
        Color(hex: "#9B59B6"),   // Plum
    ]
}
