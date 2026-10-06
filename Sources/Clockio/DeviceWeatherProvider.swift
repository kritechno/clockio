import CoreLocation
import Foundation

struct DeviceConditions {
    var celsius: Int
    /// Today's sunrise / sunset for the device location, used to drive automatic day/night.
    var sunrise: Date
    var sunset: Date
    var sourceName: String
}

enum DeviceWeatherError: LocalizedError {
    case locationServicesDisabled
    case locationPermissionDenied
    case locationUnavailable
    case invalidWeatherURL
    case emptyWeatherResponse

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            "Location services are disabled."
        case .locationPermissionDenied:
            "Clockio does not have permission to use the device location."
        case .locationUnavailable:
            "The device location is not available yet."
        case .invalidWeatherURL:
            "The weather request could not be created."
        case .emptyWeatherResponse:
            "The weather service returned no current temperature."
        }
    }
}

@MainActor
final class DeviceWeatherProvider: NSObject, @preconcurrency CLLocationManagerDelegate {
    private struct CachedReading {
        var reading: DeviceConditions
        var fetchedAt: Date
    }

    private struct OpenMeteoResponse: Decodable {
        struct Current: Decodable {
            var temperature2m: Double

            enum CodingKeys: String, CodingKey {
                case temperature2m = "temperature_2m"
            }
        }

        struct Daily: Decodable {
            var sunrise: [Double]
            var sunset: [Double]
        }

        var current: Current?
        var daily: Daily?
    }

    private let locationManager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<Void, Error>?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var cachedReading: CachedReading?
    private let cacheDuration: TimeInterval = 15 * 60
    /// Coalesces overlapping fetches: a refresh triggered by the timer and one triggered by a
    /// settings toggle must share a single network/location request, otherwise each would
    /// overwrite the other's `locationContinuation` and resolve it early as "unavailable".
    private var inFlightFetch: Task<DeviceConditions, Error>?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        locationManager.distanceFilter = 2_000
    }

    /// Current temperature plus today's sunrise/sunset for the device location, cached for 15
    /// minutes. Concurrent callers share one in-flight request.
    func conditions() async throws -> DeviceConditions {
        if let cachedReading, Date().timeIntervalSince(cachedReading.fetchedAt) < cacheDuration {
            return cachedReading.reading
        }

        if let inFlightFetch {
            return try await inFlightFetch.value
        }

        let fetch = Task { () throws -> DeviceConditions in
            let location = try await currentLocation()
            return try await fetchOpenMeteoConditions(for: location)
        }
        inFlightFetch = fetch
        defer { inFlightFetch = nil }

        let reading = try await fetch.value
        cachedReading = CachedReading(reading: reading, fetchedAt: Date())
        return reading
    }

    private func currentLocation() async throws -> CLLocation {
        // `locationServicesEnabled()` can block, so Apple warns against calling it on the main
        // thread; hop off the main actor for the check.
        let servicesEnabled = await Task.detached { CLLocationManager.locationServicesEnabled() }.value
        guard servicesEnabled else {
            throw DeviceWeatherError.locationServicesDisabled
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            try await requestAuthorization()
        case .restricted, .denied:
            throw DeviceWeatherError.locationPermissionDenied
        case .authorizedAlways, .authorizedWhenInUse:
            break
        @unknown default:
            throw DeviceWeatherError.locationPermissionDenied
        }

        if let recentLocation = locationManager.location,
           abs(recentLocation.timestamp.timeIntervalSinceNow) < cacheDuration {
            return recentLocation
        }

        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation?.resume(throwing: DeviceWeatherError.locationUnavailable)
            locationContinuation = continuation
            locationManager.requestLocation()
        }
    }

    private func requestAuthorization() async throws {
        try await withCheckedThrowingContinuation { continuation in
            authorizationContinuation?.resume(throwing: DeviceWeatherError.locationPermissionDenied)
            authorizationContinuation = continuation
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func fetchOpenMeteoConditions(for location: CLLocation) async throws -> DeviceConditions {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(location.coordinate.latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(location.coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            // Unix timestamps avoid any local-time / offset parsing ambiguity for sunrise/sunset.
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "auto")
        ]

        guard let url = components?.url else {
            throw DeviceWeatherError.invalidWeatherURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        guard let temperature = response.current?.temperature2m,
              let sunrise = response.daily?.sunrise.first,
              let sunset = response.daily?.sunset.first else {
            throw DeviceWeatherError.emptyWeatherResponse
        }

        return DeviceConditions(
            celsius: Int(temperature.rounded()),
            sunrise: Date(timeIntervalSince1970: sunrise),
            sunset: Date(timeIntervalSince1970: sunset),
            sourceName: "Open-Meteo"
        )
    }

    private func coordinateString(_ coordinate: CLLocationDegrees) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), coordinate)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        resolveAuthorization(for: manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            locationContinuation?.resume(throwing: DeviceWeatherError.locationUnavailable)
            locationContinuation = nil
            return
        }

        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    private func resolveAuthorization(for status: CLAuthorizationStatus) {
        guard let continuation = authorizationContinuation else { return }

        switch status {
        case .notDetermined:
            return
        case .authorizedAlways, .authorizedWhenInUse:
            continuation.resume()
        case .restricted, .denied:
            continuation.resume(throwing: DeviceWeatherError.locationPermissionDenied)
        @unknown default:
            continuation.resume(throwing: DeviceWeatherError.locationPermissionDenied)
        }

        authorizationContinuation = nil
    }
}
