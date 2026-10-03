import SwiftUI

struct CardSurface: ViewModifier {
    var padding: CGFloat = 18
    var radius: CGFloat = 20
    var emphasized: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(emphasized ? Theme.accent.opacity(0.32) : Theme.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(padding: CGFloat = 18, radius: CGFloat = 20, emphasized: Bool = false) -> some View {
        modifier(CardSurface(padding: padding, radius: radius, emphasized: emphasized))
    }
}

struct MicroLabel: View {
    let text: String
    var color: Color = Theme.textFaint

    var body: some View {
        Text(text.uppercased())
            .font(Theme.microLabel)
            .tracking(0.6)
            .foregroundStyle(color)
    }
}

struct FadingRule: View {
    var color: Color = Theme.divider

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: color, location: 0.12),
                .init(color: color, location: 0.88),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct AccentTag: View {
    let text: String
    var style: Style = .accent

    enum Style { case accent, neutral, outline }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(9, .semibold))
            .tracking(0.3)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(style == .outline ? Theme.accent : .clear, lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch style {
        case .accent: Theme.accent300
        case .neutral: Theme.neutral100
        case .outline: Theme.accent
        }
    }

    private var background: Color {
        switch style {
        case .accent: Theme.accent900
        case .neutral: Theme.neutral900
        case .outline: .clear
        }
    }
}

struct IconTile: View {
    let systemImage: String
    var size: CGFloat = 38
    var radius: CGFloat = 12
    var emphasized: Bool = true
    var glow: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(emphasized ? AnyShapeStyle(Theme.markGradient) : AnyShapeStyle(Theme.neutral900))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(emphasized ? Theme.accent800 : Theme.hairline, lineWidth: 1)
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.46, weight: .medium))
                    .foregroundStyle(emphasized ? Theme.accent400 : Theme.neutral400)
                    .shadow(color: glow ? Theme.accent.opacity(0.6) : .clear, radius: glow ? 8 : 0)
            )
    }
}

struct StaggeredAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .onAppear {
                guard !reduceMotion else {
                    shown = true
                    return
                }
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(Double(index) * 0.06)) {
                    shown = true
                }
            }
    }
}

extension View {
    func staggered(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.accent
    var foreground: Color? = nil
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(foreground ?? Theme.canvasDeep)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(tint.opacity(configuration.isPressed ? 0.82 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var tint: Color = Theme.text
    var borderColor: Color = Theme.hairline
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.surface.opacity(configuration.isPressed ? 0.65 : 1),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(borderColor, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct PressableRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct CountingNumber: View {
    let value: Int
    var font: Font = Theme.mono(30, .semibold)
    var color: Color = Theme.text

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0

    var body: some View {
        Text("\(displayed)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText())
            .onAppear {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.9)) { displayed = value }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.55)) { displayed = newValue }
            }
    }
}

struct RingProgress: View {
    var progress: Double
    var lineWidth: CGFloat = 10
    var tint: Color = Theme.accent
    var track: Color = Theme.accent900

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animated: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, animated)))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.15), radius: 3)
        }
        .onAppear { apply(progress) }
        .onChange(of: progress) { _, newValue in apply(newValue) }
    }

    private func apply(_ target: Double) {
        if reduceMotion {
            animated = target
        } else {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85)) { animated = target }
        }
    }
}

struct GrowingBar: View {
    var fraction: Double
    var tint: Color
    var maxHeight: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(tint)
            .frame(height: max(3, (grown ? fraction : 0) * maxHeight))
            .onAppear {
                guard !reduceMotion else {
                    grown = true
                    return
                }
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) { grown = true }
            }
    }
}
