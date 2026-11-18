import SwiftUI

/// Square cover art with a neutral placeholder.
struct ArtworkView: View {
    let key: String?
    var cornerRadius: CGFloat = 8

    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay { content }
            .clipShape(.rect(cornerRadius: cornerRadius))
            .task(id: key) { await load() }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    GeometryReader { proxy in
                        Image(systemName: "music.note")
                            .font(.system(size: proxy.size.width * 0.35))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
        }
    }

    private func load() async {
        guard let key else {
            image = nil
            return
        }
        if let cached = ArtworkImageLoader.shared.cachedImage(for: key) {
            image = cached
            return
        }
        image = nil
        image = await ArtworkImageLoader.shared.image(for: key)
    }
}
