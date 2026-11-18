import AVKit
import SwiftUI

struct TransportControls: View {
    @Environment(PlayerController.self) private var player

    var body: some View {
        HStack {
            Button("Shuffle", systemImage: "shuffle") { player.toggleShuffle() }
                .font(.title3)
                .modifier(ActiveToggleStyle(isActive: player.isShuffled))
                .accessibilityValue(player.isShuffled ? Text("On") : Text("Off"))
            Spacer()
            Button("Previous", systemImage: "backward.fill") { player.skipToPrevious() }
                .font(.title)
            Spacer()
            Button(
                player.isPlaying ? LocalizedStringKey("Pause") : LocalizedStringKey("Play"),
                systemImage: player.isPlaying ? "pause.fill" : "play.fill"
            ) {
                player.togglePlayPause()
            }
            .font(.system(size: 48))
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 64)
            Spacer()
            Button("Next", systemImage: "forward.fill") { player.skipToNext() }
                .font(.title)
            Spacer()
            Button("Repeat", systemImage: player.repeatMode == .one ? "repeat.1" : "repeat") { player.cycleRepeatMode() }
                .font(.title3)
                .modifier(ActiveToggleStyle(isActive: player.repeatMode != .off))
                .accessibilityValue(repeatDescription)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .disabled(player.currentTrack == nil)
    }

    private var repeatDescription: Text {
        switch player.repeatMode {
        case .off: Text("Off")
        case .all: Text("All")
        case .one: Text("One")
        }
    }
}

/// A soft circle behind shuffle and repeat when they're on.
private struct ActiveToggleStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .foregroundStyle(isActive ? .primary : .secondary)
            .frame(width: 40, height: 40)
            .background(Circle().fill(.white.opacity(isActive ? 0.2 : 0)))
    }
}

struct PlayerBottomBar: View {
    @Binding var showsLyrics: Bool
    @Binding var showsQueue: Bool

    var body: some View {
        HStack {
            Button("Lyrics", systemImage: showsLyrics ? "quote.bubble.fill" : "quote.bubble") {
                showsLyrics.toggle()
            }
            .accessibilityValue(showsLyrics ? Text("Shown") : Text("Hidden"))
            Spacer()
            AirPlayButton()
                .frame(width: 44, height: 44)
            Spacer()
            Button("Queue", systemImage: "list.bullet") {
                showsQueue = true
            }
        }
        .font(.title3)
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
    }
}

/// The system AirPlay route picker.
struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = UIColor.white.withAlphaComponent(0.6)
        view.activeTintColor = .white
        view.prioritizesVideoDevices = false
        return view
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
