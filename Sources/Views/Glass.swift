import SwiftUI

// Shared Soft Glass building blocks used by every screen.

struct MeshBackground: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.meshColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(RadialGradient(colors: [AppTheme.violet.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 110))
                .frame(width: 220, height: 220)
                .position(x: 50, y: 50)
            Circle()
                .fill(RadialGradient(colors: [AppTheme.coral.opacity(0.35), .clear], center: .center, startRadius: 0, endRadius: 120))
                .frame(width: 240, height: 240)
                .position(x: 340, y: 240)
        }
        .ignoresSafeArea()
    }
}

struct GlassCard: ViewModifier {
    let theme: AppTheme
    var radius: CGFloat = 14
    var dimmed = false

    func body(content: Content) -> some View {
        content
            .background(theme.glass)
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(theme.glassBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: theme.shadow, radius: 9, y: 6)
            .opacity(dimmed ? 0.5 : 1)
    }
}

extension View {
    func glassCard(_ theme: AppTheme, radius: CGFloat = 14, dimmed: Bool = false) -> some View {
        modifier(GlassCard(theme: theme, radius: radius, dimmed: dimmed))
    }
}

struct Orb: View {
    enum Mode { case ready, listening, translating, off }

    let theme: AppTheme
    var mode: Mode = .ready
    var size: CGFloat = 96
    var icon: String = "mic.fill"

    @State private var pulse = false
    @State private var spin = false

    private var gradient: AngularGradient {
        switch mode {
        case .ready:
            return AngularGradient(colors: [AppTheme.violet, AppTheme.coral, AppTheme.mint, AppTheme.violet], center: .center, angle: .degrees(210))
        case .listening:
            return AngularGradient(colors: [AppTheme.coral, Color(hex: 0xFF5E8A), AppTheme.violet, AppTheme.coral], center: .center, angle: .degrees(210))
        case .translating:
            return AngularGradient(colors: [AppTheme.violet.opacity(0.55), AppTheme.coral.opacity(0.55)], center: .center)
        case .off:
            return AngularGradient(colors: [theme.ink.opacity(0.25), theme.ink.opacity(0.10)], center: .center)
        }
    }

    private var glow: Color {
        switch mode {
        case .ready: return AppTheme.violet.opacity(0.35)
        case .listening: return AppTheme.coral.opacity(0.45)
        case .translating: return AppTheme.violet.opacity(0.25)
        case .off: return theme.ink.opacity(0.10)
        }
    }

    var body: some View {
        ZStack {
            switch mode {
            case .ready:
                Circle()
                    .fill(theme.isDark ? Color.white.opacity(0.06) : Color.white.opacity(0.45))
                    .overlay(Circle().stroke(theme.glassBorder, lineWidth: 1))
                    .frame(width: size + 28, height: size + 28)
            case .listening:
                Circle()
                    .stroke(AppTheme.coral.opacity(0.28), lineWidth: 1.5)
                    .frame(width: size + 56, height: size + 56)
                    .scaleEffect(pulse ? 1.08 : 0.94)
                Circle()
                    .fill(AppTheme.coral.opacity(0.14))
                    .overlay(Circle().stroke(AppTheme.coral.opacity(0.45), lineWidth: 1))
                    .frame(width: size + 28, height: size + 28)
                    .scaleEffect(pulse ? 1.05 : 0.97)
            case .translating:
                Circle()
                    .trim(from: 0, to: 0.66)
                    .stroke(AngularGradient(colors: [AppTheme.violet, AppTheme.coral, .clear], center: .center), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: size + 20, height: size + 20)
                    .rotationEffect(.degrees(spin ? 360 : 0))
            case .off:
                EmptyView()
            }

            Circle()
                .fill(gradient)
                .overlay(Circle().fill(Color.white.opacity(0.22)).padding(size * 0.105))
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: size * 0.31, weight: .medium))
                        .foregroundColor(.white)
                )
                .frame(width: size, height: size)
                .shadow(color: glow, radius: 20, y: 12)
        }
        .frame(height: size + 36)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
        }
    }
}

struct Keycap: View {
    let text: String
    let theme: AppTheme

    var body: some View {
        Text(text)
            .font(.glass(10, .heavy))
            .foregroundColor(theme.ink)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(theme.keycap)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: theme.ink.opacity(0.15), radius: 1.5, y: 1)
    }
}

struct PillButton: View {
    let title: String
    var icon: String? = nil
    var primary = false
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                if let icon {
                    Image(systemName: icon).font(.system(size: 9, weight: .bold))
                }
            }
            .font(.glass(11, .bold))
            .foregroundColor(primary ? theme.onPrimary : theme.ink)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(primary ? theme.ink : theme.glass)
            .overlay(Capsule().stroke(primary ? theme.ink : theme.glassBorder, lineWidth: 1))
            .clipShape(Capsule())
            .shadow(color: theme.shadow, radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct IconCircleButton: View {
    let systemName: String
    let theme: AppTheme
    var tint: Color? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint == nil ? theme.ink : .white)
                .frame(width: 32, height: 32)
                .background(tint ?? theme.glass)
                .overlay(Circle().stroke(tint == nil ? theme.glassBorder : .clear, lineWidth: 1))
                .clipShape(Circle())
                .shadow(color: tint?.opacity(0.45) ?? theme.shadow, radius: 6, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct GlassSegmented<T: Hashable>: View {
    let items: [(T, String)]
    @Binding var selection: T
    let theme: AppTheme
    var height: CGFloat = 30

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.0) { item in
                let on = item.0 == selection
                Button(action: { withAnimation(.easeOut(duration: 0.15)) { selection = item.0 } }) {
                    Text(item.1)
                        .font(.glass(10.5, .bold))
                        .foregroundColor(on ? theme.ink : theme.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: height)
                        .background(on ? theme.segmentOn : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: on ? theme.shadow : .clear, radius: 4, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(theme.segmentTrack)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct WaveformBars: View {
    let level: Float
    var count = 16

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                let shape = 0.55 + 0.45 * sin(Double(i) * 1.3 + 0.7)
                let h = 6 + CGFloat(min(1, max(0, level * 10))) * 30 * shape
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [AppTheme.coral, AppTheme.violet], startPoint: .top, endPoint: .bottom))
                    .frame(width: 4, height: h)
            }
        }
        .frame(height: 40)
        .frame(maxWidth: .infinity)
        .animation(.linear(duration: 0.08), value: level)
    }
}

struct StatusChip: View {
    let text: String
    let color: Color
    let textColor: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.glass(10, .heavy)).foregroundColor(textColor)
        }
    }
}
