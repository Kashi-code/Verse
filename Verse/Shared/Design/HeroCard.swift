import SwiftUI

/// Big cover card for "Trending now". The title sits on a glass strip tinted with the cover colour.
struct HeroTrackCard: View {
    let track: TrackInfo

    @State private var palette = CoverPalette.neutral

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ArtworkView(url: track.artworkURL, cornerRadius: DS.Radius.panel, size: DS.Size.heroArtwork)
                .frame(width: DS.Size.heroArtwork, height: DS.Size.heroArtwork)
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    SourceBadge(track: track)
                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(.white)
            .padding(DS.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(cornerRadius: DS.Radius.card, tint: Color(palette.accent), shadow: false)
            .environment(\.colorScheme, .dark)
            .padding(DS.Spacing.xs)
        }
        .frame(width: DS.Size.heroArtwork, height: DS.Size.heroArtwork)
        .shadow(color: Color(palette.accent).opacity(0.45), radius: 22, y: 12)
        .task(id: track.artworkURL) {
            palette = await CoverPaletteProvider.shared.palette(for: track.artworkURL)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Big cover with the cover colours bleeding softly down into the page.
struct HeroHeader<Actions: View>: View {
    let artworkURL: URL?
    let title: String
    let subtitle: String
    var isCircle = false
    /// How far the page has scrolled; the colour bleed fades out as you scroll.
    var scrollOffset: CGFloat = 0
    var onSubtitleTap: (() -> Void)?
    @ViewBuilder let actions: () -> Actions

    @State private var palette = CoverPalette.neutral

    var body: some View {
        VStack(spacing: DS.Spacing.s) {
            ArtworkView(url: artworkURL, cornerRadius: DS.Radius.panel, size: 240, isCircle: isCircle)
                .frame(width: 240, height: 240)
                .shadow(color: Color(palette.accent).opacity(0.5), radius: 30, y: 16)
                .scaleEffect(1 - min(max(scrollOffset, 0) / 1600, 0.12), anchor: .bottom)
                .padding(.top, DS.Spacing.m)
            Text(title)
                .font(.title.weight(.heavy))
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            if let onSubtitleTap {
                Button(subtitle, action: onSubtitleTap)
                    .font(.title3.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
            } else if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(DS.Text.secondary)
            }
            actions()
                .padding(.top, DS.Spacing.xs)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.bottom, DS.Spacing.m)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            ColorBleed(palette: palette)
                .opacity(1 - min(max(scrollOffset, 0) / 320, 1))
        }
        .task(id: artworkURL) {
            let palette = await CoverPaletteProvider.shared.palette(for: artworkURL)
            withAnimation(DS.Motion.smooth) { self.palette = palette }
        }
    }
}

/// Blurred cover colours that fade into the page background.
struct ColorBleed: View {
    let palette: CoverPalette

    var body: some View {
        LinearGradient(
            colors: [Color(palette.colors[0]), Color(palette.colors[1]), Color(palette.colors[2]).opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blur(radius: 40)
        .opacity(0.75)
        .mask {
            LinearGradient(colors: [.black, .black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
        }
        .frame(height: 520)
        .padding(.top, -200)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
