import SwiftUI

/// The app's own glass surface: translucent material, a light hairline and a soft shadow.
/// With Reduce Transparency it becomes a solid, slightly tinted surface.
struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = DS.Radius.card
    var tint: Color?
    var showsShadow = true

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                if reduceTransparency {
                    shape.fill(Color(.secondarySystemBackground))
                        .overlay { if let tint { shape.fill(tint.opacity(0.18)) } }
                } else {
                    shape.fill(.ultraThinMaterial)
                        .overlay { if let tint { shape.fill(tint.opacity(0.22)) } }
                }
            }
            .overlay {
                shape.strokeBorder(DS.Border.color, lineWidth: DS.Border.hairline)
            }
            .shadow(color: showsShadow ? DS.Shadow.color : .clear, radius: DS.Shadow.radius, y: DS.Shadow.y)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = DS.Radius.card, tint: Color? = nil, shadow: Bool = true) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius, tint: tint, showsShadow: shadow))
    }
}

/// Buttons shrink a little while pressed.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(DS.Motion.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}

/// Small capsule saying where a song comes from, and whether it is a preview.
struct SourceBadge: View {
    let track: TrackInfo

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(DS.Text.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(DS.Fill.standard))
            .accessibilityLabel(accessibilityLabel)
    }

    private var label: LocalizedStringKey {
        switch track.source {
        case .audius: "AUDIUS"
        case .apple: track.isPreview ? "PREVIEW" : "APPLE MUSIC"
        }
    }

    private var accessibilityLabel: Text {
        switch track.source {
        case .audius: Text("From Audius")
        case .apple: track.isPreview ? Text("30-second preview from Apple Music") : Text("From Apple Music")
        }
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DS.Typography.sectionTitle)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let action {
                Button("See All", action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, DS.Spacing.m)
    }
}

/// Animated bars shown next to the song that is playing.
struct PlayingIndicator: View {
    var isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isAnimating || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    let phase = sin(time * (5 + Double(index) * 1.7) + Double(index))
                    Capsule()
                        .frame(width: 3, height: isAnimating && !reduceMotion ? 5 + 9 * (phase + 1) / 2 : 6)
                }
            }
            .frame(width: 15, height: 14, alignment: .bottom)
        }
        .foregroundStyle(.tint)
        .accessibilityLabel("Now Playing")
    }
}
