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
    
    /// GET /outfit-suggestions?latitude=...&longitude=...
    /// Returns a list of garments suited for current weather at the provided coords.
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
// A single suggested outfit: one item per logical "layer".

struct WeatherOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind: WardrobeItem]
    /// Dress code “locked” for this recommendation (helps debugging / UI later)
    var dressCode: String?

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
// Orchestrates weather-aware outfit suggestions, now with DRESS CODE COHESION:
// - We “lock” a dress code from the first meaningful item (dress or top/bottom)
// - Every subsequent pick is filtered to that same dress code
// - If none has a dress code, we fall back gracefully

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
    private let store  = ManualSuggestionStore()

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

    /// Removes a card and fetches a replacement (API first, then local).
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
    /// Persists the chosen outfit to Firestore under the user's document.

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
            var targetDressCode: String? = nil

            // ====== BASE FIRST (seed the dress code) ======
            if mappedKinds.contains(.dress) {
                if let dress = try await pickItem(kind: .dress, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.dress] = dress
                }
            } else {
                // Try top + bottom as base
                if let top = try await pickItem(kind: .top, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.top] = top
                }
                if let bottom = try await pickItem(kind: .bottom, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.bottom] = bottom
                }
            }

            // If we still don't have a base, abandon this API try
            if picked[.dress] == nil && (picked[.top] == nil || picked[.bottom] == nil) {
                return nil
            }

            // ====== SHOES (respect dress code; prefer boots if raining) ======
            if let shoes = try await pickItem(kind: .shoes, lockingDressCode: &targetDressCode, preferBoots: isRaining) {
                picked[.shoes] = shoes
            }

            // ====== Additional layers (still locking dress code) ======
            picked = await addOptionals(to: picked, lockingDressCode: &targetDressCode)

            guard picked.isEmpty == false else { return nil }
            return WeatherOutfitCandidate(itemsByKind: picked, dressCode: targetDressCode)
        } catch {
            print("[WeatherSuggest] API error:", error)
            return nil
        }
    }

    /// Local fallback if API returns nothing: build Dress+Shoes if possible,
    /// otherwise Top+Bottom+Shoes; then add optional layers probabilistically.
    /// Dress code cohesion is enforced by locking the first base item's dress code.
    private func generateLocalCandidate() async -> WeatherOutfitCandidate? {
        var items: [LayerKind: WardrobeItem] = [:]
        var targetDressCode: String? = nil

        // Base: Dress OR Top+Bottom (seed dress code here)
        if let dress = try? await pickItem(kind: .dress, lockingDressCode: &targetDressCode, preferBoots: false) {
            items[.dress] = dress
        } else {
            if let top = try? await pickItem(kind: .top, lockingDressCode: &targetDressCode, preferBoots: false) {
                items[.top] = top
            }
            if let bottom = try? await pickItem(kind: .bottom, lockingDressCode: &targetDressCode, preferBoots: false) {
                items[.bottom] = bottom
            }
            // If we couldn't form a base, bail
            if items[.dress] == nil && (items[.top] == nil || items[.bottom] == nil) {
                return nil
            }
        }

        // Shoes (respect current target dress code; prefer boots if raining)
        if let shoes = try? await pickItem(kind: .shoes, lockingDressCode: &targetDressCode, preferBoots: isRaining) {
            items[.shoes] = shoes
        }

        // Optionals (respect locked dress code)
        items = await addOptionals(to: items, lockingDressCode: &targetDressCode)

        return WeatherOutfitCandidate(itemsByKind: items, dressCode: targetDressCode)
    }

    /// Tries to add outerwear/bag/accessory with weather-aware probabilities
    /// while keeping total items in 2...5 range and **respecting the locked dress code**.
    private func addOptionals(to base: [LayerKind: WardrobeItem],
                              lockingDressCode targetDressCode: inout String?) async -> [LayerKind: WardrobeItem] {
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
           let coat = try? await pickItem(kind: .outerwear, lockingDressCode: &targetDressCode, preferBoots: false) {
            items[.outerwear] = coat
        }

        // Bag
        if items.count < maxItems, items[.bag] == nil, coin(bagP),
           let bag = try? await pickItem(kind: .bag, lockingDressCode: &targetDressCode, preferBoots: false) {
            items[.bag] = bag
        }

        // Accessory
        if items.count < maxItems, items[.accessory] == nil, coin(accP),
           let acc = try? await pickItem(kind: .accessory, lockingDressCode: &targetDressCode, preferBoots: false) {
            items[.accessory] = acc
        }

        // Ensure we never drop below min items (shouldn’t happen, but just in case)
        if items.count < minItems {
            if items[.bag] == nil, let bag = try? await pickItem(kind: .bag, lockingDressCode: &targetDressCode, preferBoots: false) {
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

    // MARK: Dress-code-aware picker
    /// Pulls items for a layer kind and filters them to the locked dress code (if any).
    /// If dress code is not yet locked, it will **lock** to the first picked non-empty one.
    private func pickItem(kind: LayerKind,
                          lockingDressCode targetDressCode: inout String?,
                          preferBoots: Bool) async throws -> WardrobeItem? {
        let all = (try? await store.fetchItems(userId: userId, for: kind, limit: 300)) ?? []
        guard !all.isEmpty else { return nil }

        let trimmedDC = targetDressCode?.ci

        // 1) If we already locked a dress code, filter to it
        var candidates: [WardrobeItem]
        if let dc = trimmedDC, !dc.isEmpty {
            candidates = all.filter { !$0.dressCode.ci.isEmpty && $0.dressCode.ci == dc }
            // If we have zero candidates, relax to items with empty dress code (neutral)
            if candidates.isEmpty {
                candidates = all.filter { $0.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            // Still none? As a last resort, allow any (to avoid no-suggestion dead ends)
            if candidates.isEmpty {
                candidates = all
            }
        } else {
            // No lock yet: prefer items that actually specify a dress code, else any
            let withDC = all.filter { !$0.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            candidates = withDC.isEmpty ? all : withDC
        }

        // Shoes: if rain preference is on, bias toward boots (still respecting dress code filter above)
        if kind == .shoes, preferBoots {
            let boots = candidates.filter {
                let c = ($0.category + " " + $0.subcategory).ci
                return c.contains("boot")
            }
            if let b = boots.randomElement() {
                // Lock dress code if needed
                if targetDressCode?.isEmpty ?? true, !b.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    targetDressCode = b.dressCode
                }
                return b
            }
        }

        guard let pick = candidates.randomElement() else { return nil }

        // Lock dress code if we haven't yet and this item has one
        if targetDressCode?.isEmpty ?? true {
            let dc = pick.dressCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if !dc.isEmpty { targetDressCode = dc }
        }
        return pick
    }
}
