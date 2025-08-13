//
//  MagicViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - OpenWeather DTO
struct WeatherData: Codable {
    struct Main: Codable { let temp: Double }
    struct Weather: Codable {
        let id: Int           // e.g. 500 = light rain, 800 = clear sky
        let icon: String      // e.g. "10d"
    }
    let main: Main
    let weather: [Weather]
}

@MainActor
final class MagicViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published (UI-facing)

    // Weather
    @Published var temperature: String = "--°C"
    @Published var icon: Image? = nil
    @Published var isRaining: Bool = false

    // Location
    @Published var latitude: Double? = nil
    @Published var longitude: Double? = nil

    // Dates
    @Published var currentDate: Date = Date()
    @Published var weekDates: [Date] = []

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // Prevent heavy work in previews
    private let isRunningInPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    // Read API key without crashing if missing
    private var apiKey: String? {
        Bundle.main.infoDictionary?["OpenWeatherMapAPIKey"] as? String
    }

    // MARK: - Init

    override init() {
        super.init()
        generateWeekDates()

        // Preview stub (no networking/CL)
        if isRunningInPreviews {
            temperature = "23°C"
            icon = Image(systemName: "cloud.sun.fill")
            isRaining = false
            latitude = 51.5074
            longitude = -0.1278
            return
        }

        // Location setup
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Public helpers

    func refreshWeatherIfPossible() {
        guard let lat = latitude, let lon = longitude else {
            locationManager.requestLocation()
            return
        }
        fetchWeather(lat: lat, lon: lon)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !isRunningInPreviews else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isRunningInPreviews else { return }
        guard let loc = locations.first else { return }
        latitude = loc.coordinate.latitude
        longitude = loc.coordinate.longitude
        fetchWeather(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !isRunningInPreviews else { return }
        print("❌ Location error:", error.localizedDescription)
    }

    // MARK: - Weather

    private func fetchWeather(lat: Double, lon: Double) {
        guard let key = apiKey, !key.isEmpty else {
            print("⚠️ OpenWeatherMapAPIKey missing in Info.plist — skipping fetch.")
            return
        }
        guard let url = URL(string:
            "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&units=metric&appid=\(key)"
        ) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error { print("❌ Weather request failed:", error.localizedDescription); return }
            guard let data = data else { print("❌ No data from weather API"); return }

            do {
                let decoded = try JSONDecoder().decode(WeatherData.self, from: data)
                Task { @MainActor in
                    let t = Int(round(decoded.main.temp))
                    self?.temperature = "\(t)°C"

                    // Precipitation (rain/snow/drizzle/thunderstorm) via weather code ranges
                    let code = decoded.weather.first?.id ?? 0
                    self?.isRaining = Self.isPrecipitating(code)

                    if let iconCode = decoded.weather.first?.icon {
                        self?.loadIcon(code: iconCode)
                    }
                }
            } catch {
                print("❌ JSON decode error:", error)
            }
        }.resume()
    }

    private func loadIcon(code: String) {
        guard let url = URL(string: "https://openweathermap.org/img/wn/\(code)@2x.png") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            if let error = error { print("❌ Icon load error:", error.localizedDescription); return }
            guard let data = data, let img = UIImage(data: data) else { print("❌ Icon data invalid"); return }
            Task { @MainActor in self?.icon = Image(uiImage: img) }
        }.resume()
    }

    /// OpenWeather code ranges:
    /// 2xx Thunderstorm, 3xx Drizzle, 5xx Rain, 6xx Snow  -> treat as precipitation
    private static func isPrecipitating(_ code: Int) -> Bool {
        switch code {
        case 200...299, 300...399, 500...599, 600...699: return true
        default: return false
        }
    }

    // MARK: - Week dates (Mon–Sun)

    private func generateWeekDates() {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        weekDates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        currentDate = today
    }
}
