import AVKit
import MediaPlayer
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
            SleepTimerMenu()
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

/// Pause after some minutes or at the end of the song. The moon fills while a timer is set.
struct SleepTimerMenu: View {
    @Environment(PlayerController.self) private var player

    private static let minuteOptions = [5, 15, 30, 45, 60]

    var body: some View {
        Menu {
            if let end = player.sleepTimerEndDate {
                Section {
                    Text("Stops at \(end, style: .time)")
                }
            } else if player.sleepTimer == .endOfSong {
                Section {
                    Text("Stops when this song ends")
                }
            }
            ForEach(Self.minuteOptions, id: \.self) { minutes in
                Button {
                    player.setSleepTimer(.minutes(minutes))
                } label: {
                    Text("\(minutes) minutes")
                }
            }
            Button("End of Song", systemImage: "music.note") { player.setSleepTimer(.endOfSong) }
            if player.sleepTimer != nil {
                Divider()
                Button("Turn Off Timer", systemImage: "xmark", role: .destructive) { player.setSleepTimer(nil) }
            }
        } label: {
            Label("Sleep Timer", systemImage: player.sleepTimer == nil ? "moon.zzz" : "moon.zzz.fill")
                .foregroundStyle(player.sleepTimer == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        }
        .accessibilityValue(player.sleepTimer == nil ? Text("Off") : Text("On"))
        .sensoryFeedback(.selection, trigger: player.sleepTimer)
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

/// System volume slider (it also follows the hardware buttons). Hidden by the system in the simulator.
struct VolumeSlider: View {
    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            SystemVolumeView()
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 4)
    }
}

private struct SystemVolumeView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView(frame: .zero)
        view.tintColor = .white
        return view
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
