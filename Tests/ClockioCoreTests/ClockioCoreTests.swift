import ClockioCore
import Foundation

#if canImport(XCTest)
import XCTest

final class ClockioCoreTests: XCTestCase {
    func testPresetCatalogRemovesStaleBackgroundsAndKeepsAllBuiltInsCustomizable() {
        let ids = Set(ClockioPresets.backgrounds.map(\.id))

        XCTAssertTrue(ids.isSuperset(of: [
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
        ]))
        XCTAssertFalse(ids.contains("paper-bloom"))
        XCTAssertFalse(ids.contains("mineral-bloom"))
        XCTAssertFalse(ids.contains("mono-smoke"))
        XCTAssertFalse(ids.contains("peach-glass"))
        XCTAssertFalse(ids.contains("solar"))
        XCTAssertFalse(ids.contains("tide"))
        XCTAssertFalse(ids.contains("ember"))
        XCTAssertFalse(ids.contains("codex"))
        XCTAssertTrue(ClockioPresets.backgrounds.allSatisfy(\.customizable))
    }

    func testPaletteOverridesAcceptAllBuiltInsAndRejectUnknownIdsAndInvalidColors() {
        let sanitized = ClockioPresets.sanitizedPaletteOverrides([
            "aurora": ["#111111", "#222222", "#333333", "#444444", "#555555"],
            "spectrum": ["#AAAAAA", "#BBBBBB", "#CCCCCC", "#DDDDDD", "#EEEEEE"],
            "unknown": ["#111111", "#222222", "#333333", "#444444", "#555555"],
            "silk": ["not-a-color", "#222222", "#333333", "#444444", "#555555"]
        ])

        XCTAssertEqual(sanitized["aurora"], ["#111111", "#222222", "#333333", "#444444", "#555555"])
        XCTAssertEqual(sanitized["spectrum"], ["#AAAAAA", "#BBBBBB", "#CCCCCC", "#DDDDDD", "#EEEEEE"])
        XCTAssertNil(sanitized["unknown"])
        XCTAssertNil(sanitized["silk"])
    }

    func testSettingsNormalizeClampsValuesAndFallsBackFromMissingCustomImage() {
        var settings = ClockioSettings(
            idleMinutes: 900,
            backgroundId: ClockioPresets.customBackgroundId,
            motion: 2,
            temperature: 140,
            customBackgroundPath: "/path/that/does/not/exist.png"
        )

        settings.normalize()

        XCTAssertEqual(settings.idleMinutes, 180)
        XCTAssertEqual(settings.motion, 8)
        XCTAssertEqual(settings.temperature, 80)
        XCTAssertEqual(settings.backgroundId, ClockioPresets.defaultBackgroundId)
        XCTAssertNil(settings.customBackgroundPath)
    }

    func testAvailableBackgroundsIncludesNonCustomizableImageWhenFileExists() throws {
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

        XCTAssertEqual(custom?.name, "Custom Image")
        XCTAssertEqual(custom?.scene, .image)
        XCTAssertEqual(custom?.imagePath, imageURL.path)
        XCTAssertEqual(custom?.customizable, false)
    }

    func testPersistenceRoundTripsSettings() throws {
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

        XCTAssertFalse(loaded.launchAtLogin)
        XCTAssertFalse(loaded.autoDayNightMode)
        XCTAssertEqual(loaded.idleMinutes, 15)
        XCTAssertEqual(loaded.clockStyle, .terminal)
        XCTAssertEqual(loaded.backgroundId, "spectrum")
        XCTAssertEqual(loaded.paletteOverrides["spectrum"], ["#111111", "#222222", "#333333", "#444444", "#555555"])
        XCTAssertEqual(loaded.lastMorningGreetingDay, "2026-06-16")
    }

    func testSettingsDecodeMigratesMissingShowTodosAndAutoDayNight() throws {
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

        XCTAssertEqual(settings.backgroundId, "silk")
        XCTAssertFalse(settings.showTodos)
        XCTAssertTrue(settings.autoDayNightMode)
    }

    func testDayGreetingShowsGoodMorningOnlyDuringMorning() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertNil(DayGreeting.text(for: Self.date(hour: 4, minute: 59, calendar: calendar), calendar: calendar))
        XCTAssertEqual(DayGreeting.text(for: Self.date(hour: 5, calendar: calendar), calendar: calendar), "Good morning")
        XCTAssertEqual(DayGreeting.text(for: Self.date(hour: 11, minute: 59, calendar: calendar), calendar: calendar), "Good morning")
        XCTAssertNil(DayGreeting.text(for: Self.date(hour: 12, calendar: calendar), calendar: calendar))
        XCTAssertEqual(DayGreeting.dayIdentifier(for: Self.date(hour: 5, calendar: calendar), calendar: calendar), "2026-06-16")
    }

    func testPersistenceRoundTripsTodosSeparatelyFromSettings() throws {
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

        XCTAssertTrue(loadedSettings.showTodos)
        XCTAssertEqual(loadedTodos.map(\.title), ["First", "Second", "Done"])
        XCTAssertEqual(loadedTodos[0].scheduledHour, 9)
        XCTAssertEqual(loadedTodos[0].scheduledMinute, 30)
        XCTAssertTrue(loadedTodos[2].isDone)
        XCTAssertFalse(settingsJSON.contains("First"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: persistence.todosURL.path))
    }

    func testNightModeFollowsSolarScheduleWithFixedFallback() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let solar = SolarSchedule(
            sunrise: Self.date(hour: 6, calendar: calendar),
            sunset: Self.date(hour: 21, calendar: calendar)
        )
        let auto = ClockioSettings(autoDayNightMode: true)

        // Solar schedule: night before sunrise and after sunset, day in between.
        XCTAssertTrue(NightMode.isActive(for: Self.date(hour: 5, calendar: calendar), settings: auto, solar: solar, calendar: calendar))
        XCTAssertFalse(NightMode.isActive(for: Self.date(hour: 12, calendar: calendar), settings: auto, solar: solar, calendar: calendar))
        XCTAssertTrue(NightMode.isActive(for: Self.date(hour: 21, calendar: calendar), settings: auto, solar: solar, calendar: calendar))

        // No schedule yet → fixed 20:00–07:00 fallback.
        XCTAssertTrue(NightMode.isActive(for: Self.date(hour: 6, calendar: calendar), settings: auto, solar: nil, calendar: calendar))
        XCTAssertFalse(NightMode.isActive(for: Self.date(hour: 12, calendar: calendar), settings: auto, solar: nil, calendar: calendar))
        XCTAssertTrue(NightMode.isActive(for: Self.date(hour: 20, calendar: calendar), settings: auto, solar: nil, calendar: calendar))

        // Disabled → never night, even after sunset.
        let locked = ClockioSettings(autoDayNightMode: false)
        XCTAssertFalse(NightMode.isActive(for: Self.date(hour: 23, calendar: calendar), settings: locked, solar: solar, calendar: calendar))
    }

    private static func date(hour: Int, minute: Int = 0, calendar: Calendar) -> Date {
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
}
#endif
