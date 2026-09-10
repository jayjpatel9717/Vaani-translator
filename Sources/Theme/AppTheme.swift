import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Soft Glass design tokens

struct AppTheme {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) {
        self.scheme = scheme
    }

    var isDark: Bool { scheme == .dark }

    // Accents (shared by both schemes)
    static let violet = Color(hex: 0x6D5BFF)
    static let coral = Color(hex: 0xFF8C69)
    static let mint = Color(hex: 0x4FD1A5)
    static let amber = Color(hex: 0xF5A524)

    // Text
    var ink: Color { isDark ? Color(hex: 0xF4F2FF) : Color(hex: 0x1E1B2E) }
    var secondary: Color { ink.opacity(isDark ? 0.60 : 0.55) }
    var tertiary: Color { ink.opacity(isDark ? 0.40 : 0.38) }
    var onPrimary: Color { isDark ? Color(hex: 0x1E1B2E) : .white }
    var successText: Color { isDark ? AppTheme.mint : Color(hex: 0x1E9E6A) }
    var warningText: Color { isDark ? AppTheme.amber : Color(hex: 0xB8741A) }

    // Surfaces
    var glass: Color { isDark ? Color.white.opacity(0.08) : Color.white.opacity(0.72) }
    var glassBorder: Color { isDark ? Color.white.opacity(0.14) : Color.white.opacity(0.90) }
    var shadow: Color { isDark ? Color.black.opacity(0.30) : Color(hex: 0x1E1B2E).opacity(0.08) }
    var segmentTrack: Color { isDark ? Color.white.opacity(0.06) : Color(hex: 0x1E1B2E).opacity(0.06) }
    var segmentOn: Color { isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.85) }
    var keycap: Color { isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.85) }
    var meshColors: [Color] {
        isDark ? [Color(hex: 0x1E1A38), Color(hex: 0x2E1F2C), Color(hex: 0x15271F)]
               : [Color(hex: 0xEFE9FF), Color(hex: 0xFFE9DD), Color(hex: 0xE3F7EF)]
    }

    static func modeColor(_ mode: TranslationMode) -> Color {
        switch mode {
        case .translit: return violet
        case .translate: return mint
        case .codemix: return coral
        case .transcribe, .verbatim: return amber
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension Font {
    /// Rounded SF is the closest system face to the Manrope used in the design.
    static func glass(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
