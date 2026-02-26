import SwiftUI

// MARK: - Material Design 3 Theme
// Seed color: #B33B15 (Terracotta)

/// Extension to create adaptive colors that switch between light and dark mode
extension Color {
    init(light: Color, dark: Color) {
        #if os(iOS)
        self.init(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif os(watchOS)
        // watchOS doesn't have UITraitCollection, use dark mode colors as default
        self = dark
        #else
        self = light
        #endif
    }

    init(lightHex: String, darkHex: String) {
        self.init(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}

// MARK: - App Colors

/// Centralized theme colors based on Material Design 3
/// Seed color: #B33B15 (Terracotta)
struct AppColors {

    // MARK: - Primary

    /// Primary accent color for buttons, accents, active states
    /// Light: #8F4C38, Dark: #FFB5A0
    static let primary = Color(lightHex: "8F4C38", darkHex: "FF8B69")

    /// Text color on primary backgrounds
    /// Light: #FFFFFF, Dark: #561F0F
    static let onPrimary = Color(lightHex: "FFFFFF", darkHex: "561F0F")

    /// Container color for cards, badges
    /// Light: #FFDBD1, Dark: #723523
    static let primaryContainer = Color(lightHex: "FFDBD1", darkHex: "723523")

    /// Text color on primary container
    /// Light: #3A0B01, Dark: #FFDBD1
    static let onPrimaryContainer = Color(lightHex: "3A0B01", darkHex: "FFDBD1")

    // MARK: - Secondary

    /// Secondary color for secondary actions
    /// Light: #77574E, Dark: #E7BDB2
    static let secondary = Color(lightHex: "77574E", darkHex: "D59F8F")

    /// Text color on secondary backgrounds
    /// Light: #FFFFFF, Dark: #442A22
    static let onSecondary = Color(lightHex: "FFFFFF", darkHex: "442A22")

    /// Secondary container color
    /// Light: #FFDBD1, Dark: #5D4037
    static let secondaryContainer = Color(lightHex: "FFDBD1", darkHex: "5D4037")

    // MARK: - Tertiary

    /// Tertiary color for contrast elements (sunset purple)
    /// Light: #6D5E00, Dark: #DBC66E
    static let tertiary = Color(lightHex: "6C5D2F", darkHex: "C1AA5C")

    // MARK: - Background & Surface

    /// Page background color
    /// Light: #FFF8F6, Dark: #1A110F
    static let background = Color(lightHex: "FFF8F6", darkHex: "1A110F")

    /// Surface color (cards, sheets)
    /// Light: #FFF8F6, Dark: #1A110F
    static let surface = Color(lightHex: "FFF8F6", darkHex: "1A110F")

    /// Elevated surface color
    /// Light: #FCEEEA, Dark: #251916
    static let surfaceContainer = Color(lightHex: "FCEEEA", darkHex: "251916")

    /// Higher elevated surface
    /// Light: #F6E8E4, Dark: #302320
    static let surfaceContainerHigh = Color(lightHex: "F6E8E4", darkHex: "302320")

    // MARK: - Text Colors

    /// Primary text color on background
    /// Light: #231917, Dark: #F1DFDA
    static let onBackground = Color(lightHex: "231917", darkHex: "F1DFDA")

    /// Primary text color on surface
    /// Light: #231917, Dark: #F1DFDA
    static let onSurface = Color(lightHex: "231917", darkHex: "F1DFDA")

    /// Secondary/variant text color
    /// Light: #53433F, Dark: #D8C2BC
    static let onSurfaceVariant = Color(lightHex: "53433F", darkHex: "D8C2BC")

    // MARK: - Error

    /// Error color for destructive actions
    /// Light: #BA1A1A, Dark: #FFB4AB
    static let error = Color(lightHex: "BA1A1A", darkHex: "FFB4AB")

    /// Text on error backgrounds
    /// Light: #FFFFFF, Dark: #690005
    static let onError = Color(lightHex: "FFFFFF", darkHex: "690005")

    /// Error container
    /// Light: #FFDAD6, Dark: #93000A
    static let errorContainer = Color(lightHex: "FFDAD6", darkHex: "93000A")

    // MARK: - Semantic Aliases

    /// Main accent color (alias for primary)
    static let accent = primary

    /// Text color (alias for onBackground)
    static let text = onBackground

    /// Secondary text color (alias for onSurfaceVariant)
    static let textSecondary = onSurfaceVariant

    /// Success color (kept as system green for universal recognition)
    static let success = Color.green

    // MARK: - Gradient Colors

    /// Light glow color for light visualization
    /// Light: #FFB5A0, Dark: #FFB5A0
    static let lightGlow = Color(hex: "FF8B69")

    /// Warm accent for gradients
    /// Light: #FFDBD1, Dark: #723523
    static let warmAccent = primaryContainer

    // MARK: - Outline

    /// Outline/border color
    /// Light: #85736E, Dark: #A08D87
    static let outline = Color(lightHex: "85736E", darkHex: "A08C87")

    /// Variant outline for less emphasis
    /// Light: #D8C2BC, Dark: #53433F
    static let outlineVariant = Color(lightHex: "D8C2BC", darkHex: "53433F")
}

// MARK: - Gradient Helpers

// MARK: - Scaled Font Helpers (Dynamic Type Support)

#if os(iOS)
extension Font {
    /// Creates a scaled large display font that respects Dynamic Type settings.
    /// Base size scales from the provided value according to user's text size preference.
    static func scaledLargeDisplay(size baseSize: CGFloat, weight: Font.Weight = .bold, design: Font.Design = .rounded) -> Font {
        let scaledSize = UIFontMetrics.default.scaledValue(for: baseSize)
        return .system(size: scaledSize, weight: weight, design: design)
    }

    /// Creates a scaled system font that respects Dynamic Type settings.
    static func scaledSystem(size baseSize: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let scaledSize = UIFontMetrics.default.scaledValue(for: baseSize)
        return .system(size: scaledSize, weight: weight, design: design)
    }
}

extension View {
    /// Applies minimum scale factor for graceful text degradation when space is limited.
    func scaledText(minimumFactor: CGFloat = 0.5) -> some View {
        self.minimumScaleFactor(minimumFactor)
    }
}
#endif

#if os(iOS)
extension AppColors {
    /// Creates a light visualization gradient based on brightness
    static func lightGradient(isOn: Bool, brightness: Double) -> LinearGradient {
        if isOn {
            return LinearGradient(
                colors: [
                    primary.opacity(0.1 + brightness * 0.3),
                    primaryContainer.opacity(0.05 + brightness * 0.15),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    /// Creates a radial glow for light visualization
    static func lightGlowGradient(isOn: Bool, brightness: Double) -> RadialGradient {
        if isOn {
            return RadialGradient(
                colors: [
                    primary.opacity(0.4 * brightness),
                    lightGlow.opacity(0.2 * brightness),
                    Color.clear
                ],
                center: .center,
                startRadius: 50,
                endRadius: 150
            )
        } else {
            return RadialGradient(
                colors: [Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 150
            )
        }
    }
}
#endif
