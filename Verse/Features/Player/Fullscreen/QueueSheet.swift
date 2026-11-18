import SwiftUI

/// Now playing, Up Next (drag to reorder, swipe to remove), autoplay and where the queue came from.
struct QueueSheet: View {
    @Environment(PlayerController.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                if let current = player.queue.current {
                    Section("Now Playing") {
                        QueueRow(track: current.track)
                            .listRowBackground(rowBackground)
                    }
                }
                Section {
                    ForEach(player.upNext) { item in
                        Button {
                            player.jump(to: item)
                        } label: {
                            QueueRow(track: item.track)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(rowBackground)
                    }
                    .onDelete { offsets in
                        let items = offsets.map { player.upNext[$0] }
                        items.forEach(player.removeFromUpNext)
                    }
                    .onMove { offsets, destination in
                        player.moveUpNext(fromOffsets: offsets, toOffset: destination)
                    }
                    if player.upNext.isEmpty {
                        Text(settings.autoplay
                             ? LocalizedStringKey("Similar songs will play when this one ends.")
                             : LocalizedStringKey("Use Play Next or Add to Queue on any song."))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .listRowBackground(rowBackground)
                    }
                } header: {
                    Text("Up Next")
                } footer: {
                    if let source = player.queue.source {
                        Text("Playing from \(source.title)")
                    }
                }
                Section {
                    Toggle(isOn: $settings.autoplay) {
                        Label("Autoplay", systemImage: "infinity")
                    }
                    .listRowBackground(rowBackground)
                } footer: {
                    Text("When the queue ends, keep playing similar songs.")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Queue")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { player.clearUpNext() }
                        .disabled(player.upNext.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                        .disabled(player.upNext.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: player.upNext.map(\.id))
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
    }

    /// Rows sit on the glass sheet instead of opaque cells.
    private var rowBackground: some View {
        Color.primary.opacity(0.06)
    }
}

private struct QueueRow: View {
    let track: TrackInfo

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(url: track.thumbnailURL ?? track.artworkURL, cornerRadius: DS.Radius.control, size: 40)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .lineLimit(1)
                Text(track.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
