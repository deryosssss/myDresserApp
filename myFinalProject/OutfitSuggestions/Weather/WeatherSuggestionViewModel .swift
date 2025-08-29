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
// These mirror the remote API so we can decode JSON directly into Swift types.
struct WeatherWearGarment: Decodable {
    let id: String?
    let clothing_type: String            // e.g. "top", "bottom", "outerwear", "dress"
    let usable_temperature_range: Int?
    let name: String?
    let is_precipitation_proof: Bool?
    let icon_path: String?
}

struct WeatherWearResponse: Decodable {
    let outfit: [WeatherWearGarment]     // list of garments API recommends for the weather
}

// MARK: - Simple client
// Minimal async client around `URLSession`. Keeps concerns separate from the ViewModel.
final class WeatherWearClient {
    /// Replace with your real WeatherWear base URL if different.
    private let base = URL(string: "https://weatherwear.fly.dev")!
    var authToken: String? = nil
    
    /// GET /outfit-suggestions?latitude=...&longitude=...
    /// Returns garments suited for current weather at the provided coords.
    func suggestOutfit(lat: Double, lon: Double) async throws -> WeatherWearResponse {
        // Build URL with query items (safer than string concatenation).
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

        // Async/await URLSession call. Throws on networking errors.
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Decode once we know we got a 2xx response.
        return try JSONDecoder().decode(WeatherWearResponse.self, from: data)
    }
}

// MARK: - Card / candidate
// A single suggested outfit: one item per logical "layer".
struct WeatherOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind: WardrobeItem]   // chosen pieces keyed by layer
    /// Dress code “locked” for this recommendation (used for cohesion/explanations)
    var dressCode: String?

    /// Stable thumbnail order for cleaner UI.
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
        lhs.id == rhs.id // identity-based equality for ForEach diffing
    }
}

// MARK: - ViewModel
// Weather-aware suggestions with **dress code cohesion**:
// 1) Pick a base (dress OR top+bottom) and “lock” its dress code.
// 2) All subsequent picks are filtered to that dress code if possible.
// 3) If no items specify a dress code, we gracefully fall back instead of failing.
@MainActor
final class WeatherSuggestionViewModel: ObservableObject {
    // UI-facing state
    @Published var cards: [WeatherOutfitCandidate] = [] // current deck of suggestions
    @Published var isLoading = false                    // spinner flag
    @Published var errorMessage: String? = nil          // alert message

    // Header (bound into the view)
    @Published var temperature: String                  // e.g., "21°C"
    @Published var icon: Image?                         // optional weather icon
    @Published var currentDate: Date

    // Inputs/context
    let userId: String
    let lat: Double
    let lon: Double
    let isRaining: Bool

    // Dependencies
    private let client = WeatherWearClient()            // remote API (first try)
    private let store  = ManualSuggestionStore()        // local Firestore-backed item repo

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

    /// Builds an initial set of cards. Tries API first; if none, falls back to local generation.
    func loadInitial(count: Int = 2) async {
        guard !isLoading else { return } // avoid overlapping fetches
        isLoading = true
        defer { isLoading = false }

        cards.removeAll()

        // First pass: ask the external API for `count` candidates.
        for _ in 0..<count {
            if let c = await fetchOneCandidate() {
                cards.append(c)
            }
        }

        // Fallback: if API produced nothing, synthesize locally from your wardrobe.
        if cards.isEmpty {
            for _ in 0..<count {
                if let c = await generateLocalCandidate() {
                    cards.append(c)
                }
            }
        }
    }

    /// Remove a card and replace it (tries API; falls back to local).
    func skip(_ cardID: WeatherOutfitCandidate.ID) async {
        cards.removeAll { $0.id == cardID }

        if let api = await fetchOneCandidate() {
            cards.append(api)
            return
        }
        if let fallback = await generateLocalCandidate() {
            cards.append(fallback)
        }
    }

    // MARK: Save (after preview confirms)
    /// Persists the chosen outfit under `/users/{uid}/outfits/{doc}` in Firestore.
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
            // Minimal schema; cover image is the first item’s URL.
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

            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()
                .setData(payload)

            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Private helpers

    /// Tries to build ONE candidate from the WeatherWear API response,
    /// while locking and respecting a dress code across picks.
    private func fetchOneCandidate() async -> WeatherOutfitCandidate? {
        do {
            let resp = try await client.suggestOutfit(lat: lat, lon: lon)

            // Map remote types to local LayerKind (guard against unknown values).
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
            var targetDressCode: String? = nil // gets set by the first base pick

            // ====== BASE FIRST (seed the dress code) ======
            if mappedKinds.contains(.dress) {
                // If API suggests a dress, try that path first.
                if let dress = try await pickItem(kind: .dress, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.dress] = dress
                }
            } else {
                // Else go for top + bottom as a base.
                if let top = try await pickItem(kind: .top, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.top] = top
                }
                if let bottom = try await pickItem(kind: .bottom, lockingDressCode: &targetDressCode, preferBoots: false) {
                    picked[.bottom] = bottom
                }
            }

            // If no base formed, abandon this attempt gracefully.
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
            // We swallow API errors here and let the caller fall back to local generation.
            print("[WeatherSuggest] API error:", error)
            return nil
        }
    }

    /// Local fallback: build Dress+Shoes if possible; else Top+Bottom+Shoes.
    /// Dress code cohesion is enforced the same way as the API path.
    private func generateLocalCandidate() async -> WeatherOutfitCandidate? {
        var items: [LayerKind: WardrobeItem] = [:]
        var targetDressCode: String? = nil

        // Base (seed dress code here).
        if let dress = try? await pickItem(kind: .dress, lockingDressCode: &targetDressCode, preferBoots: false) {
            items[.dress] = dress
        } else {
            if let top = try? await pickItem(kind: .top, lockingDressCode: &targetDressCode, preferBoots: false) {
                items[.top] = top
            }
            if let bottom = try? await pickItem(kind: .bottom, lockingDressCode: &targetDressCode, preferBoots: false) {
                items[.bottom] = bottom
            }
            // If base still missing, bail.
            if items[.dress] == nil && (items[.top] == nil || items[.bottom] == nil) {
                return nil
            }
        }

        // Shoes (prefer boots in rain).
        if let shoes = try? await pickItem(kind: .shoes, lockingDressCode: &targetDressCode, preferBoots: isRaining) {
            items[.shoes] = shoes
        }

        // Optionals with probabilities guided by weather.
        items = await addOptionals(to: items, lockingDressCode: &targetDressCode)

        return WeatherOutfitCandidate(itemsByKind: items, dressCode: targetDressCode)
    }

    /// Adds outerwear/bag/accessory with weather-aware probabilities,
    /// keeps total items in 2...5, and **respects the locked dress code**.
    private func addOptionals(to base: [LayerKind: WardrobeItem],
                              lockingDressCode targetDressCode: inout String?) async -> [LayerKind: WardrobeItem] {
        var items = base
        let maxItems = 5
        let minItems = 2

        // Parse numeric °C out of a string like "23°C".
        let tC = parsedTempC()

        // Heuristics: if it's raining or ≤15°C, outerwear is more likely.
        let outerwearP: Double = (isRaining || (tC ?? 99) <= 15) ? 0.8 : 0.35
        let bagP: Double = 0.5
        let accP: Double = 0.4

        // Outerwear (if space left)
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

        // Ensure we never end up with fewer than 2 items (defensive).
        if items.count < minItems {
            if items[.bag] == nil, let bag = try? await pickItem(kind: .bag, lockingDressCode: &targetDressCode, preferBoots: false) {
                items[.bag] = bag
            }
        }

        return items
    }

    /// Bernoulli helper for randomized optional layers.
    private func coin(_ p: Double) -> Bool {
        Double.random(in: 0...1) < max(0, min(1, p))
    }

    /// Extracts a signed integer from `temperature` (e.g., "−2°C" → -2).
    private func parsedTempC() -> Int? {
        // Keep only digits and a leading minus, then parse.
        let filtered = temperature.unicodeScalars
            .filter { CharacterSet(charactersIn: "-0123456789").contains($0) }
        return Int(String(String.UnicodeScalarView(filtered)))
    }

    // MARK: Dress-code-aware picker
    /// Fetches items for a layer and filters to the locked dress code (if any).
    /// If the lock isn’t set yet, the first picked item with a non-empty dress code **locks** it.
    /// - Note: `.ci` is assumed to be a String extension that lowercases & trims (case-insensitive compare).
    private func pickItem(kind: LayerKind,
                          lockingDressCode targetDressCode: inout String?,
                          preferBoots: Bool) async throws -> WardrobeItem? {
        // Pull bucket from Firestore (already filtered by category via ManualSuggestionStore).
        let all = (try? await store.fetchItems(userId: userId, for: kind, limit: 300)) ?? []
        guard !all.isEmpty else { return nil }

        let trimmedDC = targetDressCode?.ci

        // 1) If a dress code is already locked, prefer items that match it.
        var candidates: [WardrobeItem]
        if let dc = trimmedDC, !dc.isEmpty {
            // Strict match first.
            candidates = all.filter { !$0.dressCode.ci.isEmpty && $0.dressCode.ci == dc }
            // If none, allow “neutral” (empty) dress code.
            if candidates.isEmpty {
                candidates = all.filter { $0.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            // Still none? Last resort: any items to avoid dead ends.
            if candidates.isEmpty {
                candidates = all
            }
        } else {
            // No lock yet: prefer items that actually declare a dress code so we can lock to it.
            let withDC = all.filter { !$0.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            candidates = withDC.isEmpty ? all : withDC
        }

        // 2) Special bias: if we're picking shoes and it's raining, try boots first.
        if kind == .shoes, preferBoots {
            let boots = candidates.filter {
                let c = ($0.category + " " + $0.subcategory).ci
                return c.contains("boot")
            }
            if let b = boots.randomElement() {
                // Lock dress code from this pick if we haven't yet.
                if targetDressCode?.isEmpty ?? true, !b.dressCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    targetDressCode = b.dressCode
                }
                return b
            }
        }

        // 3) Random pick among filtered candidates (keeps variety across cards).
        guard let pick = candidates.randomElement() else { return nil }

        // 4) If still unlocked and this item has a dress code, lock it for the rest of the build.
        if targetDressCode?.isEmpty ?? true {
            let dc = pick.dressCode.trimmingCharacters(in: .whitespacesAndNewlines)
            if !dc.isEmpty { targetDressCode = dc }
        }
        return pick
    }
}
