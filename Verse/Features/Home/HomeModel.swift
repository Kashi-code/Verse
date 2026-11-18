import Foundation
import Observation

@MainActor
@Observable
final class HomeModel {
    enum State: Equatable {
        case loading
        case loaded(HomeFeed)
        case failed
    }

    private(set) var state: State = .loading

    /// Loads once; `force` reloads (pull to refresh) while keeping what is on screen.
    func load(using catalog: any CatalogService, force: Bool = false) async {
        if case .loaded = state, !force { return }
        do {
            state = .loaded(try await catalog.homeFeed())
        } catch {
            if case .loaded = state { return }
            state = .failed
        }
    }

    static func greeting(at date: Date = .now, calendar: Calendar = .current) -> String {
        switch calendar.component(.hour, from: date) {
        case 5..<12: String(localized: "Good morning")
        case 12..<18: String(localized: "Good afternoon")
        default: String(localized: "Good evening")
        }
    }
}
