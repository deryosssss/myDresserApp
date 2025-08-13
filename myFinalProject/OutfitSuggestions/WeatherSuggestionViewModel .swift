//
//  WeatherSuggestionViewModel .swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - WeatherWear API models

struct WeatherWearGarment: Decodable {
    let id: String?
    let clothing_type: String
    let usable_temperature_range: Int?
    let name: String?
    let is_precipitation_proof: Bool?
    let icon_path: String?
}

struct WeatherWearResponse: Decodable {
    let outfit: [WeatherWearGarment]
}

// MARK: - Simple client

final class WeatherWearClient {
    /// Replace with your real WeatherWear base URL if different.
    private let base = URL(string: "https://weatherwear.fly.dev")!
    var authToken: String? = nil

    func suggestOutfit(lat: Double, lon: Double) async throws -> WeatherWearResponse {
        var comps = URLComponents(url: base.appendingPathComponent("/outfit-suggestions"),
                                  resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(lat)),
            URLQueryItem(name: "longitude", value: String(lon))
        ]
        var req = URLRequest(url: comps.url!)
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(WeatherWearResponse.self, from: data)
    }
}

// MARK: - Card / candidate

struct WeatherOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind: WardrobeItem]

    var orderedItems: [WardrobeItem] {
        var arr: [WardrobeItem] = []
        if let d   = itemsByKind[.dress]     { arr.append(d) }
        if let t   = itemsByKind[.top]       { arr.append(t) }
        if let b   = itemsByKind[.bottom]    { arr.append(b) }
        if let o   = itemsByKind[.outerwear] { arr.append(o) }
        if let s   = itemsByKind[.shoes]     { arr.append(s) }
        if let bag = itemsByKind[.bag]       { arr.append(bag) }
        if let acc = itemsByKind[.accessory] { arr.append(acc) }
        return arr
    }

    static func == (lhs: WeatherOutfitCandidate, rhs: WeatherOutfitCandidate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - ViewModel

@MainActor
final class WeatherSuggestionViewModel: ObservableObject {
    // UI
    @Published var cards: [WeatherOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Header
    @Published var temperature: String
    @Published var icon: Image?
    @Published var currentDate: Date

    // Inputs
    let userId: String
    let lat: Double
    let lon: Double
    let isRaining: Bool

    private let client = WeatherWearClient()
    private let store  = ManualSuggestionStore() // reuse strict layer filters

    init(
        userId: String,
        lat: Double,
        lon: Double,
        isRaining: Bool,
        temperature: String = "--",
        icon: Image? = nil,
        date: Date = Date()
    ) {
        self.userId = userId
        self.lat = lat
        self.lon = lon
        self.isRaining = isRaining
        self.temperature = temperature
        self.icon = icon
        self.currentDate = date
    }

    // MARK: Data loading

    func loadInitial(count: Int = 2) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        cards.removeAll()

        for _ in 0..<count {
            if let c = await fetchOneCandidate() {
                cards.append(c)
            }
        }

        // Local fallback if API produced nothing
        if cards.isEmpty {
            for _ in 0..<count {
                if let c = await generateLocalCandidate() {
                    cards.append(c)
                }
            }
        }
    }

    func skip(_ cardID: WeatherOutfitCandidate.ID) async {
        cards.removeAll { $0.id == cardID }

        // Try API first, then local fallback
        if let api = await fetchOneCandidate() {
            cards.append(api)
            return
        }
        if let fallback = await generateLocalCandidate() {
            cards.append(fallback)
        }
    }

    // MARK: Save (after preview confirms)

    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {
        let uid = Auth.auth().currentUser?.uid ?? userId
        guard !uid.isEmpty else {
            errorMessage = "Please sign in."
            return
        }

        do {
            let itemIDs = items.compactMap { $0.id }
            let urls = items.map { $0.imageURL }
            let payload: [String: Any] = [
                "name": name,
                "description": description ?? "",
                "imageURL": urls.first ?? "",
                "itemImageURLs": urls,
                "itemIDs": itemIDs,
                "tags": [],
                "occasion": occasion ?? "",
                "wearCount": 0,
                "isFavorite": isFavorite,
                "source": "weather",
                "createdAt": FieldValue.serverTimestamp(),
                "date": date != nil ? Timestamp(date: date!) : FieldValue.serverTimestamp()
            ]

            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()

            try await ref.setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Private helpers

    private func fetchOneCandidate() async -> WeatherOutfitCandidate? {
        do {
            let resp = try await client.suggestOutfit(lat: lat, lon: lon)

            // Map weatherwear types -> your kinds
            let mappedKinds: [LayerKind] = resp.outfit.compactMap { g in
                switch g.clothing_type.lowercased() {
                case "shirt", "top": return .top
                case "outwear", "outerwear", "jacket", "coat": return .outerwear
                case "bottom": return .bottom
                case "dress": return .dress
                default: return nil
                }
            }

            var picked: [LayerKind: WardrobeItem] = [:]

            // Always include shoes; prefer boots if raining
            if let shoes = try await pickItem(kind: .shoes, preferBoots: isRaining) {
                picked[.shoes] = shoes
            }

            // Fill the base from API hints (dress OR top/bottom)
            for kind in mappedKinds {
                if let it = try await pickItem(kind: kind, preferBoots: false) {
                    picked[kind] = it
                }
            }

            // If API didn't give a base, build one locally
            if picked[.dress] == nil && (picked[.top] == nil || picked[.bottom] == nil) {
                if let dress = try await pickItem(kind: .dress, preferBoots: false) {
                    picked[.dress] = dress
                } else if
                    let top = try await pickItem(kind: .top, preferBoots: false),
                    let bottom = try await pickItem(kind: .bottom, preferBoots: false) {
                    picked[.top] = top
                    picked[.bottom] = bottom
                }
            }

            // Add optional layers (outerwear/bag/accessory) with probabilities,
            // keeping total item count between 2...5.
            picked = await addOptionals(to: picked)

            guard picked.isEmpty == false else { return nil }
            return WeatherOutfitCandidate(itemsByKind: picked)
        } catch {
            print("[WeatherSuggest] API error:", error)
            return nil
        }
    }

    /// Local fallback if API returns nothing: build Dress+Shoes if possible,
    /// otherwise Top+Bottom+Shoes; then add optional layers probabilistically.
    private func generateLocalCandidate() async -> WeatherOutfitCandidate? {
        var items: [LayerKind: WardrobeItem] = [:]

        // Shoes first (boots if raining)
        if let shoes = try? await pickItem(kind: .shoes, preferBoots: isRaining) {
            items[.shoes] = shoes
        }

        // Base: Dress OR Top+Bottom
        if let dress = try? await pickItem(kind: .dress, preferBoots: false) {
            items[.dress] = dress
        } else if
            let top = (try? await pickItem(kind: .top, preferBoots: false)),
            let bottom = (try? await pickItem(kind: .bottom, preferBoots: false)) {
            items[.top] = top
            items[.bottom] = bottom
        } else {
            return nil
        }

        // Optionals
        items = await addOptionals(to: items)

        return WeatherOutfitCandidate(itemsByKind: items)
    }

    /// Tries to add outerwear/bag/accessory with weather-aware probabilities
    /// while keeping total items in 2...5 range.
    private func addOptionals(to base: [LayerKind: WardrobeItem]) async -> [LayerKind: WardrobeItem] {
        var items = base
        let maxItems = 5
        let minItems = 2

        // Parse temperature (e.g. "23°C" -> 23)
        let tC = parsedTempC()

        // Outerwear probability: high if raining or chilly
        let outerwearP: Double = (isRaining || (tC ?? 99) <= 15) ? 0.8 : 0.35
        let bagP: Double = 0.5
        let accP: Double = 0.4

        // Outerwear
        if items.count < maxItems, items[.outerwear] == nil, coin(outerwearP),
           let coat = try? await pickItem(kind: .outerwear, preferBoots: false) {
            items[.outerwear] = coat
        }

        // Bag
        if items.count < maxItems, items[.bag] == nil, coin(bagP),
           let bag = try? await pickItem(kind: .bag, preferBoots: false) {
            items[.bag] = bag
        }

        // Accessory
        if items.count < maxItems, items[.accessory] == nil, coin(accP),
           let acc = try? await pickItem(kind: .accessory, preferBoots: false) {
            items[.accessory] = acc
        }

        // Ensure we never drop below min items (shouldn’t happen, but just in case)
        if items.count < minItems {
            if items[.bag] == nil, let bag = try? await pickItem(kind: .bag, preferBoots: false) {
                items[.bag] = bag
            }
        }

        return items
    }

    private func coin(_ p: Double) -> Bool {
        Double.random(in: 0...1) < max(0, min(1, p))
    }

    private func parsedTempC() -> Int? {
        // Extract optional leading minus and digits
        let filtered = temperature.unicodeScalars
            .filter { CharacterSet(charactersIn: "-0123456789").contains($0) }
        return Int(String(String.UnicodeScalarView(filtered)))
    }

    private func pickItem(kind: LayerKind, preferBoots: Bool) async throws -> WardrobeItem? {
        let items = try await store.fetchItems(userId: userId, for: kind, limit: 300)
        guard !items.isEmpty else { return nil }

        if kind == .shoes {
            let boots = items.filter {
                let c = ($0.category + " " + $0.subcategory).lowercased()
                return c.contains("boot")
            }
            if preferBoots, let b = boots.randomElement() {
                return b
            }
        }
        return items.randomElement()
    }
}
