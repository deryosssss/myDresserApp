//
//  DressCodeOutfitsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//

//  Purpose:
//  Generate outfit suggestions constrained by a selected dress code (e.g., Casual,
//  Smart Casual, Smart). It pulls the user’s wardrobe from Firestore, filters by
//  dress code, classifies items into LayerKind buckets, then builds several random
//  combinations (cards). Users can skip a card to get a new variation, or save a
//  chosen outfit back to Firestore.
//
//  Change (2025-08-22):
//  - Dress-code filtering is now *strict*. We canonicalise the stored string and
//    require equality with the selected option. This prevents "Smart Casual"
//    items from leaking into "Casual" results.

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Candidate model

/// One suggested outfit (one item per logical layer).
struct DCOutfitCandidate: Identifiable, Equatable {
    let id = UUID() // Stable unique ID so ForEach diffs correctly.
    /// Concrete picks by layer, e.g. [.top: tee, .bottom: jeans, .shoes: sneakers]
    var itemsByKind: [LayerKind : WardrobeItem]

    /// Stable display order for thumbnails in the UI:
    /// dress → top → bottom → outerwear → shoes → bag → accessory
    /// (Gives a consistent visual rhythm regardless of which layers are present.)
    var orderedItems: [WardrobeItem] {
        var arr: [WardrobeItem] = []
        if let d = itemsByKind[.dress]     { arr.append(d) }
        if let t = itemsByKind[.top]       { arr.append(t) }
        if let b = itemsByKind[.bottom]    { arr.append(b) }
        if let o = itemsByKind[.outerwear] { arr.append(o) }
        if let s = itemsByKind[.shoes]     { arr.append(s) }
        if let bag = itemsByKind[.bag]     { arr.append(bag) }
        if let acc = itemsByKind[.accessory] { arr.append(acc) }
        return arr
    }

    // Equatable by identity → cards replace cleanly in arrays.
    static func == (lhs: DCOutfitCandidate, rhs: DCOutfitCandidate) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - ViewModel

/// Builds dress-code-constrained outfit cards from the user's wardrobe.
@MainActor // Ensure all @Published mutations happen on the main thread (UI safety).
final class DressCodeOutfitsViewModel: ObservableObject {
    // UI state
    @Published var cards: [DCOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Inputs
    let userId: String
    let dressCode: DressCodeOption                 // selected dress code (e.g., .casual)

    // Buckets (items classified by LayerKind after loading & filtering by dress code).
    // Using a dictionary lets us sample quickly per layer.
    private var byKind: [LayerKind: [WardrobeItem]] = [:]

    init(userId: String, dressCode: DressCodeOption) {
        self.userId = userId
        self.dressCode = dressCode
    }

    // MARK: Load

    /// Loads wardrobe items filtered by dress code, then generates `count` random cards.
    /// Uses async/await so callers can `Task { await ... }` without blocking the UI.
    func loadInitial(count: Int = 4) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadBuckets()     
            cards.removeAll()

            // Generate several different combos. We try `count` times but only append
            // when we can actually build a valid candidate (e.g., shoes available).
            for _ in 0..<count {
                if let c = makeRandomCandidate() { cards.append(c) }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Removes the given card and appends one new random card (same dress-code context).
    /// Keeps the deck size roughly stable and the UI feeling responsive.
    func skip(_ id: DCOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }
        if let new = makeRandomCandidate() {
            cards.append(new)
        }
    }

    // MARK: Save (after preview confirms)

    /// Persists a selected outfit under `/users/{uid}/outfits/{doc}` in Firestore.
    /// Accepts the final list of items from the preview sheet to keep this VM decoupled from the view.
    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {
        // If Firebase user is present, prefer that UID; otherwise fall back to injected userId.
        // (Using `Optional(userId)` keeps the type as `String?` for the guard unwrap.)
        guard let uid = Auth.auth().currentUser?.uid ?? Optional(userId) else {
            errorMessage = "Please sign in."
            return
        }

        do {
            // Compose basic outfit document. Use the first image as the hero image.
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
                "source": "dresscode",
                "dressCode": dressCode.rawValue,
                "createdAt": FieldValue.serverTimestamp(),
                "date": date != nil ? Timestamp(date: date!) : FieldValue.serverTimestamp()
            ]

            // Write to Firestore (one new doc). Await makes this cancelable if the view disappears.
            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()

            try await ref.setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success) // small UX delight
        } catch {
            // Surface failure and notify haptically.
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Buckets

    /// Fetches up to 1000 recent wardrobe items, filters by dress code (STRICT),
    /// and strictly classifies them into LayerKind buckets.
    /// Splitting "load -> filter -> classify" makes this easy to unit test.
    private func loadBuckets() async throws {
        // Pull recent items for the user
        let col = Firestore.firestore()
            .collection("users").document(userId)
            .collection("items")
        let snap = try await col.order(by: "addedAt", descending: true)
                                .limit(to: 1000)
                                .getDocuments()

        // Canonical token from UI selection (e.g., "casual", "smart casual", "smart")
        let wanted = dressCode.token

        // Map → Strictly filter by canonical dress code → classify.
        let all: [WardrobeItem] = snap.documents
            // Local mapper keeps this VM independent from other stores and simplifies tests.
            .map { doc in ManualSuggestionStoreMap.mapItem(doc.data(), id: doc.documentID) }
            .filter { item in
                let norm = canonicalDressCode(item.dressCode)
                return wanted.isEmpty || norm == wanted
            }

        // Strictly classify into kinds using matcher (mutually exclusive families).
        var res: [LayerKind: [WardrobeItem]] = [:]
        for item in all {
            for k in LayerKind.allCases {
                if KindMatcher.matches(item, for: k) {
                    res[k, default: []].append(item)
                }
            }
        }
        byKind = res
    }

    /// Converts any free-text dress code into one of our canonical buckets:
    /// "smart casual", "smart", "casual" (lowercased).
    /// Order matters: we check "smart casual" first so it does NOT fall back to "casual".
    private func canonicalDressCode(_ raw: String) -> String {
        let s = normalized(raw)
        if s.contains("smart casual") { return "smart casual" }
        if s.contains("smart")        { return "smart" }
        if s.contains("casual")       { return "casual" }
        return s // unknown values pass through (won't match any known token)
    }

    /// Lowercases, removes diacritics/punctuation, collapses whitespace and hyphens.
    private func normalized(_ str: String) -> String {
        let base = str.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[-_]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[^a-z\\s]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base
    }

    // MARK: - Build lots of variations

    /// Create a random outfit using available buckets; returns nil if not enough items.
    /// Favors variety by randomly choosing between “dress family” and “top+bottom family”.
    private func makeRandomCandidate() -> DCOutfitCandidate? {
        // Require at least one pair of shoes (anchor item for completeness).
        guard !(byKind[.shoes]?.isEmpty ?? true) else { return nil }

        // Two families: dress-based vs top+bottom-based
        let dressFamily = Bool.random()

        var picks: [LayerKind: WardrobeItem] = [:]

        if dressFamily, let d = byKind[.dress]?.randomElement() {
            // Dress-based: dress + shoes + optional layers
            picks[.dress] = d
            if let s = byKind[.shoes]?.randomElement() { picks[.shoes] = s }
            // 0–3 optional extras with tuned probabilities for natural-looking sets.
            maybePick(.outerwear, into: &picks, probability: 0.6)
            maybePick(.bag,       into: &picks, probability: 0.5)
            maybePick(.accessory, into: &picks, probability: 0.5)
        } else {
            // Top+bottom-based: need both to proceed
            guard let t = byKind[.top]?.randomElement(),
                  let b = byKind[.bottom]?.randomElement() else { return nil }
            picks[.top] = t
            picks[.bottom] = b
            if let s = byKind[.shoes]?.randomElement() { picks[.shoes] = s }
            // Optional layers
            maybePick(.outerwear, into: &picks, probability: 0.6)
            maybePick(.bag,       into: &picks, probability: 0.5)
            maybePick(.accessory, into: &picks, probability: 0.5)
        }

        // Final sanity: must have shoes at minimum.
        guard picks[.shoes] != nil else { return nil }

        return DCOutfitCandidate(itemsByKind: picks)
    }

    /// Randomly inserts a layer (if available) based on a probability threshold.
    /// Separated for readability and easy probability tuning.
    private func maybePick(_ kind: LayerKind, into dict: inout [LayerKind: WardrobeItem], probability: Double) {
        guard Double.random(in: 0...1) < probability,
              let item = byKind[kind]?.randomElement() else { return }
        dict[kind] = item
    }
}

// MARK: - Helpers (shared with ManualSuggestion)

/// Mirror of ManualSuggestionStore.mapItem so we don't import the whole type here.
/// Translates Firestore document data into a WardrobeItem.
/// Keeping this local avoids tight coupling and makes it trivial to test with fake data.
enum ManualSuggestionStoreMap {
    static func mapItem(_ data: [String: Any], id: String) -> WardrobeItem {
        // Resolve source type (default to gallery).
        let sourceStr = (data["sourceType"] as? String)?.lowercased()
            ?? WardrobeItem.SourceType.gallery.rawValue
        let src = WardrobeItem.SourceType(rawValue: sourceStr) ?? .gallery

        // Build the model, mapping Firestore fields and providing sane defaults.
        // Using nil-coalescing keeps this resilient to older/partial documents.
        return WardrobeItem(
            id: data["id"] as? String ?? id,
            userId: data["userId"] as? String ?? "",
            imageURL: data["imageURL"] as? String ?? "",
            imagePath: data["imagePath"] as? String,
            category: (data["category"] as? String ?? ""),
            subcategory: (data["subcategory"] as? String ?? ""),
            length: data["length"] as? String ?? "",
            style: data["style"] as? String ?? "",
            designPattern: data["designPattern"] as? String ?? "",
            closureType: data["closureType"] as? String ?? "",
            fit: data["fit"] as? String ?? "",
            material: data["material"] as? String ?? "",
            fastening: data["fastening"] as? String,
            dressCode: data["dressCode"] as? String ?? "",
            season: data["season"] as? String ?? "",
            size: data["size"] as? String ?? "",
            colours: data["colours"] as? [String] ?? [],
            customTags: data["customTags"] as? [String] ?? [],
            moodTags: data["moodTags"] as? [String] ?? [],
            isFavorite: data["isFavorite"] as? Bool ?? false,
            sourceType: src,
            gender: data["gender"] as? String ?? "",
            addedAt: (data["addedAt"] as? Timestamp)?.dateValue(),
            lastWorn: (data["lastWorn"] as? Timestamp)?.dateValue()
        )
    }
}

/// STRICT category/subcategory matching (same spirit as ManualSuggestionStore.matches).
/// Looks at `category + subcategory` tokens to decide which LayerKind(s) the item belongs to.
/// Using keyword buckets keeps this robust to small taxonomy variations and easy to extend.
enum KindMatcher {
    static func matches(_ item: WardrobeItem, for kind: LayerKind) -> Bool {
        let cat = item.category.lowercased()
        let sub = item.subcategory.lowercased()

        // Case-insensitive contains on concatenated category/subcategory text.
        func containsAny(_ needles: [String]) -> Bool {
            let hay = cat + " " + sub
            return needles.contains { hay.contains($0) }
        }

        // Buckets for token matching; tune as your taxonomy evolves.
        let isDressLike  = containsAny(["dress", "gown", "jumpsuit", "overall"])
        let isTopLike    = containsAny(["top", "shirt", "blouse", "t-shirt", "tee", "sweater", "hoodie", "cardigan", "tank"])
        let isBottomLike = containsAny(["bottom", "bottoms", "pants","pant", "jeans","jean", "skirt", "shorts", "trouser", "trousers", "leggings", "trackpants"])
        let isShoeLike   = containsAny(["shoe", "shoes", "sneaker", "trainer", "boot", "boots", "sandal", "sandals", "loafer", "loafers", "footwear"])
        let isOuterWear  = containsAny(["jacket", "coat", "blazer", "outerwear", "parka"])
        let isBagLike    = containsAny(["bag", "handbag", "backpack", "tote", "crossbody", "purse", "wallet"])
        let isAccessory  = containsAny(["accessory", "belt", "scarf", "hat", "cap", "jewellery", "jewelry", "glove"])

        // Ensure the item strongly belongs to exactly these families.
        // This prevents, e.g., a “boots” item also being tagged as a bottom because of the word “short”.
        switch kind {
        case .shoes:     return isShoeLike   && !(isDressLike || isTopLike || isBottomLike)
        case .dress:     return isDressLike  && !(isShoeLike || isTopLike || isBottomLike)
        case .top:       return isTopLike    && !(isDressLike || isShoeLike || isBottomLike)
        case .bottom:    return isBottomLike && !(isDressLike || isShoeLike)
        case .outerwear: return isOuterWear  && !(isDressLike || isShoeLike)
        case .bag:       return isBagLike
        case .accessory: return isAccessory
        }
    }
}
