//
//  MagicView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI
import CoreLocation
import UIKit

// MARK: - Weather Model

struct WeatherData: Codable {
    struct Main: Codable { let temp: Double }
    struct Weather: Codable { let icon: String }
    let main: Main
    let weather: [Weather]
}

// MARK: - ViewModel for Weather & Date

class MagicViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: String = "--°"
    @Published var icon: Image? = nil
    @Published var currentDate: Date = Date()
    @Published var weekDates: [Date] = []

    private let locationManager = CLLocationManager()
    private let apiKey: String = {
        let bundle = Bundle.main
        if let key = bundle.infoDictionary?["OpenWeatherMapAPIKey"] as? String,
           !key.isEmpty {
            return key
        } else {
            fatalError("⚠️ Missing OpenWeatherMapAPIKey in Info.plist")
        }
    }()

    override init() {
        super.init()
        generateWeekDates()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // 1) Ask for permission
        locationManager.requestWhenInUseAuthorization()
    }

    // 2) Called when user responds to the permission dialog
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Now that we have permission, request a one-off location
            manager.requestLocation()
        case .denied, .restricted:
            print("🛑 Location access denied or restricted")
        default:
            break
        }
    }

    // 3) Got a location → fetch weather
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        fetchWeather(lat: loc.coordinate.latitude,
                     lon: loc.coordinate.longitude)
    }

    // 4) Location error
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("❌ Location error:", error.localizedDescription)
    }

    private func fetchWeather(lat: Double, lon: Double) {
        guard let url = URL(string:
            "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&units=metric&appid=\(apiKey)"
        ) else { return }

        print("➡️ Fetching weather from URL:", url)

        URLSession.shared.dataTask(with: url) { data, resp, error in
            if let error = error {
                print("❌ Weather request failed:", error.localizedDescription)
                return
            }
            guard let data = data else {
                print("❌ No data returned from weather API")
                return
            }
            do {
                let decoded = try JSONDecoder().decode(WeatherData.self, from: data)
                DispatchQueue.main.async {
                    let temp = Int(round(decoded.main.temp))
                    self.temperature = "\(temp)°C"
                    if let iconCode = decoded.weather.first?.icon {
                        self.loadIcon(code: iconCode)
                    }
                }
            } catch {
                print("❌ JSON decode error:", error)
            }
        }.resume()
    }

    private func loadIcon(code: String) {
        let iconURL = URL(string:
            "https://openweathermap.org/img/wn/\(code)@2x.png"
        )!
        URLSession.shared.dataTask(with: iconURL) { data, _, error in
            if let error = error {
                print("❌ Icon load error:", error.localizedDescription)
                return
            }
            guard let data = data,
                  let uiImage = UIImage(data: data) else {
                print("❌ Icon data invalid")
                return
            }
            DispatchQueue.main.async {
                self.icon = Image(uiImage: uiImage)
            }
        }.resume()
    }

    private func generateWeekDates() {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                          from: today)
        ) ?? today

        weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
}

// MARK: - MagicView

struct MagicView: View {
    @StateObject private var vm = MagicViewModel()
    @State private var selectedDate: Date? = nil

    var body: some View {
        VStack(spacing: 16) {
            // Weather + Date
            HStack(spacing: 12) {
                if let icon = vm.icon {
                    icon
                        .resizable()
                        .frame(width: 50, height: 50)
                }
                VStack(alignment: .leading) {
                    Text(vm.temperature)
                        .font(.largeTitle)
                        .bold()
                    Text(vm.currentDate, formatter: dateFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Week calendar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.weekDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(
                            date,
                            inSameDayAs: selectedDate ?? vm.currentDate
                        )
                        VStack {
                            Text(weekdayFormatter.string(from: date))
                                .font(.caption)
                            Text(dayFormatter.string(from: date))
                                .font(.headline)
                        }
                        .padding(8)
                        .background(isSelected
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear)
                        .cornerRadius(8)
                        .onTapGesture {
                            selectedDate = date
                        }
                    }
                }
                .padding(.horizontal)
            }

            // Four options grid
            LazyVGrid(columns: [GridItem(), GridItem()],
                      spacing: 16) {
                OptionButton(title: "Weather Outfit",
                             systemImage: "cloud.sun") {
                    // action
                }
                OptionButton(title: "Dresscode Outfit",
                             systemImage: "tshirt") {
                    // action
                }
                OptionButton(title: "Prompt Outfit",
                             systemImage: "brain.head.profile") {
                    // action
                }
                OptionButton(title: "Manual Outfit",
                             systemImage: "pencil") {
                    // action
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    // MARK: – Formatters

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }
    private var weekdayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }
    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }
}

// MARK: - Option Button

struct OptionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                Text(title)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}


