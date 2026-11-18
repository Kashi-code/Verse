import SwiftUI

/// Progress bar with elapsed and remaining time. Drag to seek; VoiceOver can swipe up/down to skip 10 s.
struct PlaybackScrubber: View {
    @Environment(PlayerController.self) private var player
    @State private var dragTime: TimeInterval?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !player.isPlaying || dragTime != nil)) { _ in
            let duration = max(player.duration, 0)
            let time = min(dragTime ?? player.currentTime, duration)

            VStack(spacing: 6) {
                GeometryReader { proxy in
                    let progress = duration > 0 ? time / duration : 0
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.25))
                        Capsule().fill(.white.opacity(dragTime == nil ? 0.8 : 1))
                            .frame(width: proxy.size.width * progress)
                    }
                    .frame(height: dragTime == nil ? 6 : 10)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                dragTime = fraction(value.location.x, width: proxy.size.width) * duration
                            }
                            .onEnded { value in
                                player.seek(to: fraction(value.location.x, width: proxy.size.width) * duration)
                                dragTime = nil
                            }
                    )
                }
                .frame(height: 24)

                HStack {
                    Text(TimeFormatting.clock(time))
                    Spacer()
                    Text("-" + TimeFormatting.clock(duration - time))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback Position")
            .accessibilityValue(Text("\(TimeFormatting.clock(time)) of \(TimeFormatting.clock(duration))"))
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: player.seek(to: min(player.currentTime + 10, duration))
                case .decrement: player.seek(to: max(player.currentTime - 10, 0))
                @unknown default: break
                }
            }
        }
        .animation(.spring(duration: 0.25), value: dragTime == nil)
    }

    private func fraction(_ x: CGFloat, width: CGFloat) -> Double {
        guard width > 0 else { return 0 }
        return min(max(Double(x / width), 0), 1)
    }
}
