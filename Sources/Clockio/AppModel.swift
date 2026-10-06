import AppKit
import ClockioCore
import Combine
import CoreGraphics
import EventKit
import Foundation
import ServiceManagement
import SwiftUI
import UniformTypeIdentifiers

enum WorkspaceMode: String, CaseIterable, Identifiable {
    case gallery
    case todo
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gallery: "Gallery"
        case .todo: "To-Do"
        case .settings: "Settings"
        }
    }

    static var sidebarModes: [WorkspaceMode] {
        [.gallery, .todo]
    }
}

/// UI-facing state of the calendar integration.
enum CalendarDisplayStatus {
    case off       // disabled in settings
    case active    // access granted, events loaded
    case denied    // user turned it on but declined the system permission prompt
}

/// Borderless windows return `false` from `canBecomeKey`/`canBecomeMain` by default,
/// so key events never reach the local monitor and keyboard dismissal silently fails.
/// Opting in lets the screensaver be dismissed with any key press.
final class ScreensaverWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class ClockioAppModel: ObservableObject {
    @Published var settings: ClockioSettings {
        didSet {
            guard settings != oldValue else { return }
            // Persist on a short debounce so dragging the slider / colour picker (which fire
            // dozens of mutations per second) doesn't thrash the disk on every frame.
            scheduleSettingsSave()
            // Run each side-effect only when its own input changed — these used to run on
            // every mutation (XPC status calls, timer rebuilds, menu rebuilds per frame).
            if settings.hideDock != oldValue.hideDock { applyDockPolicy() }
            if settings.launchAtLogin != oldValue.launchAtLogin { syncLaunchAtLogin() }
            if settings.autoDayNightMode != oldValue.autoDayNightMode {
                scheduleAppearanceWatcher()
                // Auto day/night now needs the location-based solar schedule.
                scheduleConditionsRefresh()
            }
            if settings.autoStartScreensaver != oldValue.autoStartScreensaver
                || settings.idleMinutes != oldValue.idleMinutes {
                scheduleIdleWatcher()
            }
            if settings.showTemperature != oldValue.showTemperature { scheduleConditionsRefresh() }
            if settings.showCalendarEvents != oldValue.showCalendarEvents { handleCalendarToggle() }
            // Keep the cached rendered background in sync without recomputing it on every frame.
            if settings.backgroundId != oldValue.backgroundId
                || settings.paletteOverrides != oldValue.paletteOverrides
                || settings.customBackgroundPath != oldValue.customBackgroundPath
                || settings.customBackgroundName != oldValue.customBackgroundName {
                recomputeBackgrounds()
            }
            if settings.affectsStatusMenu(comparedTo: oldValue) { onSettingsChanged?() }
        }
    }

    @Published private(set) var todos: [TodoItem] {
        didSet {
            guard todos != oldValue else { return }
            scheduleTodosSave()
        }
    }

    @Published var mode: WorkspaceMode = .gallery
    @Published private(set) var screensaverRunning = false
    @Published private(set) var screensaverGreeting: String?
    @Published private(set) var isNightModeActive: Bool
    /// Location-based sunrise/sunset for today. `nil` until the first successful fetch, in which
    /// case automatic day/night falls back to a fixed evening schedule.
    @Published private(set) var solarSchedule: SolarSchedule?
    @Published private(set) var temperatureStatus = "Using last saved temperature"
    @Published private(set) var systemStatusMessage: String?
    @Published private(set) var calendarEvents: [CalendarEvent] = []
    @Published private(set) var calendarStatus: CalendarDisplayStatus = .off

    // Cached so the render path (which re-reads these on every screensaver frame) never has to
    // rebuild the preset catalogue or stat the filesystem. Recomputed only when an input changes.
    @Published private(set) var currentBackground: ClockBackground
    @Published private(set) var renderedBackground: ClockBackground

    let persistence: ClockioPersistence
    var onSettingsChanged: (() -> Void)?
    private let weatherProvider = DeviceWeatherProvider()
    private let calendarProvider = CalendarProvider()
    private var calendarChangeObserver: NSObjectProtocol?
    private var dayChangeObserver: NSObjectProtocol?
    private var idleTimer: Timer?
    private var appearanceTimer: Timer?
    private var weatherTimer: Timer?
    private var saveTimer: Timer?
    private var todoSaveTimer: Timer?
    private var screensaverWindows: [NSWindow] = []
    private var eventMonitor: Any?
    private var screenChangeObserver: NSObjectProtocol?

    init(persistence: ClockioPersistence = ClockioPersistence()) {
        self.persistence = persistence
        let loadedSettings = persistence.loadSettings()
        self.settings = loadedSettings
        self.todos = Self.orderedTodos(persistence.loadTodos())
        let night = NightMode.isActive(for: Date(), settings: loadedSettings, solar: nil)
        self.isNightModeActive = night
        let current = ClockioPresets.background(named: loadedSettings.backgroundId, settings: loadedSettings)
        self.currentBackground = current
        self.renderedBackground = current.applyingNightMode(night)
    }

    var availableBackgrounds: [ClockBackground] {
        ClockioPresets.availableBackgrounds(settings: settings)
    }

    private func recomputeBackgrounds() {
        currentBackground = ClockioPresets.background(named: settings.backgroundId, settings: settings)
        renderedBackground = currentBackground.applyingNightMode(isNightModeActive)
    }

    var appearanceStatusText: String {
        if settings.autoDayNightMode {
            isNightModeActive ? "Night" : "Day"
        } else {
            "Day locked"
        }
    }

    /// Human-readable description of the active day/night switch points for the settings panel.
    var appearanceScheduleText: String {
        guard let solar = solarSchedule else { return "Sunset to sunrise" }
        let formatter = Self.clockTimeFormatter
        return "↓ \(formatter.string(from: solar.sunset))  ↑ \(formatter.string(from: solar.sunrise))"
    }

    private static let clockTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var orderedTodos: [TodoItem] {
        Self.orderedTodos(todos)
    }

    var activeTodos: [TodoItem] {
        Self.dayPlanTodos(todos.filter { !$0.isDone })
    }

    var visibleTodos: [TodoItem] {
        Array(activeTodos.prefix(3))
    }

    var completedTodos: [TodoItem] {
        Self.orderedTodos(todos.filter(\.isDone))
    }

    var scheduledTodos: [TodoItem] {
        activeTodos.filter { Self.scheduledMinutes($0) != nil }
    }

    func start() {
        applyDockPolicy()
        syncLaunchAtLogin()
        scheduleAppearanceWatcher()
        scheduleIdleWatcher()
        scheduleConditionsRefresh()
        observeDayChanges()
        // Re-establish calendar access/observation if it was enabled in a previous session.
        if settings.showCalendarEvents { handleCalendarToggle() }
    }

    /// At midnight refresh anything that is scoped to "today": the calendar agenda (otherwise a
    /// screensaver left running overnight keeps yesterday's events) and the solar schedule (so the
    /// next day's sunrise/sunset drive day/night).
    private func observeDayChanges() {
        guard dayChangeObserver == nil else { return }
        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.refreshCalendarEvents()
                self.scheduleConditionsRefresh()
                self.updateAppearanceMode()
            }
        }
    }

    func setShowCalendarEvents(_ isOn: Bool) {
        settings.showCalendarEvents = isOn
    }

    func refreshCalendarEvents() {
        guard settings.showCalendarEvents else {
            calendarEvents = []
            return
        }
        guard calendarProvider.access == .granted else { return }
        calendarEvents = calendarProvider.todaysEvents()
        calendarStatus = .active
    }

    private func handleCalendarToggle() {
        guard settings.showCalendarEvents else {
            calendarChangeObserver.map(NotificationCenter.default.removeObserver)
            calendarChangeObserver = nil
            calendarEvents = []
            calendarStatus = .off
            return
        }

        Task { @MainActor in
            let granted = await calendarProvider.requestAccess()
            guard granted else {
                // Flip the toggle back off (this re-enters the off branch and resets status to
                // .off), *then* mark denied so the UI hint sticks and we don't keep retrying.
                settings.showCalendarEvents = false
                calendarStatus = .denied
                return
            }
            observeCalendarChanges()
            refreshCalendarEvents()
        }
    }

    private func observeCalendarChanges() {
        guard calendarChangeObserver == nil else { return }
        calendarChangeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshCalendarEvents()
            }
        }
    }

    func selectClockStyle(_ style: ClockStyle) {
        settings.clockStyle = style
    }

    func selectBackground(_ id: String) {
        guard availableBackgrounds.contains(where: { $0.id == id }) else { return }
        settings.backgroundId = id
    }

    func shuffleBackground() {
        let backgrounds = availableBackgrounds
        guard !backgrounds.isEmpty else { return }
        // A true shuffle: jump to a random background other than the current one (it used to
        // just advance to the next preset in order, which isn't what "Shuffle" implies).
        let candidates = backgrounds.filter { $0.id != settings.backgroundId }
        settings.backgroundId = (candidates.randomElement() ?? backgrounds[0]).id
    }

    func setMotion(_ value: Double) {
        settings.motion = min(100, max(8, value))
    }

    func setPaletteColor(backgroundId: String, index: Int, hex: String) {
        guard ClockioPresets.isHexColor(hex),
              let background = availableBackgrounds.first(where: { $0.id == backgroundId }),
              background.customizable,
              background.gradient.indices.contains(index)
        else { return }

        var colors = background.gradient
        colors[index] = hex
        settings.paletteOverrides[backgroundId] = colors
        settings.paletteOverrides = ClockioPresets.sanitizedPaletteOverrides(settings.paletteOverrides)
    }

    func resetPalette(backgroundId: String) {
        settings.paletteOverrides.removeValue(forKey: backgroundId)
    }

    func addTodo(title: String, scheduledHour: Int? = nil, scheduledMinute: Int? = nil) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (todos.map(\.sortOrder).max() ?? -1) + 1
        todos.append(TodoItem(
            title: trimmed,
            sortOrder: nextOrder,
            scheduledHour: sanitizedHour(scheduledHour),
            scheduledMinute: sanitizedMinute(scheduledMinute)
        ))
        todos = Self.renumbered(todos)
    }

    func updateTodoTitle(id: UUID, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        if trimmed.isEmpty {
            deleteTodo(id: id)
            return
        }
        todos[index].title = trimmed
    }

    func setTodoDone(id: UUID, isDone: Bool) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].isDone = isDone
    }

    func setTodoSchedule(id: UUID, hour: Int?, minute: Int?) {
        guard let index = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[index].scheduledHour = sanitizedHour(hour)
        todos[index].scheduledMinute = sanitizedMinute(minute)
        if todos[index].scheduledHour == nil || todos[index].scheduledMinute == nil {
            todos[index].scheduledHour = nil
            todos[index].scheduledMinute = nil
        }
    }

    func toggleTodoDone(id: UUID) {
        guard let todo = todos.first(where: { $0.id == id }) else { return }
        setTodoDone(id: id, isDone: !todo.isDone)
    }

    func deleteTodo(id: UUID) {
        todos.removeAll { $0.id == id }
        todos = Self.renumbered(todos)
    }

    func replaceTodosForSnapshot(_ sampleTodos: [TodoItem]) {
        todos = Self.renumbered(sampleTodos)
    }

    func chooseCustomBackground() {
        let panel = NSOpenPanel()
        panel.title = "Choose screensaver background"
        panel.allowedContentTypes = [.png, .jpeg, .webP, .gif, .heic, .heif]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let source = panel.url else { return }

        do {
            let imported = try persistence.copyCustomBackground(from: source)
            settings.customBackgroundPath = imported.path
            settings.customBackgroundName = imported.name
            settings.backgroundId = ClockioPresets.customBackgroundId
            systemStatusMessage = "Imported background: \(imported.name)"
        } catch {
            systemStatusMessage = "Could not import background: \(error.localizedDescription)"
            NSSound.beep()
        }
    }

    func startScreensaver() {
        guard !screensaverRunning else { return }

        screensaverGreeting = consumeMorningGreeting(for: Date())
        screensaverRunning = true
        presentScreensaverWindows()

        // Activate the app so keyDown events reach the local monitor; a borderless window
        // will not become key without help in accessory mode. `presentScreensaverWindows`
        // keys the clock (primary) window.
        NSApp.activate(ignoringOtherApps: true)

        installScreensaverEventMonitor()
        observeScreenChanges()
        onSettingsChanged?()
    }

    func stopScreensaver() {
        guard screensaverRunning || !screensaverWindows.isEmpty else { return }
        eventMonitor.map(NSEvent.removeMonitor)
        eventMonitor = nil
        screenChangeObserver.map(NotificationCenter.default.removeObserver)
        screenChangeObserver = nil
        screensaverWindows.forEach { $0.close() }
        screensaverWindows.removeAll()
        screensaverGreeting = nil
        screensaverRunning = false
        onSettingsChanged?()
    }

    private func consumeMorningGreeting(for date: Date, calendar: Calendar = .current) -> String? {
        guard let greeting = DayGreeting.text(for: date, calendar: calendar) else { return nil }

        let dayIdentifier = DayGreeting.dayIdentifier(for: date, calendar: calendar)
        guard settings.lastMorningGreetingDay != dayIdentifier else { return nil }

        settings.lastMorningGreetingDay = dayIdentifier
        return greeting
    }

    /// Build (or rebuild) one borderless screensaver window per connected display. With two or
    /// more displays the primary one shows the clock and the rest show the full-screen day plan
    /// ("one monitor for the clock, the other for the to-do list"). Rebuilding lets a display
    /// plugged in mid-session join the screensaver too.
    private func presentScreensaverWindows() {
        screensaverWindows.forEach { $0.close() }
        screensaverWindows.removeAll()

        // Make sure the agenda display shows up-to-date events for the day.
        refreshCalendarEvents()

        let screens = NSScreen.screens.isEmpty ? [NSScreen.main].compactMap { $0 } : NSScreen.screens
        let primary = Self.primaryScreen(in: screens)
        let hasAgendaDisplay = screens.count > 1

        screensaverWindows = screens.map { screen in
            let isPrimary = (screen == primary)
            let role: ScreensaverRole = (hasAgendaDisplay && !isPrimary)
                ? .agenda
                : .clock(showsTodos: !hasAgendaDisplay)

            // Create without a `screen:` argument and position with `setFrame` in global
            // coordinates. Passing `screen:` interprets `contentRect` relative to that
            // screen's origin, which double-offsets secondary displays and drops their
            // windows off-screen — so the saver only appeared on the main display.
            let window = ScreensaverWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            // The window is strongly retained in `screensaverWindows`, so it must not be
            // released when closed. Otherwise `close()` over-releases it under ARC, which
            // crashes later in `objc_release` while AppKit deallocates the window's
            // transform animation during an autorelease-pool drain.
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.backgroundColor = .black
            window.isOpaque = true
            window.acceptsMouseMovedEvents = true
            window.contentView = NSHostingView(
                rootView: ScreensaverView(role: role, globalPointerFrame: screen.frame)
                    .environmentObject(self)
            )
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            return window
        }

        // Key the clock (primary) window so keyDown events reach the local monitor.
        let primaryWindow = zip(screens, screensaverWindows).first { $0.0 == primary }?.1
        (primaryWindow ?? screensaverWindows.first)?.makeKey()
    }

    private func observeScreenChanges() {
        guard screenChangeObserver == nil else { return }
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.screensaverRunning else { return }
                self.presentScreensaverWindows()
            }
        }
    }

    /// The display showing the menu bar sits at the global origin. That is the "main monitor"
    /// the clock should live on, independent of which display currently has key focus.
    private static func primaryScreen(in screens: [NSScreen]) -> NSScreen? {
        screens.first { $0.frame.origin == .zero } ?? screens.first
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(settings.hideDock ? .accessory : .regular)
    }

    private func installScreensaverEventMonitor() {
        eventMonitor.map(NSEvent.removeMonitor)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.stopScreensaver()
            }
            return event
        }
    }

    private func scheduleSettingsSave() {
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.flushSettings() }
        }
    }

    /// Write any pending settings immediately. Called from `applicationWillTerminate` so a
    /// change made just before quitting is never lost to the debounce window.
    func flushSettings() {
        saveTimer?.invalidate()
        saveTimer = nil
        do {
            try persistence.saveSettings(settings)
        } catch {
            systemStatusMessage = "Could not save settings: \(error.localizedDescription)"
            NSSound.beep()
        }
    }

    func flushTodos() {
        todoSaveTimer?.invalidate()
        todoSaveTimer = nil
        do {
            try persistence.saveTodos(todos)
        } catch {
            systemStatusMessage = "Could not save to-dos: \(error.localizedDescription)"
            NSSound.beep()
        }
    }

    private func syncLaunchAtLogin() {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return }

        do {
            if settings.launchAtLogin {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep the preference; launch item changes require a signed app bundle in production.
            systemStatusMessage = "Could not update launch-at-login: \(error.localizedDescription)"
        }
    }

    private func scheduleIdleWatcher() {
        idleTimer?.invalidate()
        idleTimer = nil
        guard settings.autoStartScreensaver else { return }

        idleTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkIdleState()
            }
        }
    }

    private func checkIdleState() {
        guard settings.autoStartScreensaver, !screensaverRunning else { return }
        if systemIdleSeconds() >= Double(settings.idleMinutes * 60) {
            startScreensaver()
        }
    }

    /// Seconds since the last user input event (keyboard, mouse, trackpad, scroll…).
    ///
    /// `eventType: .null` measures the time since the last *null* event — effectively
    /// session uptime, not user idle time — which made the screensaver fire within a few
    /// seconds of launch regardless of activity. `kCGAnyInputEventType` (`~0`) reports the
    /// real idle interval.
    private func systemIdleSeconds() -> Double {
        guard let anyInput = CGEventType(rawValue: ~0) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    private func scheduleAppearanceWatcher() {
        appearanceTimer?.invalidate()
        appearanceTimer = nil
        updateAppearanceMode()

        guard settings.autoDayNightMode else { return }
        appearanceTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAppearanceMode()
            }
        }
    }

    private func updateAppearanceMode(now: Date = Date()) {
        setNightMode(NightMode.isActive(for: now, settings: settings, solar: solarSchedule))
    }

    private func setNightMode(_ active: Bool) {
        guard active != isNightModeActive else { return }
        isNightModeActive = active
        // Night mode changes the rendered palette, so refresh the cached background.
        recomputeBackgrounds()
    }

    /// Refreshes temperature and/or the solar schedule whenever either feature needs it. Both come
    /// from one cached location-based request, so a single timer drives them.
    private func scheduleConditionsRefresh() {
        weatherTimer?.invalidate()
        weatherTimer = nil

        if !settings.showTemperature {
            temperatureStatus = "Temperature hidden"
        }

        guard settings.showTemperature || settings.autoDayNightMode else { return }

        if settings.showTemperature {
            temperatureStatus = "Updating local temperature"
        }
        Task { [weak self] in await self?.loadConditions() }

        weatherTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.loadConditions() }
        }
    }

    private func loadConditions() async {
        guard settings.showTemperature || settings.autoDayNightMode else { return }
        do {
            let reading = try await weatherProvider.conditions()
            // Only write the temperature when it actually changed; the value persists as the
            // last-known reading shown while offline.
            if settings.showTemperature, reading.celsius != settings.temperature {
                settings.temperature = reading.celsius
            }
            if settings.showTemperature {
                temperatureStatus = "Updated from \(reading.sourceName)"
            }
            applySolarSchedule(SolarSchedule(sunrise: reading.sunrise, sunset: reading.sunset))
        } catch {
            if settings.showTemperature {
                temperatureStatus = "Weather unavailable - using saved temperature"
            }
        }
    }

    private func applySolarSchedule(_ schedule: SolarSchedule) {
        solarSchedule = schedule
        updateAppearanceMode()
    }

    private func scheduleTodosSave() {
        todoSaveTimer?.invalidate()
        todoSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.flushTodos() }
        }
    }

    private static func orderedTodos(_ todos: [TodoItem]) -> [TodoItem] {
        todos.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    private static func dayPlanTodos(_ todos: [TodoItem]) -> [TodoItem] {
        todos.sorted { lhs, rhs in
            let lhsMinutes = scheduledMinutes(lhs)
            let rhsMinutes = scheduledMinutes(rhs)
            switch (lhsMinutes, rhsMinutes) {
            case let (.some(left), .some(right)) where left != right:
                return left < right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    static func scheduledMinutes(_ todo: TodoItem) -> Int? {
        guard let hour = todo.scheduledHour,
              let minute = todo.scheduledMinute,
              (0...23).contains(hour),
              (0...59).contains(minute)
        else { return nil }
        return hour * 60 + minute
    }

    private static func renumbered(_ todos: [TodoItem]) -> [TodoItem] {
        todos.enumerated().map { index, todo in
            var next = todo
            next.sortOrder = Double(index)
            return next
        }
    }

    private func sanitizedHour(_ hour: Int?) -> Int? {
        guard let hour else { return nil }
        return min(max(hour, 0), 23)
    }

    private func sanitizedMinute(_ minute: Int?) -> Int? {
        guard let minute else { return nil }
        return min(max(minute, 0), 59)
    }
}
