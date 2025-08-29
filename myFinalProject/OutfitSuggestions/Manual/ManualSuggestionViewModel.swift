//
//  ManualSuggestionViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firestore Store
/// Thin data-access layer used by `ManualSuggestionViewModel`.
/// • Fetches items from Firestore, then filters them by `LayerKind`.
/// • Saves an outfit document composed from current selections.
/// Keeping I/O here keeps the VM small & testable.
struct ManualSuggestionStore {
    private let db = Firestore.firestore()

    /// Pulls recent items for a user, then locally filters to the requested `LayerKind`.
    /// (Fetching a large slice once and filtering client-side is simpler than many Firestore
    /// queries; we rely on lightweight token matching in `matches(_:for:)`.)
    func fetchItems(userId: String, for kind: LayerKind, limit: Int = 300) async throws -> [WardrobeItem] {
        let col = db.collection("users").document(userId).collection("items")
        let snapshot = try await col
            .order(by: "addedAt", descending: true)
            .limit(to: 1000)
            .getDocuments()

        let all: [WardrobeItem] = snapshot.documents.map { doc in
            mapItem(doc.data(), id: doc.documentID)
        }

        let filtered = all.filter { matches($0, for: kind) }
        return Array(filtered.prefix(limit))
    }

    /// Creates an outfit document with all the chosen items.
    func saveOutfit(
        userId: String,
        name: String,
        selections: [LayerSelection],
        itemsByLayer: [LayerKind: [WardrobeItem]],
        tags: [String] = [],
        occasion: String? = nil,
        description: String = "",
        createdOn: Date? = nil,
        isFavorite: Bool = false
    ) async throws -> String {

        // Resolve concrete WardrobeItem objects for each selected layer.
        let selectedItems: [WardrobeItem] = selections.compactMap { sel in
            guard let itemID = sel.itemID,
                  let arr = itemsByLayer[sel.kind] else { return nil }
            return arr.first(where: { $0.id == itemID })
        }

        // Flatten for Firestore payload.
        let itemIDs = selectedItems.compactMap { $0.id }
        let itemImageURLs = selectedItems.map { $0.imageURL }
        let coverURL = itemImageURLs.first ?? ""

        var payload: [String: Any] = [
            "name": name,
            "description": description,
            "occasion": occasion ?? "",
            "imageURL": coverURL,
            "itemImageURLs": itemImageURLs,
            "itemIDs": itemIDs,
            "tags": tags,
            "wearCount": 0,
            "isFavorite": isFavorite,
            "source": "manual",
            "createdAt": FieldValue.serverTimestamp(),
            "lastWorn": FieldValue.serverTimestamp()
        ]

        if let createdOn {
            payload["createdOn"] = Timestamp(date: createdOn)
        }

        // Write under /users/{uid}/outfits/{autoId}
        let ref = db.collection("users").document(userId).collection("outfits").document()
        try await ref.setData(payload)
        return ref.documentID
    }

    // MARK: - Private helpers

    /// Maps raw Firestore fields into `WardrobeItem`. Tolerant of missing keys.
    private func mapItem(_ data: [String: Any], id: String) -> WardrobeItem {
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

    /// Token-based classifier to decide which `LayerKind` an item belongs to.
    /// Uses simple `contains` checks on category + subcategory for resilience to messy taxonomy.
    private func matches(_ item: WardrobeItem, for kind: LayerKind) -> Bool {
        let cat = item.category.lowercased()
        let sub = item.subcategory.lowercased()

        func containsAny(_ needles: [String], in hay: String...) -> Bool {
            let joined = hay.joined(separator: " ")
            return needles.contains { joined.contains($0) }
        }

        // Core buckets (expandable as your taxonomy grows).
        let isDressLike  = containsAny(["dress", "gown", "jumpsuit", "overall"], in: cat, sub)
        let isTopLike    = containsAny(["top", "shirt", "blouse", "t-shirt", "tee", "sweater", "hoodie", "cardigan", "tank"], in: cat, sub)
        let isBottomLike = containsAny(
            ["bottom","pants","jeans","skirt","shorts","trouser","trousers"],
            in: cat, sub)
        let isShoeLike   = containsAny(["shoe", "shoes", "sneaker", "trainer", "boot", "boots", "sandal", "sandals", "loafer", "loafers", "footwear"], in: cat, sub)
        let isOuterWear  = containsAny(["jacket", "coat", "blazer", "outerwear", "parka"], in: cat, sub)
        let isBagLike    = containsAny(["bag", "handbag", "backpack", "tote", "crossbody", "purse", "wallet"], in: cat, sub)
        let isAccessory  = containsAny(["accessory", "belt", "scarf", "hat", "cap", "jewellery", "jewelry", "glove"], in: cat, sub)

        // Mutually-exclusive where it matters (avoid classifying shoes as tops, etc.).
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

// MARK: - ViewModel
/// Drives the Manual Outfit screen:
/// • Holds layer config (e.g., Top/Bottom/Shoes) and per-layer item sources/selections.
/// • Loads items in parallel per layer.
/// • Provides roll/randomize semantics that respect locked layers.
/// • Saves composed outfits via the Store.
@MainActor
final class ManualSuggestionViewModel: ObservableObject {

    @Published var layers: [LayerSelection]
    @Published var itemsByLayer: [LayerKind: [WardrobeItem]] = [:]
    @Published var selectedIndex: [LayerKind: Int] = [:]

    @Published var isSaving = false
    @Published var errorMessage: String? = nil

    let userId: String
    private let store = ManualSuggestionStore()

    /// Default preset is Top+Bottom+Shoes; caller can override by passing a custom kind list.
    init(userId: String, preset: [LayerKind] = [.top, .bottom, .shoes]) {
        self.userId = userId
        self.layers = preset.map { LayerSelection(kind: $0) }
    }

    /// Loads item sources for *all* current layers in parallel, then
    /// clamps/repairs the selected indices to stay in-range.
    func loadAll() async {
        let localStore = self.store
        let localUserId = self.userId
        let snapshotLayers = self.layers

        await withTaskGroup(of: (LayerKind, [WardrobeItem]).self) { group in
            for layer in snapshotLayers {
                let kind = layer.kind
                group.addTask {
                    let items = (try? await localStore.fetchItems(userId: localUserId, for: kind)) ?? []
                    return (kind, items)
                }
            }

            // Collect results into a single dictionary keyed by kind.
            var dict: [LayerKind: [WardrobeItem]] = [:]
            for await pair in group { dict[pair.0] = pair.1 }

            self.itemsByLayer = dict

            // Ensure each layer points to a valid selection (or nil when empty).
            for i in self.layers.indices {
                let kind = self.layers[i].kind
                let arr = dict[kind] ?? []

                guard !arr.isEmpty else {
                    self.selectedIndex[kind] = 0
                    self.layers[i].itemID = nil
                    continue
                }

                let current = self.selectedIndex[kind] ?? 0
                let idx = max(0, min(current, arr.count - 1)) // clamp to bounds
                self.selectedIndex[kind] = idx
                self.layers[i].itemID = arr[idx].id
            }
        }
    }

    /// Current concrete picks in *layer order* (used by the preview sheet).
    func selectedItems() -> [WardrobeItem] {
        layers.compactMap { sel in
            guard let idx = selectedIndex[sel.kind],
                  let arr = itemsByLayer[sel.kind],
                  arr.indices.contains(idx) else { return nil }
            return arr[idx]
        }
    }

    /// Applies a new preset (e.g., switching to Dress+Shoes) while
    /// preserving any existing layer state when possible.
    func applyPreset(_ preset: LayerPreset) {
        rebuildLayers(from: preset.kinds)
        Task { await loadAll() } // refresh sources for new kinds
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Rebuilds `layers` from a set of kinds:
    /// • Reuse existing `LayerSelection` for kinds that remain (keeps lock/selection).
    /// • Remove stale kinds from caches to avoid dangling state.
    private func rebuildLayers(from kinds: [LayerKind]) {
        var rebuilt: [LayerSelection] = []
        for k in kinds {
            if let old = layers.first(where: { $0.kind == k }) { rebuilt.append(old) }
            else { rebuilt.append(LayerSelection(kind: k)) }
        }
        let removedKinds = Set(layers.map(\.kind)).subtracting(kinds)
        for rk in removedKinds {
            itemsByLayer[rk] = nil
            selectedIndex[rk] = nil
        }
        layers = rebuilt
    }

    /// Toggles the “pin/lock” flag for a given layer (the carousel honors this by disabling scroll).
    func toggleLock(_ kind: LayerKind) {
        guard let i = layers.firstIndex(where: { $0.kind == kind }) else { return }
        layers[i].locked.toggle()
    }

    /// Selects a specific index for a layer and updates its selected item id.
    func select(kind: LayerKind, index: Int) {
        guard let arr = itemsByLayer[kind], arr.indices.contains(index) else { return }
        selectedIndex[kind] = index
        if let i = layers.firstIndex(where: { $0.kind == kind }) {
            layers[i].itemID = arr[index].id
        }
    }

    /// Randomizes only *unlocked* layers. Keeps UX snappy with animation and haptic feedback.
    func randomizeUnlocked() {
        for layer in layers where !layer.locked {
            guard let arr = itemsByLayer[layer.kind], !arr.isEmpty else { continue }
            let r = Int.random(in: 0..<arr.count)
            withAnimation(.easeInOut) {
                select(kind: layer.kind, index: r)
            }
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    /// Minimal validity rule for saving:
    /// • Shoes are always required
    /// • Either (Dress) OR (Top + Bottom)
    var isComplete: Bool {
        let kinds = Set(layers.map { $0.kind })
        guard kinds.contains(.shoes) else { return false }
        if kinds.contains(.dress) { return true }
        return kinds.contains(.top) && kinds.contains(.bottom)
    }

    /// Saves the composed outfit. Surfaces validation + errors to the View via `errorMessage`.
    func saveOutfit(
        name: String,
        occasion: String?,
        description: String,
        date: Date?,
        isFavorite: Bool,
        tags: [String] = []
    ) async {
        guard isComplete else {
            errorMessage = "Outfit incomplete (need Shoes + [Dress] or [Top & Bottom])."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await store.saveOutfit(
                userId: userId,
                name: name,
                selections: layers,
                itemsByLayer: itemsByLayer,
                tags: tags,
                occasion: occasion,
                description: description,
                createdOn: date,
                isFavorite: isFavorite
            )
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
