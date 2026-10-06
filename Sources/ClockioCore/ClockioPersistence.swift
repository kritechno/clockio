import Foundation

public struct ClockioPersistence: Sendable {
    public var supportDirectory: URL

    public init(supportDirectory: URL? = nil) {
        if let supportDirectory {
            self.supportDirectory = supportDirectory
        } else {
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            self.supportDirectory = root.appendingPathComponent("Clockio", isDirectory: true)
        }
    }

    public var settingsURL: URL {
        supportDirectory.appendingPathComponent("settings.json", isDirectory: false)
    }

    public var todosURL: URL {
        supportDirectory.appendingPathComponent("todos.json", isDirectory: false)
    }

    public var customBackgroundsDirectory: URL {
        supportDirectory.appendingPathComponent("Custom Backgrounds", isDirectory: true)
    }

    public func loadSettings() -> ClockioSettings {
        do {
            let data = try Data(contentsOf: settingsURL)
            var settings = try JSONDecoder().decode(ClockioSettings.self, from: data)
            settings.normalize()
            return settings
        } catch {
            return ClockioSettings()
        }
    }

    public func saveSettings(_ settings: ClockioSettings) throws {
        var settings = settings
        settings.normalize()
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.clockio.encode(settings)
        try data.write(to: settingsURL, options: .atomic)
    }

    public func loadTodos() -> [TodoItem] {
        do {
            let data = try Data(contentsOf: todosURL)
            let todos = try JSONDecoder().decode([TodoItem].self, from: data)
            return Self.sortedTodos(todos.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        } catch {
            return []
        }
    }

    public func saveTodos(_ todos: [TodoItem]) throws {
        try FileManager.default.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.clockio.encode(Self.sortedTodos(todos))
        try data.write(to: todosURL, options: .atomic)
    }

    public func copyCustomBackground(from sourceURL: URL) throws -> (path: String, name: String) {
        try FileManager.default.createDirectory(at: customBackgroundsDirectory, withIntermediateDirectories: true)

        // Only one custom background is kept at a time. Remove any previous imports so that
        // repeatedly choosing a new image doesn't accumulate orphaned files in Application
        // Support (each import is copied under a fresh UUID filename).
        if let existing = try? FileManager.default.contentsOfDirectory(
            at: customBackgroundsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for url in existing {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let ext = sourceURL.pathExtension.isEmpty ? "png" : sourceURL.pathExtension
        let destination = customBackgroundsDirectory
            .appendingPathComponent("background-\(UUID().uuidString)", isDirectory: false)
            .appendingPathExtension(ext)

        try FileManager.default.copyItem(at: sourceURL, to: destination)
        return (destination.path, sourceURL.lastPathComponent)
    }

    private static func sortedTodos(_ todos: [TodoItem]) -> [TodoItem] {
        todos.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }
}

public extension JSONEncoder {
    static var clockio: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
