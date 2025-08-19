//
//  MagicViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//
//
//  - Requests location permission and a one-shot location fix
//  - Calls OpenWeather “current weather” for that coordinate
//  - Exposes temperature text, a weather icon image, and a simple rain flag
//  - Also computes the current week’s dates (Mon–Sun) for UI display
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - OpenWeather DTO

/// Minimal subset of OpenWeather's "Current Weather" response we care about.
struct WeatherData: Codable {
    struct Main: Codable { let temp: Double } // current temperature in °C (since we request units=metric)
    struct Weather: Codable {
        let id: Int      // condition code (e.g. 500 = light rain, 800 = clear)
        let icon: String // icon token (e.g. "10d") used to fetch a PNG
    }
    let main: Main
    let weather: [Weather]
}

@MainActor
final class MagicViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published (UI-facing)

    /// e.g. "21°C" (formatted string so UI can bind directly)
    @Published var temperature: String = "--°C"
    /// OpenWeather icon converted to a SwiftUI Image (optional while loading)
    @Published var icon: Image? = nil
    /// True if current condition implies precipitation (rain/snow/drizzle/thunderstorm)
    @Published var isRaining: Bool = false

    /// Last known latitude/longitude (nil until we have a fix or previews stub them)
    @Published var latitude: Double? = nil
    @Published var longitude: Double? = nil

    /// Current date (now) and the 7 dates for the current calendar week (Mon–Sun)
    @Published var currentDate: Date = Date()
    @Published var weekDates: [Date] = []

    // MARK: - Private

    /// Location manager for one-shot location requests.
    private let locationManager = CLLocationManager()

    /// Prevent side effects (location, networking) in Xcode canvas previews.
    private let isRunningInPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    /// OpenWeather API key read from Info.plist; nil if missing (we fail gracefully).
    private var apiKey: String? {
        Bundle.main.infoDictionary?["OpenWeatherMapAPIKey"] as? String
    }

    // MARK: - Init

    override init() {
        super.init()
        generateWeekDates() // seed current week + date immediately

        // In previews, short-circuit all IO and provide stable demo values.
        if isRunningInPreviews {
            temperature = "23°C"
            icon = Image(systemName: "cloud.sun.fill")
            isRaining = false
            latitude = 51.5074
            longitude = -0.1278
            return
        }

        // Configure Core Location and ask for foreground permission.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Public helpers

    /// If we already have coordinates, refresh weather; otherwise request a location first.
    func refreshWeatherIfPossible() {
        guard let lat = latitude, let lon = longitude else {
            locationManager.requestLocation() // triggers delegate callbacks
            return
        }
        fetchWeather(lat: lat, lon: lon)
    }

    // MARK: - CLLocationManagerDelegate

    /// Called whenever authorization changes (user accepted/denied, or app resumes).
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !isRunningInPreviews else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation() // ask for a single GPS/Wi-Fi fix
        default:
            break // do nothing; UI can show placeholders
        }
    }

    /// Receives one-shot location updates after `requestLocation()`.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isRunningInPreviews else { return }
        guard let loc = locations.first else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
    }

    /// Location errors (permissions denied, timeout, etc.) are logged for debugging.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !isRunningInPreviews else { return }
        print("❌ Location error:", error.localizedDescription)
    }

    // MARK: - Weather

    /// Fetches current weather from OpenWeather and updates published UI state.
    private func fetchWeather(lat: Double, lon: Double) {
        // Fail gracefully if the key is missing (avoid crash in dev).
        guard let key = apiKey, !key.isEmpty else {
            print("⚠️ OpenWeatherMapAPIKey missing in Info.plist — skipping fetch.")
            return
        }
        // Build the request URL (metric units for °C).
        guard let url = URL(string:
            "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&units=metric&appid=\(key)"
        ) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            // Network error path.
            if let error = error {
                print("❌ Weather request failed:", error.localizedDescription)
                return
            }
            guard let data = data else {
                print("❌ No data from weather API")
                return
            }

            do {
                // Decode + apply on main actor (since we update @Published properties).
                let decoded = try JSONDecoder().decode(WeatherData.self, from: data)
                Task { @MainActor in
                    // Format temperature like "23°C"
                    let t = Int(round(decoded.main.temp))
                    self?.temperature = "\(t)°C"

                    // Mark precipitation for codes in 2xx/3xx/5xx/6xx ranges.
                    let code = decoded.weather.first?.id ?? 0
                    self?.isRaining = Self.isPrecipitating(code)

                    // Kick off icon download if the response contained an icon code.
                    if let iconCode = decoded.weather.first?.icon {
                        self?.loadIcon(code: iconCode)
                    }
                }
            } catch {
                print("❌ JSON decode error:", error)
            }
        }.resume()
    }

    /// Downloads the PNG icon from OpenWeather and publishes it as a SwiftUI Image.
    private func loadIcon(code: String) {
        guard let url = URL(string: "https://openweathermap.org/img/wn/\(code)@2x.png") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error {
                print("❌ Icon load error:", error.localizedDescription)
                return
            }
            guard let data = data, let img = UIImage(data: data) else {
                print("❌ Icon data invalid")
                return
            }
            Task { @MainActor in self?.icon = Image(uiImage: img) }
        }.resume()
    }

    /// OpenWeather condition codes:
    /// 2xx Thunderstorm, 3xx Drizzle, 5xx Rain, 6xx Snow → treat as precipitation.
    private static func isPrecipitating(_ code: Int) -> Bool {
        switch code {
        case 200...299, 300...399, 500...599, 600...699: return true
        default: return false
        }
    }

    // MARK: - Week dates (Mon–Sun)

    /// Computes the Monday of the current week and builds an array of 7 dates (Mon–Sun).
    private func generateWeekDates() {
        let cal = Calendar.current
        let today = Date()
        // Start of ISO week (yearForWeekOfYear + weekOfYear yields the Monday for many locales).
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        weekDates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        currentDate = today
    }
}
