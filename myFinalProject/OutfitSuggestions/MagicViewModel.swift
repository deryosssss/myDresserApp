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

// MARK: - Weather DTO
struct WeatherData: Codable {
    struct Main: Codable { let temp: Double }
    struct Weather: Codable { let icon: String }
    let main: Main
    let weather: [Weather]
}

@MainActor
final class MagicViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    // Weather
    @Published var temperature: String = "--°C"
    @Published var icon: Image? = nil

    // Dates
    @Published var currentDate: Date = Date()
    @Published var weekDates: [Date] = []

    private let locationManager = CLLocationManager()

    // Prevent heavy work in previews
    private let isRunningInPreviews = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

    // Preview-safe API key (no fatalError)
    private var apiKey: String? {
        Bundle.main.infoDictionary?["OpenWeatherMapAPIKey"] as? String
    }

    override init() {
        super.init()
        generateWeekDates()

        // Short-circuit for previews: show mock weather & stop
        if isRunningInPreviews {
            temperature = "23°C"
            icon = Image(systemName: "cloud.sun.fill")
            return
        }

        // Location setup
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.requestWhenInUseAuthorization()
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
                    if let code = decoded.weather.first?.icon { self?.loadIcon(code: code) }
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

    // MARK: - Week dates (Mon–Sun)
    private func generateWeekDates() {
        let cal = Calendar.current
        let today = Date()
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
        weekDates = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
        currentDate = today
    }
}
