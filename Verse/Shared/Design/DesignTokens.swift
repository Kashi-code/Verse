import SwiftUI

/// Design tokens. Views use these instead of raw numbers and colours.
enum DS {
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 12
        static let panel: CGFloat = 20
        static let sheet: CGFloat = 28
    }

    /// Translucent fill levels, drawn in the foreground colour so they work in light and dark mode.
    enum Fill {
        static let subtle = Color.primary.opacity(0.05)
        static let standard = Color.primary.opacity(0.09)
        static let hover = Color.primary.opacity(0.13)
        static let pressed = Color.primary.opacity(0.18)
    }

    enum Text {
        static let primary = Color.primary
        static let secondary = Color.primary.opacity(0.68)
        static let tertiary = Color.primary.opacity(0.45)
    }

    enum Border {
        static let hairline: CGFloat = 0.5
        static let color = Color.white.opacity(0.22)
    }

    enum Shadow {
        static let color = Color.black.opacity(0.18)
        static let radius: CGFloat = 18
        static let y: CGFloat = 8
    }

    enum Motion {
        /// Taps and small state changes.
        static let snappy = Animation.snappy(duration: 0.25)
        /// Layout and screen transitions.
        static let smooth = Animation.smooth(duration: 0.45)
        static let fade = Animation.easeInOut(duration: 0.2)
    }

    enum Size {
        static let rowArtwork: CGFloat = 48
        static let cardArtwork: CGFloat = 156
        static let heroArtwork: CGFloat = 280
        static let artistAvatar: CGFloat = 112
        static let miniPlayerArtwork: CGFloat = 40
    }

    enum Typography {
        static let pageTitle = Font.largeTitle.weight(.heavy)
        static let sectionTitle = Font.title2.weight(.bold)
        static let rowTitle = Font.body.weight(.semibold)
        static let rowSubtitle = Font.subheadline
        static let caption = Font.caption.weight(.semibold)
    }
}
