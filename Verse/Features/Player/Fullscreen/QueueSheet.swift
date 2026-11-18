import SwiftUI

/// Now playing, Up Next (drag to reorder, swipe to remove) and where the queue came from.
struct QueueSheet: View {
    @Environment(PlayerController.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let current = player.queue.current {
                    Section("Now Playing") {
                        QueueRow(track: current.track)
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
                    }
                    .onDelete { offsets in
                        let items = offsets.map { player.upNext[$0] }
                        items.forEach(player.removeFromUpNext)
                    }
                    .onMove { offsets, destination in
                        player.moveUpNext(fromOffsets: offsets, toOffset: destination)
                    }
                } header: {
                    Text("Up Next")
                } footer: {
                    if let source = player.queue.source {
                        Text("Playing from \(source.title)")
                    }
                }
            }
            .overlay {
                if player.upNext.isEmpty {
                    ContentUnavailableView("Nothing Up Next", systemImage: "list.bullet",
                                           description: Text("Use Play Next or Add to Queue on any song."))
                }
            }
            .navigationTitle("Queue")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", role: .destructive) { player.clearUpNext() }
                        .disabled(player.upNext.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sensoryFeedback(.selection, trigger: player.upNext.map(\.id))
        }
        .presentationDetents([.medium, .large])
    }
}

private struct QueueRow: View {
    let track: TrackInfo

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(key: track.artworkKey, cornerRadius: 6)
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
