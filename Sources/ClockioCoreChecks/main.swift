import ClockioCore
import Foundation

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw CheckFailure.failed(message)
    }
}

func run(_ name: String, _ body: () throws -> Void) rethrows {
    try body()
    print("PASS \(name)")
}

do {
    try run("preset catalog removes stale backgrounds and keeps all built-ins customizable") {
        let ids = Set(ClockioPresets.backgrounds.map(\.id))
        try expect(ids.isSuperset(of: [
            "aurora",
            "mahogany",
            "spectrum",
            "silk",
            "prism",
            "vellum",
            "dawn-silk",
            "polar-silk",
            "field-contour",
            "arc-horizon",
            "lumen",
            "lake-mist"
        ]), "Missing migrated background styles")
        try expect(!ids.contains("paper-bloom"), "Paper Bloom should be removed")
        try expect(!ids.contains("mineral-bloom"), "Mineral Bloom should be removed")
        try expect(!ids.contains("mono-smoke"), "Mono Smoke should be removed")
        try expect(!ids.contains("peach-glass"), "Peach Glass should be removed")
        try expect(!ids.contains("solar"), "Solar Glass should be removed")
        try expect(!ids.contains("tide"), "Tide Veil should be removed")
        try expect(!ids.contains("ember"), "Ember Rain should be removed")
        try expect(!ids.contains("codex"), "Codex Black should be removed")
        try expect(ClockioPresets.backgrounds.allSatisfy(\.customizable), "All built-in backgrounds should be customizable")
    }

    try run("palette overrides accept all built-ins and reject unknown ids and invalid colors") {
        let sanitized = ClockioPresets.sanitizedPaletteOverrides([
            "spectrum": ["#111111", "#222222", "#333333", "#444444", "#555555"],
            "aurora": ["#111111", "#222222", "#333333", "#444444", "#555555"],
            "silk": ["not-a-color", "#222222", "#333333", "#444444", "#555555"]
        ])

        try expect(sanitized["spectrum"] == ["#111111", "#222222", "#333333", "#444444", "#555555"], "Valid spectrum override was not preserved")
        try expect(sanitized["aurora"] == ["#111111", "#222222", "#333333", "#444444", "#555555"], "Valid aurora override was not preserved")
        try expect(sanitized["silk"] == nil, "Invalid silk override should be rejected")
    }

    try run("settings normalize clamps values and falls back from missing custom image") {
        var settings = ClockioSettings(
            idleMinutes: 900,
            backgroundId: ClockioPresets.customBackgroundId,
            motion: 2,
            temperature: 140,
            customBackgroundPath: "/path/that/does/not/exist.png"
        )

        settings.normalize()
        try expect(settings.idleMinutes == 180, "idleMinutes was not clamped")
        try expect(settings.motion == 8, "motion was not clamped")
        try expect(settings.temperature == 80, "temperature was not clamped")
        try expect(settings.backgroundId == ClockioPresets.defaultBackgroundId, "missing custom image did not fall back")
        try expect(settings.customBackgroundPath == nil, "missing custom path was not cleared")
    }

    try run("available backgrounds includes custom image when file exists") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let imageURL = directory.appendingPathComponent("desk.png")
        try Data([1, 2, 3]).write(to: imageURL)

        let settings = ClockioSettings(
            backgroundId: ClockioPresets.customBackgroundId,
            customBackgroundPath: imageURL.path,
            customBackgroundName: "desk.png"
        )

        let custom = ClockioPresets.availableBackgrounds(settings: settings)
            .first { $0.id == ClockioPresets.customBackgroundId }
        try expect(custom?.name == "Custom Image", "custom image should use a stable display name")
        try expect(custom?.scene == .image, "custom image scene was not image")
        try expect(custom?.imagePath == imageURL.path, "custom image path was not used")
        try expect(custom?.customizable == false, "custom image should not expose palette editing")
    }

    try run("persistence round trips settings") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = ClockioPersistence(supportDirectory: directory)
        let settings = ClockioSettings(
            launchAtLogin: false,
            idleMinutes: 15,
            autoDayNightMode: false,
            clockStyle: .terminal,
            backgroundId: "spectrum",
            paletteOverrides: [
                "spectrum": ["#111111", "#222222", "#333333", "#444444", "#555555"]
            ],
            lastMorningGreetingDay: "2026-06-16"
        )

        try persistence.saveSettings(settings)
        let loaded = persistence.loadSettings()

        try expect(loaded.launchAtLogin == false, "launchAtLogin did not persist")
        try expect(loaded.autoDayNightMode == false, "autoDayNightMode did not persist")
        try expect(loaded.idleMinutes == 15, "idleMinutes did not persist")
        try expect(loaded.clockStyle == .terminal, "clockStyle did not persist")
        try expect(loaded.backgroundId == "spectrum", "backgroundId did not persist")
        try expect(loaded.paletteOverrides["spectrum"] == ["#111111", "#222222", "#333333", "#444444", "#555555"], "palette override did not persist")
        try expect(loaded.lastMorningGreetingDay == "2026-06-16", "last morning greeting day did not persist")
    }

    try run("settings decode migrates missing showTodos and auto day/night") {
        let json = """
        {
          "launchAtLogin": false,
          "autoStartScreensaver": true,
          "idleMinutes": 10,
          "hideDock": true,
          "clockStyle": "digital",
          "backgroundId": "silk",
          "motion": 42,
          "showDate": true,
          "showSeconds": false,
          "showTemperature": true,
          "temperature": 22,
          "customBackgroundName": "",
          "paletteOverrides": {}
        }
        """

        let settings = try JSONDecoder().decode(ClockioSettings.self, from: Data(json.utf8))

        try expect(settings.backgroundId == "silk", "backgroundId did not decode")
        try expect(settings.showTodos == false, "missing showTodos should decode to false")
        try expect(settings.autoDayNightMode == true, "missing autoDayNightMode should decode to true")
    }

    try run("day greeting shows good morning only during morning") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(hour: Int, minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: 2026,
                month: 6,
                day: 16,
                hour: hour,
                minute: minute
            ))!
        }

        try expect(DayGreeting.text(for: date(hour: 4, minute: 59), calendar: calendar) == nil, "greeting should be hidden before morning")
        try expect(DayGreeting.text(for: date(hour: 5), calendar: calendar) == "Good morning", "greeting should appear at 05:00")
        try expect(DayGreeting.text(for: date(hour: 11, minute: 59), calendar: calendar) == "Good morning", "greeting should remain through 11:59")
        try expect(DayGreeting.text(for: date(hour: 12), calendar: calendar) == nil, "greeting should be hidden at noon")
        try expect(DayGreeting.dayIdentifier(for: date(hour: 5), calendar: calendar) == "2026-06-16", "greeting day identifier was incorrect")
    }

    try run("persistence round trips todos separately from settings") {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let persistence = ClockioPersistence(supportDirectory: directory)
        let settings = ClockioSettings(showTodos: true)
        let todos = [
            TodoItem(title: "Second", createdAt: Date(timeIntervalSinceReferenceDate: 2), sortOrder: 1, scheduledHour: 15, scheduledMinute: 0),
            TodoItem(title: "First", createdAt: Date(timeIntervalSinceReferenceDate: 1), sortOrder: 0, scheduledHour: 9, scheduledMinute: 30),
            TodoItem(title: "Done", isDone: true, createdAt: Date(timeIntervalSinceReferenceDate: 3), sortOrder: 2)
        ]

        try persistence.saveSettings(settings)
        try persistence.saveTodos(todos)
        let loadedSettings = persistence.loadSettings()
        let loadedTodos = persistence.loadTodos()
        let settingsJSON = try String(contentsOf: persistence.settingsURL, encoding: .utf8)

        try expect(loadedSettings.showTodos == true, "showTodos did not persist")
        try expect(loadedTodos.map(\.title) == ["First", "Second", "Done"], "todos did not persist in sort order")
        try expect(loadedTodos[0].scheduledHour == 9, "scheduled hour did not persist")
        try expect(loadedTodos[0].scheduledMinute == 30, "scheduled minute did not persist")
        try expect(loadedTodos[2].isDone == true, "completed todo did not persist")
        try expect(!settingsJSON.contains("First"), "todo title leaked into settings.json")
        try expect(FileManager.default.fileExists(atPath: persistence.todosURL.path), "todos.json was not created")
    }

    try run("night mode follows solar schedule with fixed fallback") {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func date(hour: Int) -> Date {
            calendar.date(from: DateComponents(
                calendar: calendar, timeZone: calendar.timeZone,
                year: 2026, month: 6, day: 16, hour: hour, minute: 0
            ))!
        }

        let solar = SolarSchedule(sunrise: date(hour: 6), sunset: date(hour: 21))
        let auto = ClockioSettings(autoDayNightMode: true)

        try expect(NightMode.isActive(for: date(hour: 5), settings: auto, solar: solar, calendar: calendar), "before sunrise should be night")
        try expect(!NightMode.isActive(for: date(hour: 12), settings: auto, solar: solar, calendar: calendar), "midday should be day")
        try expect(NightMode.isActive(for: date(hour: 21), settings: auto, solar: solar, calendar: calendar), "after sunset should be night")

        try expect(NightMode.isActive(for: date(hour: 6), settings: auto, solar: nil, calendar: calendar), "fallback: 06:00 should be night")
        try expect(!NightMode.isActive(for: date(hour: 12), settings: auto, solar: nil, calendar: calendar), "fallback: midday should be day")
        try expect(NightMode.isActive(for: date(hour: 20), settings: auto, solar: nil, calendar: calendar), "fallback: 20:00 should be night")

        let locked = ClockioSettings(autoDayNightMode: false)
        try expect(!NightMode.isActive(for: date(hour: 23), settings: locked, solar: solar, calendar: calendar), "disabled auto day/night should never be night")
    }

    print("All ClockioCore checks passed")
} catch {
    fputs("FAIL \(error)\n", stderr)
    exit(1)
}
