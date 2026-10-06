import AppKit
import ClockioCore
import SwiftUI

@MainActor
func writeSnapshot(
    mode: WorkspaceMode,
    screensaver: Bool,
    style: ClockStyle? = nil,
    backgroundId: String? = nil,
    customBackgroundPath: String? = nil,
    includeTodos: Bool = false,
    agenda: Bool = false,
    to path: String
) throws {
    let model = ClockioAppModel(
        persistence: ClockioPersistence(
            supportDirectory: URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("ClockioSnapshot-\(UUID().uuidString)", isDirectory: true)
        )
    )
    model.mode = mode
    if let style {
        model.settings.clockStyle = style
    }
    if let customBackgroundPath, FileManager.default.fileExists(atPath: customBackgroundPath) {
        model.settings.customBackgroundPath = customBackgroundPath
        model.settings.customBackgroundName = URL(fileURLWithPath: customBackgroundPath).lastPathComponent
        model.settings.backgroundId = ClockioPresets.customBackgroundId
    }
    if let backgroundId, model.availableBackgrounds.contains(where: { $0.id == backgroundId }) {
        model.settings.backgroundId = backgroundId
    }
    if includeTodos {
        model.settings.showTodos = true
        model.replaceTodosForSnapshot(SelfContainedSnapshotData.todos)
    }

    let rootView: AnyView = screensaver
        ? AnyView(ScreensaverView(role: agenda ? .agenda : .clock(showsTodos: true)).environmentObject(model))
        : AnyView(ClockioRootView().environmentObject(model))
    let view = NSHostingView(rootView: rootView)
    view.frame = NSRect(x: 0, y: 0, width: 1280, height: 720)
    view.wantsLayer = true
    view.layoutSubtreeIfNeeded()

    guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw SnapshotError.renderFailed
    }
    representation.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: representation)

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw SnapshotError.renderFailed
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

@MainActor
func writeBackgroundThumbSnapshot(customBackgroundPath: String, to path: String) throws {
    var settings = ClockioSettings()
    settings.customBackgroundPath = customBackgroundPath
    settings.customBackgroundName = URL(fileURLWithPath: customBackgroundPath).lastPathComponent
    settings.backgroundId = ClockioPresets.customBackgroundId

    guard let background = ClockioPresets.availableBackgrounds(settings: settings)
        .first(where: { $0.id == ClockioPresets.customBackgroundId })
    else {
        throw SnapshotError.renderFailed
    }

    let rootView = BackgroundThumb(background: background, cornerRadius: 12)
    let view = NSHostingView(rootView: rootView)
    view.frame = NSRect(x: 0, y: 0, width: 268, height: 184)
    view.wantsLayer = true
    view.layoutSubtreeIfNeeded()

    guard let representation = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
        throw SnapshotError.renderFailed
    }
    representation.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: representation)

    guard let data = representation.representation(using: .png, properties: [:]) else {
        throw SnapshotError.renderFailed
    }
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

@MainActor
func writeTodoSnapshotSuite(to directoryPath: String) throws {
    let directory = URL(fileURLWithPath: directoryPath, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let backgroundsByStyle: [ClockStyle: String] = [
        .digital: "silk",
        .paint: "prism",
        .horizon: "field-contour",
        .flip: "aurora",
        .analog: "lake-mist",
        .minimal: "arc-horizon",
        .terminal: "lumen"
    ]

    for style in ClockStyle.allCases {
        let output = directory.appendingPathComponent("clockio-\(style.rawValue)-todos.png")
        try writeSnapshot(
            mode: .gallery,
            screensaver: false,
            style: style,
            backgroundId: backgroundsByStyle[style],
            includeTodos: true,
            to: output.path
        )
    }

    try writeSnapshot(
        mode: .gallery,
        screensaver: true,
        style: .digital,
        backgroundId: "silk",
        includeTodos: true,
        to: directory.appendingPathComponent("clockio-screensaver-todos.png").path
    )

    try writeSnapshot(
        mode: .todo,
        screensaver: false,
        style: .digital,
        backgroundId: "lake-mist",
        includeTodos: true,
        to: directory.appendingPathComponent("clockio-todo-workspace.png").path
    )
}

enum SelfContainedSnapshotData {
    static let todos: [TodoItem] = [
        TodoItem(title: "Review timeline", createdAt: Date(timeIntervalSinceReferenceDate: 0), sortOrder: 0, scheduledHour: 9, scheduledMinute: 30),
        TodoItem(title: "Gym", createdAt: Date(timeIntervalSinceReferenceDate: 60), sortOrder: 1, scheduledHour: 15, scheduledMinute: 0),
        TodoItem(title: "Prep focus block", createdAt: Date(timeIntervalSinceReferenceDate: 120), sortOrder: 2),
        TodoItem(title: "Archived item", isDone: true, createdAt: Date(timeIntervalSinceReferenceDate: 180), sortOrder: 3)
    ]
}

enum SnapshotError: Error {
    case renderFailed
}

enum SmokeTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

@MainActor
func runTodoSmokeTest() throws {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("ClockioTodoSmoke-\(UUID().uuidString)", isDirectory: true)
    let persistence = ClockioPersistence(supportDirectory: directory)
    let model = ClockioAppModel(persistence: persistence)

    model.settings.showTodos = true
    model.addTodo(title: "Draft plan", scheduledHour: 9, scheduledMinute: 30)
    model.addTodo(title: "Send recap", scheduledHour: 15, scheduledMinute: 0)
    guard let first = model.orderedTodos.first, let second = model.orderedTodos.dropFirst().first else {
        throw SmokeTestError.failed("todos were not added")
    }

    model.updateTodoTitle(id: first.id, title: "Finalize plan")
    model.setTodoDone(id: second.id, isDone: true)
    model.flushSettings()
    model.flushTodos()

    let restarted = ClockioAppModel(persistence: persistence)
    let loaded = restarted.orderedTodos
    guard restarted.settings.showTodos else {
        throw SmokeTestError.failed("showTodos did not persist")
    }
    let loadedTitles = loaded.map(\.title)
    guard loadedTitles == ["Finalize plan", "Send recap"] else {
        throw SmokeTestError.failed("todo add/edit did not persist: \(loadedTitles)")
    }
    guard loaded.first?.isDone == false, loaded.dropFirst().first?.isDone == true else {
        throw SmokeTestError.failed("todo completion state did not persist")
    }
    guard loaded.dropFirst().first?.scheduledHour == 15, loaded.dropFirst().first?.scheduledMinute == 0 else {
        throw SmokeTestError.failed("todo schedule did not persist")
    }
}

func argument(after flag: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: flag) else { return nil }
    let valueIndex = CommandLine.arguments.index(after: index)
    guard CommandLine.arguments.indices.contains(valueIndex) else { return nil }
    return CommandLine.arguments[valueIndex]
}

if CommandLine.arguments.contains("--todo-smoke-test") {
    do {
        _ = NSApplication.shared
        try runTodoSmokeTest()
        print("todo smoke test passed")
        exit(0)
    } catch {
        fputs("todo smoke test failed: \(error)\n", stderr)
        exit(1)
    }
}

if let suiteOutput = argument(after: "--snapshot-suite") {
    do {
        _ = NSApplication.shared
        try writeTodoSnapshotSuite(to: suiteOutput)
        print(suiteOutput)
        exit(0)
    } catch {
        fputs("snapshot suite failed: \(error)\n", stderr)
        exit(1)
    }
}

if let thumbOutput = argument(after: "--thumb-snapshot") {
    guard let customBackgroundPath = argument(after: "--custom-background") else {
        fputs("thumb snapshot failed: --custom-background is required\n", stderr)
        exit(1)
    }

    do {
        _ = NSApplication.shared
        try writeBackgroundThumbSnapshot(customBackgroundPath: customBackgroundPath, to: thumbOutput)
        print(thumbOutput)
        exit(0)
    } catch {
        fputs("thumb snapshot failed: \(error)\n", stderr)
        exit(1)
    }
}

if let snapshotIndex = CommandLine.arguments.firstIndex(of: "--snapshot") {
    let output = CommandLine.arguments.dropFirst(snapshotIndex + 1).first ?? "/tmp/clockio-swiftui-snapshot.png"
    let mode: WorkspaceMode = if CommandLine.arguments.contains("--settings") {
        .settings
    } else if CommandLine.arguments.contains("--todo") {
        .todo
    } else {
        .gallery
    }
    let screensaver = CommandLine.arguments.contains("--screensaver")
    let agenda = CommandLine.arguments.contains("--agenda")
    let style = argument(after: "--style").flatMap(ClockStyle.init(rawValue:))
    let backgroundId = argument(after: "--background")
    let customBackgroundPath = argument(after: "--custom-background")
    let includeTodos = CommandLine.arguments.contains("--todos")
    do {
        _ = NSApplication.shared
        try writeSnapshot(
            mode: mode,
            screensaver: screensaver,
            style: style,
            backgroundId: backgroundId,
            customBackgroundPath: customBackgroundPath,
            includeTodos: includeTodos,
            agenda: agenda,
            to: output
        )
        print(output)
        exit(0)
    } catch {
        fputs("snapshot failed: \(error)\n", stderr)
        exit(1)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let model = ClockioAppModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var isQuitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(model.settings.hideDock ? .accessory : .regular)
        NSApp.mainMenu = makeApplicationMenu()

        createMainWindow()
        createStatusItem()
        model.onSettingsChanged = { [weak self] in
            self?.rebuildStatusMenu()
        }
        model.start()

        if !model.settings.hideDock {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist any setting changed within the save debounce window before exit.
        model.flushSettings()
        model.flushTodos()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isQuitting { return true }
        sender.orderOut(nil)
        // Closing via the traffic light hides the window; keep the status menu's Open/Hide label
        // in sync (it would otherwise still read "Hide Clockio").
        rebuildStatusMenu()
        return false
    }

    private func createMainWindow() {
        let rootView = ClockioRootView().environmentObject(model)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1440, height: 930),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = "Clockio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = NSColor(red: 0.97, green: 0.96, blue: 0.93, alpha: 1)
        window.minSize = NSSize(width: 1080, height: 720)
        window.contentView = NSHostingView(rootView: rootView)
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }

    private func showMainWindow() {
        if window == nil {
            createMainWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        rebuildStatusMenu()
    }

    private func hideMainWindow() {
        window?.orderOut(nil)
        rebuildStatusMenu()
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = makeStatusIcon()
        item.button?.image?.isTemplate = true
        item.button?.toolTip = "Clockio"
        let menu = NSMenu()
        menu.delegate = self
        // Respect the manual `isEnabled` flags (disabled headers, Stop-Screensaver state) instead
        // of letting AppKit re-enable every item with a valid action.
        menu.autoenablesItems = false
        item.menu = menu
        statusItem = item
        rebuildStatusMenu()
    }

    /// Repopulate just before the menu opens so window-visibility and screensaver state are always
    /// current, regardless of how they last changed.
    func menuNeedsUpdate(_ menu: NSMenu) {
        populateStatusMenu(menu)
    }

    private func rebuildStatusMenu() {
        guard let menu = statusItem?.menu else { return }
        populateStatusMenu(menu)
    }

    private func populateStatusMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        let isVisible = window?.isVisible ?? false

        let title = NSMenuItem(title: "Clockio", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(NSMenuItem(
            title: isVisible ? "Hide Clockio" : "Open Clockio",
            action: isVisible ? #selector(hideClockioFromMenu) : #selector(openClockioFromMenu),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Start Screensaver Now", action: #selector(startScreensaverFromMenu), keyEquivalent: ""))

        let stopItem = NSMenuItem(title: "Stop Screensaver", action: #selector(stopScreensaverFromMenu), keyEquivalent: "")
        stopItem.isEnabled = model.screensaverRunning
        menu.addItem(stopItem)

        menu.addItem(.separator())
        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = model.settings.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        let dockItem = NSMenuItem(title: "Hide Dock Icon", action: #selector(toggleDockIcon), keyEquivalent: "")
        dockItem.state = model.settings.hideDock ? .on : .off
        menu.addItem(dockItem)

        let idleItem = NSMenuItem(
            title: "Idle Start: \(model.settings.autoStartScreensaver ? "\(model.settings.idleMinutes) min" : "Off")",
            action: nil,
            keyEquivalent: ""
        )
        idleItem.isEnabled = false
        menu.addItem(idleItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Clockio", action: #selector(quitClockio), keyEquivalent: "q"))
    }

    @objc private func openClockioFromMenu() {
        showMainWindow()
    }

    @objc private func hideClockioFromMenu() {
        hideMainWindow()
    }

    @objc private func startScreensaverFromMenu() {
        model.startScreensaver()
    }

    @objc private func stopScreensaverFromMenu() {
        model.stopScreensaver()
    }

    @objc private func toggleLaunchAtLogin() {
        model.settings.launchAtLogin.toggle()
    }

    @objc private func toggleDockIcon() {
        model.settings.hideDock.toggle()
    }

    @objc private func quitClockio() {
        isQuitting = true
        model.stopScreensaver()
        NSApp.terminate(nil)
    }

    private func makeApplicationMenu() -> NSMenu {
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit Clockio", action: #selector(quitClockio), keyEquivalent: "q"))
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        menu.addItem(appItem)
        return menu
    }

    private func makeStatusIcon() -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.black.setStroke()

        let outer = NSBezierPath(ovalIn: NSRect(x: 3, y: 3, width: 16, height: 16))
        outer.lineWidth = 2.2
        outer.stroke()

        let hands = NSBezierPath()
        hands.move(to: NSPoint(x: 11, y: 11))
        hands.line(to: NSPoint(x: 11, y: 16))
        hands.move(to: NSPoint(x: 11, y: 11))
        hands.line(to: NSPoint(x: 15, y: 9))
        hands.lineWidth = 2.0
        hands.lineCapStyle = .round
        hands.stroke()

        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: 7, y: 6))
        smile.curve(to: NSPoint(x: 16, y: 7), controlPoint1: NSPoint(x: 9, y: 4.2), controlPoint2: NSPoint(x: 13, y: 4.5))
        smile.lineWidth = 1.8
        smile.lineCapStyle = .round
        smile.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
