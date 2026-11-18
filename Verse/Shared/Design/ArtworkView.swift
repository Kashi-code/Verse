import SwiftUI

/// Square (or circular) remote artwork with a neutral placeholder and a short fade-in.
struct ArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = DS.Radius.control
    /// Points; the image is decoded at this size times the screen scale.
    var size: CGFloat = 160
    var isCircle = false

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    private var pixelSize: Int { Int(size * displayScale) }

    var body: some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                ZStack {
                    Rectangle().fill(DS.Fill.standard)
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        GeometryReader { proxy in
                            Image(systemName: isCircle ? "person.fill" : "music.note")
                                .font(.system(size: proxy.size.width * 0.32))
                                .foregroundStyle(DS.Text.tertiary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
            }
            .clipShape(isCircle ? AnyShape(Circle()) : AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)))
            .task(id: url) { await load() }
            .accessibilityHidden(true)
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }
        if let cached = ImageLoader.shared.cachedImage(for: url, pixelSize: pixelSize) {
            image = cached
            return
        }
        image = nil
        let loaded = await ImageLoader.shared.image(for: url, pixelSize: pixelSize)
        withAnimation(DS.Motion.fade) { image = loaded }
    }
}
