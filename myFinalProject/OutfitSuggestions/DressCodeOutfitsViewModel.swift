//
//  DressCodeOutfitsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//


import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Candidate model

struct DCOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind : WardrobeItem]

    var orderedItems: [WardrobeItem] {
        var arr: [WardrobeItem] = []
        if let d = itemsByKind[.dress] { arr.append(d) }
        if let t = itemsByKind[.top] { arr.append(t) }
        if let b = itemsByKind[.bottom] { arr.append(b) }
        if let o = itemsByKind[.outerwear] { arr.append(o) }
        if let s = itemsByKind[.shoes] { arr.append(s) }
        if let bag = itemsByKind[.bag] { arr.append(bag) }
        if let acc = itemsByKind[.accessory] { arr.append(acc) }
        return arr
    }

    static func == (lhs: DCOutfitCandidate, rhs: DCOutfitCandidate) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - ViewModel

@MainActor
final class DressCodeOutfitsViewModel: ObservableObject {
    // UI
    @Published var cards: [DCOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // Inputs
    let userId: String
    let dressCode: DressCodeOption

    // Buckets (filtered by dress code)
    private var byKind: [LayerKind: [WardrobeItem]] = [:]

    init(userId: String, dressCode: DressCodeOption) {
        self.userId = userId
        self.dressCode = dressCode
    }

    // MARK: Load

    func loadInitial(count: Int = 4) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await loadBuckets()
            cards.removeAll()

            // Generate several different combos
            for _ in 0..<count {
                if let c = makeRandomCandidate() {
                    cards.append(c)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func skip(_ id: DCOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }
        if let new = makeRandomCandidate() {
            cards.append(new)
        }
    }

    // MARK: Save (after preview confirms)

    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {
        guard let uid = Auth.auth().currentUser?.uid ?? Optional(userId) else {
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
                "source": "dresscode",
                "dressCode": dressCode.rawValue,
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

    // MARK: - Buckets

    private func loadBuckets() async throws {
        // Pull recent items for the user, raw
        let col = Firestore.firestore().collection("users").document(userId).collection("items")
        let snap = try await col.order(by: "addedAt", descending: true).limit(to: 1000).getDocuments()

        // Dress-code filter (case-insensitive "contains")
        let token = dressCode.token
        let all: [WardrobeItem] = snap.documents.map { doc in
            ManualSuggestionStoreMap.mapItem(doc.data(), id: doc.documentID)
        }.filter { item in
            let dc = item.dressCode.lowercased()
            return token.isEmpty || dc.contains(token)
        }

        // Strictly classify into kinds
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

    // MARK: - Build lots of variations

    /// Create a random outfit using available buckets; returns nil if not enough items.
    private func makeRandomCandidate() -> DCOutfitCandidate? {
        guard !(byKind[.shoes]?.isEmpty ?? true) else { return nil }

        // Two families: dress-based vs top+bottom-based
        let dressFamily = Bool.random()

        var picks: [LayerKind: WardrobeItem] = [:]

        if dressFamily, let d = byKind[.dress]?.randomElement() {
            picks[.dress] = d
            // shoes
            if let s = byKind[.shoes]?.randomElement() { picks[.shoes] = s }
            // 0–3 optional extras
            maybePick(.outerwear, into: &picks, probability: 0.6)
            maybePick(.bag,       into: &picks, probability: 0.5)
            maybePick(.accessory, into: &picks, probability: 0.5)
        } else {
            // Need both top & bottom
            guard let t = byKind[.top]?.randomElement(),
                  let b = byKind[.bottom]?.randomElement() else { return nil }
            picks[.top] = t
            picks[.bottom] = b
            if let s = byKind[.shoes]?.randomElement() { picks[.shoes] = s }
            maybePick(.outerwear, into: &picks, probability: 0.6)
            maybePick(.bag,       into: &picks, probability: 0.5)
            maybePick(.accessory, into: &picks, probability: 0.5)
        }

        guard picks[.shoes] != nil else { return nil }
        return DCOutfitCandidate(itemsByKind: picks)
    }

    private func maybePick(_ kind: LayerKind, into dict: inout [LayerKind: WardrobeItem], probability: Double) {
        guard Double.random(in: 0...1) < probability,
              let item = byKind[kind]?.randomElement() else { return }
        dict[kind] = item
    }
}

// MARK: - Helpers (shared with ManualSuggestion)

/// Mirror of ManualSuggestionStore.mapItem so we don't import the whole type here.
enum ManualSuggestionStoreMap {
    static func mapItem(_ data: [String: Any], id: String) -> WardrobeItem {
        let sourceStr = (data["sourceType"] as? String)?.lowercased() ?? WardrobeItem.SourceType.gallery.rawValue
        let src = WardrobeItem.SourceType(rawValue: sourceStr) ?? .gallery
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

/// STRICT category/subcategory matching (same spirit as ManualSuggestionStore.matches)
enum KindMatcher {
    static func matches(_ item: WardrobeItem, for kind: LayerKind) -> Bool {
        let cat = item.category.lowercased()
        let sub = item.subcategory.lowercased()

        func containsAny(_ needles: [String]) -> Bool {
            let hay = cat + " " + sub
            return needles.contains { hay.contains($0) }
        }

        let isDressLike  = containsAny(["dress", "gown", "jumpsuit", "overall"])
        let isTopLike    = containsAny(["top", "shirt", "blouse", "t-shirt", "tee", "sweater", "hoodie", "cardigan", "tank"])
        let isBottomLike = containsAny(["pants", "jeans", "skirt", "shorts", "trouser", "trousers", "leggings", "trackpants"])
        let isShoeLike   = containsAny(["shoe", "shoes", "sneaker", "trainer", "boot", "boots", "sandal", "sandals", "loafer", "loafers", "footwear"])
        let isOuterWear  = containsAny(["jacket", "coat", "blazer", "outerwear", "parka"])
        let isBagLike    = containsAny(["bag", "handbag", "backpack", "tote", "crossbody", "purse", "wallet"])
        let isAccessory  = containsAny(["accessory", "belt", "scarf", "hat", "cap", "jewellery", "jewelry", "glove"])

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
