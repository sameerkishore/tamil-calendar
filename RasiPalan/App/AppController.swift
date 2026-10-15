import AppKit
import Observation
import RasiCore
import ServiceManagement

/// What the pad is currently showing. Views observe this; only `AppController` writes it.
@MainActor
@Observable
final class PadModel {
    var context: DayContext
    /// Tomorrow's sheet, faintly visible through the paper.
    var nextContext: DayContext
    var layout: CardLayout
    var language: CardLanguage
    var scale: CGFloat
    /// The top sheet is off being torn; the pad shows the next day on top.
    var isTearing = false
    var perforations = TearPhysics.defaults.holes
    /// The printed board the pad hangs on, if any.
    var board: BoardStyle = .none
    var boardImage: NSImage?
    var boardCrop = PhotoCrop()
    /// The pad (and torn sheets, balls, bin) float above all windows instead of the desktop.
    var keepOnTop = false

    func theme(scale: CGFloat? = nil) -> CardTheme {
        CardTheme(scale: scale ?? self.scale, language: language, perforations: perforations, paper: layout.paper)
    }

    init(context: DayContext, layout: CardLayout = .classic, language: CardLanguage = .tamilEnglish, scale: CGFloat = 1) {
        self.context = context
        nextContext = context.next()
        self.layout = layout
        self.language = language
        self.scale = scale
    }
}

extension DayContext {
    func next() -> DayContext {
        DayContext(day: day.adding(days: 1), location: location, style: style)
    }
}

/// Owns the app's state and services, and recomputes the sheet whenever any input changes
/// (pad date, location, panchangam style).
@MainActor
final class AppController {
    let store: StateStore
    let model: PadModel
    private let locationService = LocationService()
    private var pad: PadWindowController?
    private var menuBar: MenuBarController?
    private var cityPicker: CityPickerWindowController?
    private let tear = TearController()
    private var floatingSheets: FloatingSheetsController?
    private var paperBalls: PaperBallsController?
    private var trashBin: TrashBinController?
    private var physicsSettings: PhysicsSettingsWindowController?
    private var gallery: TemplateGalleryWindowController?
    private var photoCrop: PhotoCropWindowController?
    private var settings: SettingsWindowController?
    private let frontHotKey = HotKey()

    /// Only move the saved location if the user has really travelled.
    private static let relocationThresholdKm = 25.0

    init(store: StateStore) {
        self.store = store
        if store.state.location == nil {
            // Something sensible to show while Core Location answers (or if it never does).
            store.state.location = .fallback(for: .current)
            store.state.locationSource = .timeZone
            store.save()
        }
        model = PadModel(context: Self.context(for: store.state), language: store.state.language,
                         scale: store.state.padScale)
        model.perforations = store.state.physics.holes
        model.layout = CardLayout.bundled[store.state.layoutID] ?? .classic
        model.board = store.state.board
        model.boardImage = store.state.boardImagePath.flatMap(NSImage.init(contentsOfFile:))
        model.boardCrop = store.state.boardCrop
        model.keepOnTop = store.state.keepOnTop
    }

    func start() {
        SoundPlayer.shared.isEnabled = state.soundEnabled
        registerFrontShortcut()
        let pad = PadWindowController(store: store, model: model)
        self.pad = pad
        menuBar = MenuBarController(app: self, pad: pad)
        pad.show()

        let bin = TrashBinController(store: store, scale: model.scale, sprites: BallSprites.make(model: model))
        bin.onEmptied = { [weak self] in self?.updateBinVisibility() }
        bin.onClearDesktop = { [weak self] in self?.clearDesktop() }
        pad.onScaleChanged = { [weak bin] s in bin?.setScale(s) }
        trashBin = bin

        let balls = PaperBallsController(store: store, model: model)
        balls.level = { pad.level }
        balls.bin = { [weak bin] in bin?.target }
        balls.onBinned = { [weak bin] in bin?.accept() }
        balls.onCountChanged = { [weak self] in self?.updateBinVisibility() }
        balls.restore()
        paperBalls = balls
        updateBinVisibility()

        let sheets = FloatingSheetsController(store: store, model: model)
        sheets.onCrumpled = { [weak self] sheet, _ in
            self?.paperBalls?.add(PaperBallRecord(sheet: sheet))
        }
        sheets.restore(level: pad.level)
        floatingSheets = sheets

        pad.onTearBegan = { [weak self] point in
            guard let self else { return }
            tear.begin(at: point, sheetRect: pad.sheetScreenRect, context: model.context, layout: model.layout,
                       theme: model.theme(), level: pad.level)
        }
        pad.onTearMoved = { [weak self] point, time in self?.tear.move(to: point, time: time) }
        pad.onTearEnded = { [weak self] point, time in self?.tear.end(at: point, time: time) }
        tear.physics = { [weak self] in self?.state.physics ?? .defaults }
        tear.onLift = { [weak self] in self?.model.isTearing = true }
        tear.onSettle = { [weak self] in self?.model.isTearing = false }
        tear.onTornOff = { [weak self] in self?.advancePad() }
        tear.onDrop = { [weak self] sheet in
            guard let self, let pad = self.pad else { return }
            floatingSheets?.add(sheet, level: pad.level)
        }
        updateAutomaticLocation()

        NotificationCenter.default.addObserver(forName: .NSSystemTimeZoneDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.timeZoneChanged() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.bringEverythingOnScreen() }
        }
        bringEverythingOnScreen()
    }

    var state: AppState { store.state }

    private static func context(for state: AppState) -> DayContext {
        DayContext(day: state.padDay, location: state.location ?? .fallback(for: .current), style: state.style)
    }

    private func commit() {
        store.save()
        model.context = Self.context(for: store.state)
        model.nextContext = model.context.next()
        model.language = store.state.language
    }

    // MARK: - Location

    func useAutomaticLocation() {
        store.state.locationSource = .timeZone   // anything but .manual, so the next fix is accepted
        commit()
        updateAutomaticLocation(force: true)
    }

    func setManualLocation(_ location: GeoLocation) {
        store.state.location = location
        store.state.locationSource = .manual
        commit()
    }

    func chooseCity() {
        if cityPicker == nil {
            cityPicker = CityPickerWindowController(
                search: { [locationService] query in await locationService.search(query) },
                choose: { [weak self] location in
                    self?.setManualLocation(location)
                    self?.cityPicker?.close()
                })
        }
        cityPicker?.show()
    }

    private func updateAutomaticLocation(force: Bool = false) {
        guard state.locationSource != .manual else { return }
        locationService.requestLocation { [weak self] found in
            guard let self, self.state.locationSource != .manual else { return }
            if let found {
                let moved = self.state.location.map { $0.distance(to: found) > Self.relocationThresholdKm } ?? true
                if force || moved || self.state.locationSource != .automatic {
                    self.store.state.location = found
                    self.store.state.locationSource = .automatic
                    self.commit()
                }
            } else if self.state.locationSource == .timeZone {
                self.store.state.location = .fallback(for: .current)
                self.commit()
            }
        }
    }

    private func timeZoneChanged() {
        if state.locationSource == .timeZone {
            store.state.location = .fallback(for: .current)
            commit()
        }
        updateAutomaticLocation()
    }

    // MARK: - Settings

    func showSettings() {
        if settings == nil { settings = SettingsWindowController(app: self) }
        settings?.show()
    }

    func setPadScale(_ scale: CGFloat) { pad?.setScale(scale) }

    // MARK: - Open at login

    var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setOpensAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            let alert = NSAlert()
            alert.messageText = on ? "Couldn't turn on Open at Login" : "Couldn't turn off Open at Login"
            alert.informativeText = "\(error.localizedDescription)\n\nTip: install the app with scripts/install.sh so it lives in Applications."
            NSApp.activate()
            alert.runModal()
        }
    }

    func showGallery() {
        if gallery == nil {
            gallery = TemplateGalleryWindowController(
                model: model,
                chooseLayout: { [weak self] in self?.setLayout($0) },
                chooseBoard: { [weak self] in self?.setBoard($0) },
                choosePicture: { [weak self] in self?.chooseBoardImage() },
                adjustPicture: { [weak self] in self?.adjustBoardImage() })
        }
        gallery?.show()
    }

    func setLayout(_ id: String) {
        guard let layout = CardLayout.bundled[id] else { return }
        store.state.layoutID = id
        store.save()
        model.layout = layout
    }

    func setBoard(_ board: BoardStyle) {
        if board == .custom && model.boardImage == nil {
            chooseBoardImage()
            return
        }
        store.state.board = board
        store.save()
        model.board = board
        pad?.boardChanged()
    }

    /// Lets the user pick a picture for the board; copies it into Application Support.
    func chooseBoardImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.message = "Choose a picture for the calendar board, e.g. your family deity or a favourite photo."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RasiPalan", isDirectory: true)
        let dest = dir.appendingPathComponent("board-image." + (url.pathExtension.isEmpty ? "png" : url.pathExtension))
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: url, to: dest)
        } catch {
            NSLog("RasiPalan: couldn't copy board image: \(error)")
            return
        }
        store.state.boardImagePath = dest.path
        store.state.boardCrop = PhotoCrop()
        model.boardImage = image
        model.boardCrop = PhotoCrop()
        setBoard(.custom)
        adjustBoardImage()
    }

    /// Opens the crop window for the board picture; changes apply live.
    func adjustBoardImage() {
        guard let image = model.boardImage else { return chooseBoardImage() }
        photoCrop = PhotoCropWindowController(image: image, crop: store.state.boardCrop) { [weak self] crop in
            guard let self else { return }
            model.boardCrop = crop
            store.state.boardCrop = crop
            store.save()
        }
        photoCrop?.show()
    }

    func setLanguage(_ language: CardLanguage) {
        store.state.language = language
        commit()
    }

    func setStyle(_ style: PanchangamStyle) {
        store.state.style = style
        commit()
    }

    /// A sheet came off: the pad moves on to the next day.
    private func advancePad() {
        store.state.padDay = store.state.padDay.adding(days: 1)
        model.isTearing = false
        commit()
    }

    /// Brings the calendar in front of every window, or sends it back to the desktop.
    func toggleInFront() {
        setKeepOnTop(!state.keepOnTop)
    }

    func setFrontShortcut(_ shortcut: FrontShortcut) {
        store.state.frontShortcut = shortcut
        store.save()
        registerFrontShortcut()
    }

    private func registerFrontShortcut() {
        frontHotKey.register(state.frontShortcut) { [weak self] in self?.toggleInFront() }
    }

    func resetPadPosition() { pad?.resetPosition() }

    func setKeepOnTop(_ on: Bool) {
        store.state.keepOnTop = on
        model.keepOnTop = on
        store.save()
        pad?.applyLevel()
        if let pad {
            floatingSheets?.setLevel(pad.level)
            paperBalls?.setLevel(pad.level)
            trashBin?.setLevel(pad.level)
        }
    }

    func showPhysicsSettings() {
        if physicsSettings == nil {
            physicsSettings = PhysicsSettingsWindowController(physics: state.physics) { [weak self] physics in
                guard let self else { return }
                store.state.physics = physics
                store.save()
                model.perforations = physics.holes
            }
        }
        physicsSettings?.show()
    }

    private func bringEverythingOnScreen() {
        floatingSheets?.bringOnScreen()
        paperBalls?.bringOnScreen()
        trashBin?.bringOnScreen()
    }

    /// Sweeps away every torn sheet and paper ball lying around (the bin keeps what's in it).
    func clearDesktop() {
        floatingSheets?.removeAll()
        paperBalls?.removeAll()
        SoundPlayer.shared.play("rustle", volume: 0.8)
    }

    /// The bin is out while there are paper balls about or it has something in it.
    private func updateBinVisibility() {
        guard let bin = trashBin, let pad, let balls = paperBalls else { return }
        if !balls.isEmpty || bin.model.count > 0 {
            bin.show(level: pad.level)
        } else {
            bin.hide()
        }
    }

    func setSoundEnabled(_ on: Bool) {
        store.state.soundEnabled = on
        store.save()
        SoundPlayer.shared.isEnabled = on
    }

    /// Debug: browse dates without tearing.
    func shiftPadDay(by days: Int) {
        store.state.padDay = store.state.padDay.adding(days: days)
        commit()
    }

    func resetPadDayToToday() {
        store.state.padDay = .today()
        commit()
    }
}
