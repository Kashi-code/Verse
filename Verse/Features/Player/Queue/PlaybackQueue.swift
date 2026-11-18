import Foundation

/// The play queue, shared by local files and Apple Music.
///
/// `items` is always in play order. While shuffled, `unshuffledItems` keeps the original order so
/// shuffle can be turned off again. Shuffling only reorders what hasn't played yet, and repeat-all
/// reshuffles a full cycle, so no song repeats before every song has played.
struct PlaybackQueue: Codable, Sendable, Equatable {
    private(set) var items: [QueueItem] = []
    private(set) var currentIndex: Int?
    private(set) var unshuffledItems: [QueueItem]?
    private(set) var source: QueueSource?
    var repeatMode: RepeatMode = .off

    var isEmpty: Bool { items.isEmpty }
    var isShuffled: Bool { unshuffledItems != nil }
    var current: QueueItem? { currentIndex.map { items[$0] } }

    var upNext: [QueueItem] {
        guard let currentIndex else { return [] }
        return Array(items[(currentIndex + 1)...])
    }

    // MARK: Replacing

    /// Replaces the queue. With `shuffled`, the start item plays first (a random one if `index` is nil).
    mutating func replace(
        with tracks: [TrackInfo],
        startAt index: Int?,
        source: QueueSource?,
        shuffled: Bool,
        using rng: inout some RandomNumberGenerator
    ) {
        let newItems = tracks.map { QueueItem(track: $0) }
        self.source = source
        unshuffledItems = nil
        items = newItems
        guard !newItems.isEmpty else {
            currentIndex = nil
            return
        }

        let start: Int
        if let index {
            start = min(max(index, 0), newItems.count - 1)
        } else if shuffled {
            start = Int.random(in: newItems.indices, using: &rng)
        } else {
            start = 0
        }

        if shuffled {
            var others = newItems
            let first = others.remove(at: start)
            others.shuffle(using: &rng)
            unshuffledItems = newItems
            items = [first] + others
            currentIndex = 0
        } else {
            currentIndex = start
        }
    }

    // MARK: Shuffle

    mutating func setShuffled(_ shuffled: Bool, using rng: inout some RandomNumberGenerator) {
        guard shuffled != isShuffled else { return }
        if shuffled {
            unshuffledItems = items
            guard let currentIndex else {
                items.shuffle(using: &rng)
                return
            }
            var upcoming = Array(items[(currentIndex + 1)...])
            upcoming.shuffle(using: &rng)
            items.replaceSubrange((currentIndex + 1)..., with: upcoming)
        } else if let original = unshuffledItems {
            let currentID = current?.id
            items = original
            unshuffledItems = nil
            currentIndex = currentID.flatMap { id in items.firstIndex { $0.id == id } } ?? (items.isEmpty ? nil : 0)
        }
    }

    // MARK: Moving through the queue

    /// Moves to the next item and returns it, or returns nil at the end of the queue.
    /// Repeat-one only applies when the song ends by itself, not when the user skips.
    @discardableResult
    mutating func advance(userInitiated: Bool, using rng: inout some RandomNumberGenerator) -> QueueItem? {
        guard let currentIndex else { return nil }
        if repeatMode == .one && !userInitiated {
            return items[currentIndex]
        }
        if currentIndex + 1 < items.count {
            self.currentIndex = currentIndex + 1
            return items[currentIndex + 1]
        }
        guard repeatMode != .off else { return nil }

        if isShuffled && items.count > 1 {
            let justPlayed = items[currentIndex].id
            items.shuffle(using: &rng)
            if items[0].id == justPlayed {
                items.swapAt(0, items.count - 1)
            }
        }
        self.currentIndex = 0
        return items[0]
    }

    /// Moves to the previous item. Returns true if the current item changed.
    @discardableResult
    mutating func goBack() -> Bool {
        guard let currentIndex else { return false }
        if currentIndex > 0 {
            self.currentIndex = currentIndex - 1
            return true
        }
        if repeatMode == .all && items.count > 1 {
            self.currentIndex = items.count - 1
            return true
        }
        return false
    }

    @discardableResult
    mutating func jump(to id: QueueItem.ID) -> QueueItem? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        currentIndex = index
        return items[index]
    }

    // MARK: Editing

    /// Inserts tracks right after the current item.
    mutating func insertNext(_ tracks: [TrackInfo]) {
        let newItems = tracks.map { QueueItem(track: $0) }
        guard !newItems.isEmpty else { return }
        guard let currentIndex else {
            append(newItems)
            return
        }
        let currentID = items[currentIndex].id
        items.insert(contentsOf: newItems, at: currentIndex + 1)
        if var original = unshuffledItems {
            let position = original.firstIndex { $0.id == currentID }.map { $0 + 1 } ?? original.endIndex
            original.insert(contentsOf: newItems, at: position)
            unshuffledItems = original
        }
    }

    /// Adds tracks to the end of the queue.
    mutating func append(_ tracks: [TrackInfo]) {
        append(tracks.map { QueueItem(track: $0) })
    }

    private mutating func append(_ newItems: [QueueItem]) {
        guard !newItems.isEmpty else { return }
        items.append(contentsOf: newItems)
        unshuffledItems?.append(contentsOf: newItems)
        if currentIndex == nil {
            currentIndex = 0
        }
    }

    mutating func removeFromUpNext(_ id: QueueItem.ID) {
        guard let currentIndex,
              let index = items.firstIndex(where: { $0.id == id }),
              index > currentIndex else { return }
        items.remove(at: index)
        unshuffledItems?.removeAll { $0.id == id }
    }

    /// Reorders "Up Next". Offsets are positions within `upNext`, as given by `List.onMove`.
    mutating func moveUpNext(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard let currentIndex else { return }
        var upcoming = upNext
        let valid = offsets.filter { upcoming.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.map { upcoming[$0] }
        for offset in valid.sorted(by: >) {
            upcoming.remove(at: offset)
        }
        let target = min(max(destination - valid.filter { $0 < destination }.count, 0), upcoming.count)
        upcoming.insert(contentsOf: moving, at: target)
        items.replaceSubrange((currentIndex + 1)..., with: upcoming)
    }

    mutating func clearUpNext() {
        guard let currentIndex else { return }
        let removed = Set(items[(currentIndex + 1)...].map(\.id))
        items.removeSubrange((currentIndex + 1)...)
        unshuffledItems?.removeAll { removed.contains($0.id) }
    }
}

extension PlaybackQueue {
    mutating func replace(with tracks: [TrackInfo], startAt index: Int?, source: QueueSource?, shuffled: Bool) {
        var rng = SystemRandomNumberGenerator()
        replace(with: tracks, startAt: index, source: source, shuffled: shuffled, using: &rng)
    }

    mutating func setShuffled(_ shuffled: Bool) {
        var rng = SystemRandomNumberGenerator()
        setShuffled(shuffled, using: &rng)
    }

    @discardableResult
    mutating func advance(userInitiated: Bool) -> QueueItem? {
        var rng = SystemRandomNumberGenerator()
        return advance(userInitiated: userInitiated, using: &rng)
    }
}
