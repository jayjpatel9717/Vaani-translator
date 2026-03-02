import SwiftUI

// MARK: - Appearance Mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
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

// MARK: - Adaptive Design Tokens

struct AppTheme {
    let scheme: ColorScheme

    init(_ scheme: ColorScheme) {
        self.scheme = scheme
    }

    var isDark: Bool { scheme == .dark }

    // MARK: - Brand

    var brandBlue: Color {
        isDark ? Color(red: 0.50, green: 0.58, blue: 1.00)
               : Color(red: 0.35, green: 0.45, blue: 0.95)
    }

    var brandWarm: Color {
        isDark ? Color(red: 1.00, green: 0.62, blue: 0.38)
               : Color(red: 0.85, green: 0.50, blue: 0.35)
    }

    // MARK: - Gradients

    var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brandBlue, brandWarm],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var recordingGradient: LinearGradient {
        let colors: [Color] = isDark
            ? [Color(red: 1.0, green: 0.32, blue: 0.32), Color(red: 1.0, green: 0.55, blue: 0.20)]
            : [.red, .orange]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Surfaces

    var cardBackground: Color {
        isDark ? Color(white: 0.14) : Color(nsColor: .controlBackgroundColor)
    }

    var cardBorder: Color {
        isDark ? Color(white: 1.0).opacity(0.10) : Color(white: 0.0).opacity(0.06)
    }

    var sectionHeaderColor: Color {
        Color(nsColor: .tertiaryLabelColor)
    }

    // MARK: - Status

    var statusSuccess: Color {
        isDark ? Color(red: 0.35, green: 0.90, blue: 0.55) : .green
    }

    var statusWarning: Color {
        isDark ? Color(red: 1.00, green: 0.78, blue: 0.30) : .orange
    }

    var statusError: Color {
        isDark ? Color(red: 1.00, green: 0.42, blue: 0.42) : .red
    }

    // MARK: - Tinted Backgrounds

    var errorTint: Color {
        Color.red.opacity(isDark ? 0.14 : 0.06)
    }

    var warningTint: Color {
        Color.orange.opacity(isDark ? 0.16 : 0.08)
    }

    // MARK: - Shadows & Glows

    var brandShadow: Color {
        isDark ? brandBlue.opacity(0.40) : brandBlue.opacity(0.20)
    }

    var recordingShadow: Color {
        isDark ? Color.red.opacity(0.45) : Color.red.opacity(0.25)
    }

    var recordingPulse: Color {
        isDark ? Color.red.opacity(0.35) : Color.red.opacity(0.20)
    }

    var shadowRadius: CGFloat {
        isDark ? 16 : 12
    }
}
