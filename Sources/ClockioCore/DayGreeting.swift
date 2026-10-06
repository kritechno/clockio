import Foundation

public enum DayGreeting {
    public static func text(for date: Date, calendar: Calendar = .current) -> String? {
        let hour = calendar.component(.hour, from: date)
        return (5..<12).contains(hour) ? "Good morning" : nil
    }

    public static func dayIdentifier(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
