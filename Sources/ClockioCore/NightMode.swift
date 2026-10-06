import Foundation

/// Today's sunrise / sunset for the device location. Drives automatic day/night so the app
/// darkens with the actual sunset instead of a fixed clock time.
public struct SolarSchedule: Equatable, Sendable {
    public var sunrise: Date
    public var sunset: Date

    public init(sunrise: Date, sunset: Date) {
        self.sunrise = sunrise
        self.sunset = sunset
    }

    /// Night runs from sunset until the following sunrise. The times are for the current day; the
    /// schedule is refreshed daily, so before sunrise / after sunset both read as night.
    public func isNight(at date: Date) -> Bool {
        date < sunrise || date >= sunset
    }
}

public enum NightMode {
    /// Whether night colours should be active. Prefers the location-based sunrise/sunset; falls
    /// back to a fixed evening window (20:00–07:00) until the first solar lookup succeeds or when
    /// location is unavailable.
    public static func isActive(
        for date: Date,
        settings: ClockioSettings,
        solar: SolarSchedule?,
        calendar: Calendar = .current
    ) -> Bool {
        guard settings.autoDayNightMode else { return false }
        if let solar {
            return solar.isNight(at: date)
        }
        let hour = calendar.component(.hour, from: date)
        return hour >= 20 || hour < 7
    }
}
