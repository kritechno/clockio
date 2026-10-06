import Foundation

public enum ClockStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case digital
    case paint
    case horizon
    case flip
    case analog
    case minimal
    case terminal

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .digital: "Glass Digital"
        case .paint: "Date Sentence"
        case .horizon: "Status Corner"
        case .flip: "Flip Panels"
        case .analog: "Soft Dial"
        case .minimal: "Stacked"
        case .terminal: "Terminal"
        }
    }
}

public enum BackgroundScene: String, Codable, Sendable {
    case ribbons
    case paint
    case mist
    case horizon
    case contourHorizon
    case aurora
    case image

    public var label: String {
        switch self {
        case .ribbons: "Flow"
        case .paint: "Brush"
        case .mist: "Mist"
        case .horizon, .contourHorizon: "Horizon"
        case .aurora: "Aurora"
        case .image: "Image"
        }
    }
}

public struct ClockBackground: Identifiable, Equatable, Codable, Sendable {
    public var id: String
    public var name: String
    public var scene: BackgroundScene
    public var accent: String
    public var gradient: [String]
    public var customizable: Bool
    public var imagePath: String?

    public init(
        id: String,
        name: String,
        scene: BackgroundScene,
        accent: String,
        gradient: [String],
        customizable: Bool = true,
        imagePath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.scene = scene
        self.accent = accent
        self.gradient = gradient
        self.customizable = customizable
        self.imagePath = imagePath
    }
}

public struct TodoItem: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var title: String
    public var isDone: Bool
    public var createdAt: Date
    public var sortOrder: Double
    public var scheduledHour: Int?
    public var scheduledMinute: Int?

    public init(
        id: UUID = UUID(),
        title: String,
        isDone: Bool = false,
        createdAt: Date = Date(),
        sortOrder: Double = 0,
        scheduledHour: Int? = nil,
        scheduledMinute: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
    }
}

public struct ClockioSettings: Equatable, Codable, Sendable {
    public var launchAtLogin: Bool
    public var autoStartScreensaver: Bool
    public var idleMinutes: Int
    public var hideDock: Bool
    public var autoDayNightMode: Bool
    public var clockStyle: ClockStyle
    public var backgroundId: String
    public var motion: Double
    public var showDate: Bool
    public var showSeconds: Bool
    public var showTemperature: Bool
    public var showTodos: Bool
    public var showCalendarEvents: Bool
    public var temperature: Int
    public var customBackgroundPath: String?
    public var customBackgroundName: String
    public var paletteOverrides: [String: [String]]
    public var lastMorningGreetingDay: String?

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin
        case autoStartScreensaver
        case idleMinutes
        case hideDock
        case autoDayNightMode
        case clockStyle
        case backgroundId
        case motion
        case showDate
        case showSeconds
        case showTemperature
        case showTodos
        case showCalendarEvents
        case temperature
        case customBackgroundPath
        case customBackgroundName
        case paletteOverrides
        case lastMorningGreetingDay
    }

    public init(
        launchAtLogin: Bool = true,
        autoStartScreensaver: Bool = true,
        idleMinutes: Int = 5,
        hideDock: Bool = true,
        autoDayNightMode: Bool = true,
        clockStyle: ClockStyle = .digital,
        backgroundId: String = ClockioPresets.defaultBackgroundId,
        motion: Double = 42,
        showDate: Bool = true,
        showSeconds: Bool = false,
        showTemperature: Bool = true,
        showTodos: Bool = false,
        showCalendarEvents: Bool = false,
        temperature: Int = 24,
        customBackgroundPath: String? = nil,
        customBackgroundName: String = "",
        paletteOverrides: [String: [String]] = [:],
        lastMorningGreetingDay: String? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.autoStartScreensaver = autoStartScreensaver
        self.idleMinutes = idleMinutes
        self.hideDock = hideDock
        self.autoDayNightMode = autoDayNightMode
        self.clockStyle = clockStyle
        self.backgroundId = backgroundId
        self.motion = motion
        self.showDate = showDate
        self.showSeconds = showSeconds
        self.showTemperature = showTemperature
        self.showTodos = showTodos
        self.showCalendarEvents = showCalendarEvents
        self.temperature = temperature
        self.customBackgroundPath = customBackgroundPath
        self.customBackgroundName = customBackgroundName
        self.paletteOverrides = paletteOverrides
        self.lastMorningGreetingDay = lastMorningGreetingDay
        normalize()
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? true
        autoStartScreensaver = try container.decodeIfPresent(Bool.self, forKey: .autoStartScreensaver) ?? true
        idleMinutes = try container.decodeIfPresent(Int.self, forKey: .idleMinutes) ?? 5
        hideDock = try container.decodeIfPresent(Bool.self, forKey: .hideDock) ?? true
        autoDayNightMode = try container.decodeIfPresent(Bool.self, forKey: .autoDayNightMode) ?? true
        clockStyle = try container.decodeIfPresent(ClockStyle.self, forKey: .clockStyle) ?? .digital
        backgroundId = try container.decodeIfPresent(String.self, forKey: .backgroundId) ?? ClockioPresets.defaultBackgroundId
        motion = try container.decodeIfPresent(Double.self, forKey: .motion) ?? 42
        showDate = try container.decodeIfPresent(Bool.self, forKey: .showDate) ?? true
        showSeconds = try container.decodeIfPresent(Bool.self, forKey: .showSeconds) ?? false
        showTemperature = try container.decodeIfPresent(Bool.self, forKey: .showTemperature) ?? true
        showTodos = try container.decodeIfPresent(Bool.self, forKey: .showTodos) ?? false
        showCalendarEvents = try container.decodeIfPresent(Bool.self, forKey: .showCalendarEvents) ?? false
        temperature = try container.decodeIfPresent(Int.self, forKey: .temperature) ?? 24
        customBackgroundPath = try container.decodeIfPresent(String.self, forKey: .customBackgroundPath)
        customBackgroundName = try container.decodeIfPresent(String.self, forKey: .customBackgroundName) ?? ""
        paletteOverrides = try container.decodeIfPresent([String: [String]].self, forKey: .paletteOverrides) ?? [:]
        lastMorningGreetingDay = try container.decodeIfPresent(String.self, forKey: .lastMorningGreetingDay)
        normalize()
    }

    /// Whether a change between two settings values affects the menu-bar status menu
    /// (which only shows launch-at-login, dock, and idle-timer state).
    public func affectsStatusMenu(comparedTo other: ClockioSettings) -> Bool {
        launchAtLogin != other.launchAtLogin
            || hideDock != other.hideDock
            || idleMinutes != other.idleMinutes
            || autoStartScreensaver != other.autoStartScreensaver
    }

    public mutating func normalize() {
        idleMinutes = min(180, max(1, idleMinutes))
        motion = min(100, max(8, motion))
        temperature = min(80, max(-80, temperature))
        paletteOverrides = ClockioPresets.sanitizedPaletteOverrides(paletteOverrides)

        let customAvailable = customBackgroundPath.map { FileManager.default.fileExists(atPath: $0) } ?? false
        if backgroundId == ClockioPresets.customBackgroundId, !customAvailable {
            backgroundId = ClockioPresets.defaultBackgroundId
            customBackgroundPath = nil
            customBackgroundName = ""
        }

        if !ClockioPresets.isAllowedBackgroundId(backgroundId) {
            backgroundId = ClockioPresets.defaultBackgroundId
        }
    }
}

public enum ClockioPresets {
    public static let customBackgroundId = "custom"
    public static let defaultBackgroundId = "aurora"
    public static let fallbackGradient = ["#0d1118", "#1b2430", "#435268", "#8492a6", "#f8fafc"]

    public static let backgrounds: [ClockBackground] = [
        ClockBackground(
            id: "aurora",
            name: "Aurora Drift",
            scene: .ribbons,
            accent: "#6ee7f6",
            gradient: ["#06101e", "#11284a", "#5f4fd8", "#ff7c92", "#f2c66b"]
        ),
        ClockBackground(
            id: "mahogany",
            name: "Mahogany Flow",
            scene: .ribbons,
            accent: "#f6c88f",
            gradient: ["#180c0d", "#351316", "#7b2d23", "#d38b58", "#f3dac2"]
        ),
        ClockBackground(
            id: "spectrum",
            name: "Spectrum Brush",
            scene: .paint,
            accent: "#ff95c3",
            gradient: ["#f8f6f0", "#005d92", "#006148", "#ff671d", "#ff9bc4"],
            customizable: true
        ),
        ClockBackground(
            id: "silk",
            name: "Silk Horizon",
            scene: .horizon,
            accent: "#2e775c",
            gradient: ["#f8f4ee", "#6ba9ff", "#ffa8d3", "#ff6b28", "#00756c"],
            customizable: true
        ),
        ClockBackground(
            id: "prism",
            name: "Prism Brush",
            scene: .paint,
            accent: "#8d6df4",
            gradient: ["#f6f0e9", "#3867ff", "#7f4cff", "#ff4f7b", "#f9d661"],
            customizable: true
        ),
        ClockBackground(
            id: "vellum",
            name: "Vellum Brush",
            scene: .paint,
            accent: "#d76b45",
            gradient: ["#f5efe4", "#274653", "#2a9d8f", "#e76f51", "#f4a261"],
            customizable: true
        ),
        ClockBackground(
            id: "dawn-silk",
            name: "Dawn Silk",
            scene: .horizon,
            accent: "#d96b71",
            gradient: ["#f6eee5", "#8ab6ff", "#ffd0df", "#ff8a4c", "#526c52"],
            customizable: true
        ),
        ClockBackground(
            id: "polar-silk",
            name: "Polar Silk",
            scene: .horizon,
            accent: "#4b8d88",
            gradient: ["#eef5f2", "#78a7c8", "#ccd4ff", "#f1c7a1", "#1f6f75"],
            customizable: true
        ),
        ClockBackground(
            id: "field-contour",
            name: "Field Contour",
            scene: .contourHorizon,
            accent: "#7f6a3d",
            gradient: ["#f5f0e7", "#8ca8bd", "#e5c778", "#7f6a3d", "#2f6650"]
        ),
        ClockBackground(
            id: "arc-horizon",
            name: "Arc Horizon",
            scene: .contourHorizon,
            accent: "#bd6f5b",
            gradient: ["#f7efe6", "#7199b5", "#e6b2a2", "#bd6f5b", "#346665"]
        ),
        ClockBackground(
            id: "lumen",
            name: "Lumen Haze",
            scene: .aurora,
            accent: "#ccd8ff",
            gradient: ["#080813", "#21124a", "#7646d9", "#a687ff", "#f2efff"]
        ),
        ClockBackground(
            id: "lake-mist",
            name: "Lake Mist",
            scene: .mist,
            accent: "#c98fc7",
            gradient: ["#0d1820", "#244a61", "#c98fc7", "#17394f", "#eef1ef"]
        )
    ]

    public static func isHexColor(_ value: String) -> Bool {
        value.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
    }

    public static func isAllowedBackgroundId(_ id: String) -> Bool {
        id == customBackgroundId || backgrounds.contains { $0.id == id }
    }

    public static func background(named id: String, settings: ClockioSettings) -> ClockBackground {
        availableBackgrounds(settings: settings).first { $0.id == id } ?? backgrounds[0]
    }

    public static func availableBackgrounds(settings: ClockioSettings) -> [ClockBackground] {
        var settings = settings
        settings.normalize()

        var output = backgrounds.map { background in
            var next = background
            if let override = settings.paletteOverrides[background.id], override.count == 5 {
                next.gradient = override
                next.accent = override[3]
            }
            return next
        }

        if let path = settings.customBackgroundPath, FileManager.default.fileExists(atPath: path) {
            output.append(
                ClockBackground(
                    id: customBackgroundId,
                    name: "Custom Image",
                    scene: .image,
                    accent: "#f8fafc",
                    gradient: fallbackGradient,
                    customizable: false,
                    imagePath: path
                )
            )
        }

        return output
    }

    public static func sanitizedPaletteOverrides(_ overrides: [String: [String]]) -> [String: [String]] {
        let customizableIds = Set(backgrounds.filter(\.customizable).map(\.id))
        return overrides.reduce(into: [:]) { result, item in
            let (id, colors) = item
            guard customizableIds.contains(id), colors.count == 5, colors.allSatisfy(isHexColor) else {
                return
            }
            result[id] = colors
        }
    }
}
