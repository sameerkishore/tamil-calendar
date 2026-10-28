import AppKit
import ImageIO
import SwiftUI

/// One of the user's board pictures, with its own framing in the arch.
struct BoardPhoto: Codable, Equatable, Identifiable {
    var id = UUID()
    /// File name inside `BoardSlideshow.directory`.
    var file: String
    var crop = PhotoCrop()

    var url: URL { BoardSlideshow.directory.appendingPathComponent(file) }
}

/// When the board picture moves on by itself.
enum PictureChange: String, Codable, CaseIterable {
    case never
    case eachWake
    case quarterHour
    case hourly
    case threeHours
    case daily

    var title: String {
        switch self {
        case .never: "Never"
        case .eachWake: "Each time the Mac wakes"
        case .quarterHour: "Every 15 minutes"
        case .hourly: "Every hour"
        case .threeHours: "Every 3 hours"
        case .daily: "Every day"
        }
    }

    var interval: TimeInterval? {
        switch self {
        case .never, .eachWake: nil
        case .quarterHour: 15 * 60
        case .hourly: 60 * 60
        case .threeHours: 3 * 60 * 60
        case .daily: 24 * 60 * 60
        }
    }
}

/// The pictures on the Your Own Picture board. "Each time the Mac wakes" swaps while the display
/// is asleep or the screen locked, so the new picture is simply there when you come back; timed
/// changes and the shortcut crossfade in view.
@MainActor
final class BoardSlideshow {
    nonisolated static let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("RasiPalan/board-photos", isDirectory: true)

    private let store: StateStore
    private let model: PadModel
    /// "Each time the Mac wakes" changes once per sleep, however many sleep notifications come.
    private var changedWhileAway = false
    /// Shuffle goes through every picture once before any repeats; the next one is last.
    private var shuffleBag: [UUID] = []
    private var preloaded: (id: UUID, image: NSImage)?
    private var timer: Timer?

    init(store: StateStore, model: PadModel) {
        self.store = store
        self.model = model
        migrateSinglePicture()
        if !photos.indices.contains(store.state.boardPhotoIndex) { store.state.boardPhotoIndex = 0 }
        publish()
        if let current { display(current, image: Self.image(at: current.url), animated: false) }
    }

    private var photos: [BoardPhoto] { store.state.boardPhotos }
    var current: BoardPhoto? { photos.indices.contains(store.state.boardPhotoIndex) ? photos[store.state.boardPhotoIndex] : nil }

    func start() {
        // Launching (often at login) is a natural moment for a fresh picture, before the pad shows.
        if store.state.pictureChange == .eachWake { next(animated: false) }
        changeIfDue(animated: false)
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.changeIfDue(animated: true) }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.wentAway() }
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cameBack() }
            }
        }
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.wentAway() }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.cameBack() }
        }
    }

    // MARK: - Changing the picture

    /// Moves on to the next picture: a soft crossfade when asked for in view, instant otherwise.
    func next(animated: Bool) {
        guard photos.count > 1, let id = upcomingID() else { return }
        if store.state.pictureShuffle { shuffleBag.removeLast() }
        show(id, animated: animated)
    }

    func show(_ id: UUID, animated: Bool) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let photo = photos[index]
        let image = preloaded?.id == id ? preloaded!.image : Self.image(at: photo.url)
        store.state.boardPhotoIndex = index
        store.state.pictureChangedAt = Date()
        store.save()
        model.boardPhotoID = id
        display(photo, image: image, animated: animated)
    }

    private func display(_ photo: BoardPhoto, image: NSImage?, animated: Bool) {
        let apply = { [model] in
            model.boardImage = image
            model.boardCrop = photo.crop
        }
        if animated { withAnimation(.easeInOut(duration: 0.8), apply) } else { apply() }
        preloadUpcoming()
    }

    /// Timed changes: checked every minute, and on going to sleep so one that falls due overnight
    /// is already made when you're back.
    private func changeIfDue(animated: Bool) {
        guard let interval = store.state.pictureChange.interval,
              Date().timeIntervalSince(store.state.pictureChangedAt ?? .distantPast) >= interval else { return }
        next(animated: animated)
    }

    private func wentAway() {
        if store.state.pictureChange == .eachWake && !changedWhileAway {
            changedWhileAway = true
            next(animated: false)
        }
        changeIfDue(animated: false)
    }

    private func cameBack() { changedWhileAway = false }

    private func upcomingID() -> UUID? {
        guard photos.count > 1, let current else { return nil }
        guard store.state.pictureShuffle else {
            return photos[(store.state.boardPhotoIndex + 1) % photos.count].id
        }
        shuffleBag.removeAll { id in !photos.contains { $0.id == id } || id == current.id }
        if shuffleBag.isEmpty { shuffleBag = photos.map(\.id).filter { $0 != current.id }.shuffled() }
        return shuffleBag.last
    }

    /// Decodes the next picture ahead of time, so a change never waits on a big photo.
    private func preloadUpcoming() {
        guard let id = upcomingID(), preloaded?.id != id, let url = photos.first(where: { $0.id == id })?.url else { return }
        Task {
            let decoded = await Task.detached(priority: .utility) { Self.decode(url) }.value
            guard let decoded else { return }
            preloaded = (id, NSImage(cgImage: decoded.image, size: decoded.size))
        }
    }

    // MARK: - Editing the list

    /// Asks for pictures and adds them to the end. Returns how many were added.
    @discardableResult
    func addPictures() -> Int {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = true
        panel.message = "Choose pictures for the calendar board, e.g. your family deity or favourite photos."
        NSApp.activate()
        guard panel.runModal() == .OK else { return 0 }
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        let wasEmpty = photos.isEmpty
        var added = 0
        for url in panel.urls {
            let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
            let file = UUID().uuidString + "." + ext
            do {
                try FileManager.default.copyItem(at: url, to: Self.directory.appendingPathComponent(file))
            } catch {
                NSLog("RasiPalan: couldn't copy board picture: \(error)")
                continue
            }
            store.state.boardPhotos.append(BoardPhoto(file: file))
            added += 1
        }
        store.save()
        publish()
        if wasEmpty, let first = photos.first { show(first.id, animated: false) } else { preloadUpcoming() }
        return added
    }

    func remove(_ id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        let wasCurrent = index == store.state.boardPhotoIndex
        try? FileManager.default.removeItem(at: photos[index].url)
        store.state.boardPhotos.remove(at: index)
        if index < store.state.boardPhotoIndex { store.state.boardPhotoIndex -= 1 }
        if store.state.boardPhotoIndex >= photos.count { store.state.boardPhotoIndex = 0 }
        store.save()
        publish()
        if wasCurrent {
            if let current { show(current.id, animated: true) } else {
                model.boardImage = nil
                model.boardPhotoID = nil
            }
        } else {
            preloadUpcoming()
        }
    }

    /// Puts the picture at `destination` in the slideshow order.
    func move(_ id: UUID, to destination: Int) {
        guard let from = photos.firstIndex(where: { $0.id == id }) else { return }
        let currentID = current?.id
        let photo = store.state.boardPhotos.remove(at: from)
        store.state.boardPhotos.insert(photo, at: min(max(destination, 0), photos.count))
        store.state.boardPhotoIndex = photos.firstIndex { $0.id == currentID } ?? 0
        store.save()
        publish()
        preloadUpcoming()
    }

    /// A picture's framing, from the Adjust Picture window (which may outlive a change).
    func setCrop(_ crop: PhotoCrop, for id: UUID) {
        guard let index = photos.firstIndex(where: { $0.id == id }) else { return }
        store.state.boardPhotos[index].crop = crop
        store.save()
        if id == current?.id { model.boardCrop = crop }
        model.boardPhotos = photos
    }

    func setChange(_ change: PictureChange) {
        store.state.pictureChange = change
        // Count from now, not from whenever the picture last changed.
        store.state.pictureChangedAt = Date()
        store.save()
        model.pictureChange = change
    }

    func setShuffle(_ on: Bool) {
        store.state.pictureShuffle = on
        store.save()
        model.pictureShuffle = on
        shuffleBag = []
        preloaded = nil
        preloadUpcoming()
    }

    private func publish() {
        model.boardPhotos = photos
        model.boardPhotoID = current?.id
        model.pictureChange = store.state.pictureChange
        model.pictureShuffle = store.state.pictureShuffle
    }

    /// The one board picture from before slideshows becomes the first of the list.
    private func migrateSinglePicture() {
        guard photos.isEmpty, let path = store.state.boardImagePath else { return }
        let old = URL(fileURLWithPath: path)
        let file = UUID().uuidString + "." + (old.pathExtension.isEmpty ? "png" : old.pathExtension)
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: old, to: Self.directory.appendingPathComponent(file))
        } catch {
            NSLog("RasiPalan: couldn't move the board picture: \(error)")
            return
        }
        store.state.boardPhotos = [BoardPhoto(file: file, crop: store.state.boardCrop)]
        store.state.boardPhotoIndex = 0
        store.state.boardImagePath = nil
        store.save()
    }

    // MARK: - Decoding

    private struct Decoded: @unchecked Sendable {
        let image: CGImage
        var size: NSSize { NSSize(width: image.width, height: image.height) }
    }

    /// Large enough for the arch at the biggest pad size on a Retina screen.
    nonisolated private static let boardPixels = 2000

    private static func image(at url: URL) -> NSImage? {
        decode(url).map { NSImage(cgImage: $0.image, size: $0.size) }
    }

    /// Downsampled and upright, so a 48-megapixel photo doesn't sit in memory at full size.
    nonisolated private static func decode(_ url: URL, maxPixels: Int = boardPixels) -> Decoded? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(Decoded.init)
    }

    /// A small copy for the list of pictures in Templates & Board.
    nonisolated static func thumbnail(_ url: URL) async -> NSImage? {
        let decoded = await Task.detached(priority: .utility) { decode(url, maxPixels: 240) }.value
        return decoded.map { NSImage(cgImage: $0.image, size: $0.size) }
    }
}
