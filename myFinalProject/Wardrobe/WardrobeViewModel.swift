//  WardrobeViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
//

import Foundation
import Combine
import FirebaseFirestore

/// Abstraction over Firestore operations for both items and outfits.
protocol WardrobeDataService {
    /// Listen for real-time updates to all wardrobe items.
    func listen(
        _ callback: @escaping (Result<[WardrobeItem], Error>) -> Void
    ) -> ListenerRegistration

    /// Save a new wardrobe item document.
    func save(
        _ item: WardrobeItem,
        completion: @escaping (Result<Void, Error>) -> Void
    )

    /// Delete a wardrobe item document by its ID.
    func deleteItem(_ id: String)

    /// Update specific fields on a wardrobe item document.
    func updateItem(_ id: String, data: [String: Any])
}

class WardrobeViewModel: ObservableObject {
    // MARK: — Published state
    @Published var items: [WardrobeItem] = []
    @Published var favoriteIDs = Set<String>()
    @Published var outfitsByItem: [String: [Outfit]] = [:]
    @Published var error: Error?

    private let service: WardrobeDataService
    private var listener: ListenerRegistration?

    init(service: WardrobeDataService = WardrobeFirestoreService()) {
        self.service = service
        listener = service.listen { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newItems):
                    self?.items = newItems
                case .failure(let err):
                    self?.error = err
                }
            }
        }
    }

    deinit {
        listener?.remove()
    }

    // MARK: — WardrobeItem APIs

    /// Toggle favorite state for a wardrobe item.
    func toggleFavorite(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        let newVal = !favoriteIDs.contains(id)
        if newVal { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
        service.updateItem(id, data: ["isFavorite": newVal])
    }

    /// Delete a wardrobe item (and its outfits).
    func delete(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        items.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        outfitsByItem[id] = nil
        service.deleteItem(id)
    }

    /// Update a single field on an item by mutating and persisting.
    func updateItem(_ item: WardrobeItem, transform: (inout WardrobeItem) -> Void) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var copy = items[idx]
        transform(&copy)
        items[idx] = copy
        service.updateItem(id, data: copy.dictionary)
    }

    /// Add or remove from any of the item's array‐fields.
    func modifyList<Value: Equatable>(
        _ item: WardrobeItem,
        keyPath: WritableKeyPath<WardrobeItem, [Value]>,
        add: Value? = nil,
        remove: Value? = nil
    ) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var copy = items[idx]
        if let v = add, !copy[keyPath: keyPath].contains(v) {
            copy[keyPath: keyPath].append(v)
        }
        if let v = remove, let pos = copy[keyPath: keyPath].firstIndex(of: v) {
            copy[keyPath: keyPath].remove(at: pos)
        }
        items[idx] = copy
        service.updateItem(id, data: copy.dictionary)
    }

    // MARK: — Outfit storage

    /// Associate a list of outfits with a given item.
    func setOutfits(_ outfits: [Outfit], for item: WardrobeItem) {
        guard let id = item.id else { return }
        outfitsByItem[id] = outfits
    }

    /// Retrieve outfits associated with an item.
    func outfits(for item: WardrobeItem) -> [Outfit] {
        guard let id = item.id else { return [] }
        return outfitsByItem[id] ?? []
    }

    // MARK: — Outfit APIs

    func toggleFavorite(_ outfit: Outfit) {
        guard let oid = outfit.id else { return }
        for (itemID, arr) in outfitsByItem {
            var outfits = arr
            if let idx = outfits.firstIndex(where: { $0.id == oid }) {
                outfits[idx].isFavorite.toggle()
                outfitsByItem[itemID] = outfits
                return
            }
        }
    }

    func delete(_ outfit: Outfit) {
        guard let oid = outfit.id else { return }
        for (itemID, arr) in outfitsByItem {
            var outfits = arr
            if let idx = outfits.firstIndex(where: { $0.id == oid }) {
                outfits.remove(at: idx)
                outfitsByItem[itemID] = outfits
                return
            }
        }
    }

    func removeTag(_ outfit: Outfit, tag: String) {
        guard let oid = outfit.id else { return }
        for (itemID, arr) in outfitsByItem {
            var outfits = arr
            if let idx = outfits.firstIndex(where: { $0.id == oid }) {
                outfits[idx].tags.removeAll { $0 == tag }
                outfitsByItem[itemID] = outfits
                return
            }
        }
    }

    func updateTags(_ outfit: Outfit, newTags: [String]) {
        guard let oid = outfit.id else { return }
        for (itemID, arr) in outfitsByItem {
            var outfits = arr
            if let idx = outfits.firstIndex(where: { $0.id == oid }) {
                outfits[idx].tags = newTags
                outfitsByItem[itemID] = outfits
                return
            }
        }
    }

    // MARK: — Helpers

    /// Check if a wardrobe item is marked favorite.
    func isFavorite(_ item: WardrobeItem) -> Bool {
        guard let id = item.id else { return false }
        return favoriteIDs.contains(id)
    }
}
