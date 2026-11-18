import SwiftData
import SwiftUI

/// A song row: artwork, title, source badge and artist, duration. Shows bars while playing.
struct TrackRow: View {
    let track: TrackInfo
    var number: Int?
    var showsArtwork = true

    @Environment(PlayerController.self) private var player

    private var isCurrent: Bool { player.currentTrack?.id == track.id }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            if let number {
                Group {
                    if isCurrent {
                        PlayingIndicator(isAnimating: player.isPlaying)
                    } else {
                        Text("\(number)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(DS.Text.tertiary)
                    }
                }
                .frame(minWidth: 24)
            }
            if showsArtwork {
                ArtworkView(url: track.thumbnailURL ?? track.artworkURL, size: DS.Size.rowArtwork)
                    .frame(width: DS.Size.rowArtwork, height: DS.Size.rowArtwork)
                    .overlay {
                        if isCurrent && number == nil {
                            RoundedRectangle(cornerRadius: DS.Radius.control).fill(.black.opacity(0.35))
                            PlayingIndicator(isAnimating: player.isPlaying)
                                .foregroundStyle(.white)
                        }
                    }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(DS.Typography.rowTitle)
                    .foregroundStyle(isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(DS.Text.primary))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    SourceBadge(track: track)
                    Text(track.artist)
                        .font(DS.Typography.rowSubtitle)
                        .foregroundStyle(DS.Text.tertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !track.isPreview, track.duration > 0 {
                Text(TimeFormatting.clock(track.duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(DS.Text.tertiary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

/// Long-press menu for a song.
struct TrackContextMenu: View {
    let track: TrackInfo

    @Environment(PlayerController.self) private var player
    @Environment(Router.self) private var router: Router?
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") { player.playNext([track]) }
        Button("Add to Queue", systemImage: "text.line.last.and.arrowtriangle.forward") { player.addToQueue([track]) }
        Divider()
        let library = UserLibrary(context: modelContext)
        if library.isLiked(track.id) {
            Button("Remove from Liked Songs", systemImage: "heart.slash") { library.toggleLike(track) }
        } else {
            Button("Like", systemImage: "heart") { library.toggleLike(track) }
        }
        if let artist = track.artistReference {
            Button("Go to Artist", systemImage: "music.microphone") { router?.open(.artist(artist)) }
        }
        if let album = track.albumReference {
            Button("Go to Album", systemImage: "square.stack") { router?.open(.collection(album)) }
        }
        if let url = track.externalURL {
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}

/// Square artwork with two lines of text, used in shelves.
struct TrackCard: View {
    let track: TrackInfo
    var size: CGFloat = DS.Size.cardArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ArtworkView(url: track.artworkURL, cornerRadius: DS.Radius.card, size: size)
                .frame(width: size, height: size)
                .shadow(color: DS.Shadow.color, radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if track.isPreview {
                        Image(systemName: "30.circle.fill")
                            .font(.caption2)
                            .accessibilityLabel("Preview")
                    }
                    Text(track.artist)
                        .lineLimit(1)
                }
                .font(.footnote)
                .foregroundStyle(DS.Text.tertiary)
            }
            .frame(width: size, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct CollectionCard: View {
    let collection: CatalogCollection
    var size: CGFloat = DS.Size.cardArtwork

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ArtworkView(url: collection.artworkURL, cornerRadius: DS.Radius.card, size: size)
                .frame(width: size, height: size)
                .zoomSource(collection.id)
                .shadow(color: DS.Shadow.color, radius: 10, y: 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(collection.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(collection.subtitle)
                    .font(.footnote)
                    .foregroundStyle(DS.Text.tertiary)
                    .lineLimit(1)
            }
            .frame(width: size, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ArtistBubble: View {
    let artist: CatalogArtist
    var size: CGFloat = DS.Size.artistAvatar

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ArtworkView(url: artist.imageURL, size: size, isCircle: true)
                .frame(width: size, height: size)
                .zoomSource(artist.id)
                .shadow(color: DS.Shadow.color, radius: 10, y: 5)
            HStack(spacing: 3) {
                Text(artist.name)
                    .lineLimit(1)
                if artist.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Verified")
                }
            }
            .font(.subheadline.weight(.semibold))
            .frame(width: size)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Glass Play and Shuffle buttons for the top of song lists and detail pages.
struct PlayShuffleButtons: View {
    let action: (_ shuffled: Bool) -> Void

    @State private var taps = 0

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            Button {
                taps += 1
                action(false)
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            Button {
                taps += 1
                action(true)
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .controlSize(.large)
        .font(.headline)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
    }
}

/// A horizontal shelf with a title.
struct Shelf<Item: Identifiable, Content: View>: View {
    let title: LocalizedStringKey
    let items: [Item]
    @ViewBuilder let content: (Item) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.s) {
            SectionHeader(title: title)
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: DS.Spacing.s) {
                    ForEach(items) { item in
                        content(item)
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
            }
            .scrollIndicators(.hidden)
        }
    }
}
