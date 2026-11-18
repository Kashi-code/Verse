import Foundation

enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum LyricsTextSize: String, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    /// Multiplier applied on top of the Dynamic Type size.
    var scale: Double {
        switch self {
        case .small: 0.85
        case .medium: 1.0
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }
}

enum LaunchBehavior: String, CaseIterable, Identifiable, Sendable {
    case resume, startFresh

    var id: Self { self }

    var title: LocalizedStringResource {
        switch self {
        case .resume: "Resume Last Queue"
        case .startFresh: "Start Fresh"
        }
    }
}
