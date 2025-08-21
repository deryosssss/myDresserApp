//
//  WardrobeViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025
//
//  1) Subscribes to wardrobe items from a data service (Firestore-backed) and exposes them to the UI.
//  2) Handles item mutations (toggle favorite, update fields, list edits, delete) and media replace (sync/async).
//  3) Listens to outfits globally and per-item; decodes/hydrates Outfit docs; supports favorite/tag edits (TODO persist).
//  4) Applies filters + sorting for the list view; manages listener lifecycle cleanly.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit

/// Abstraction over Firestore operations for both items and outfits.
protocol WardrobeDataService {
    func listen(_ callback: @escaping (Result<[WardrobeItem], Error>) -> Void) -> ListenerRegistration
    func save(_ item: WardrobeItem, completion: @escaping (Result<Void, Error>) -> Void)
    func deleteItem(_ id: String)
    func updateItem(_ id: String, data: [String: Any])
}

final class WardrobeViewModel: ObservableObject {
    // MARK: - Published state
    @Published var items: [WardrobeItem] = []                 // live items list
    @Published var favoriteIDs = Set<String>()                // quick favorite lookup

    // Per-item outfits (ItemDetailView)
    @Published var outfitsByItem: [String: [Outfit]] = [:]    // itemId → outfits

    // All outfits for Wardrobe → Outfits tab (drives usage/diversity)
    @Published var allOutfits: [Outfit] = []                  // global outfits feed

    @Published var error: Error?                              // surface async errors

    // Filters (sheet → list)
    @Published var filters: WardrobeFilters = .default        // user-selected filters/sort

    private let service: WardrobeDataService                  // Firestore-backed service
    private var itemsListener: ListenerRegistration?          // listener for items

    // Per-item listeners
    private var outfitListeners: [String: ListenerRegistration] = [:] // itemId → listener
    // Global listener
    private var allOutfitsListener: ListenerRegistration?     // listener for all outfits

    init(service: WardrobeDataService = WardrobeFirestoreService()) {
        self.service = service

        // Items
        itemsListener = service.listen { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newItems):
                    self?.items = newItems
                    self?.favoriteIDs = Set(newItems.filter { $0.isFavorite }.compactMap { $0.id }) // recompute favorites
                case .failure(let err):
                    self?.error = err
                }
            }
        }

        // All outfits
        startAllOutfitsListener() // begin global outfits feed
    }

    deinit {
        itemsListener?.remove()
        allOutfitsListener?.remove()
        outfitListeners.values.forEach { $0.remove() }
    }

    // MARK: - WardrobeItem APIs

    func toggleFavorite(_ item: WardrobeItem) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isFavorite.toggle()                                   // optimistic UI
        let newVal = items[idx].isFavorite
        if newVal { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
        service.updateItem(id, data: ["isFavorite": newVal])             // persist flag
    }

    func isFavorite(_ item: WardrobeItem) -> Bool {
        if let id = item.id, let latest = items.first(where: { $0.id == id }) {
            return latest.isFavorite                                      // read from source of truth
        }
        return item.isFavorite
    }

    func delete(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        items.removeAll { $0.id == id }                                   // optimistic removal
        favoriteIDs.remove(id)
        stopOutfitsListener(for: item)                                     // cleanup listener
        outfitsByItem[id] = nil
        service.deleteItem(id)                                             // best-effort delete
    }

    func updateItem(_ item: WardrobeItem, transform: (inout WardrobeItem) -> Void) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var copy = items[idx]
        transform(&copy)                                                   // mutate copy
        items[idx] = copy                                                  // update UI
        service.updateItem(id, data: copy.dictionary)                      // persist partial update
    }

    func modifyList<Value: Equatable>(
        _ item: WardrobeItem,
        keyPath: WritableKeyPath<WardrobeItem, [Value]>,
        add: Value? = nil,
        remove: Value? = nil
    ) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var copy = items[idx]
        if let v = add, !copy[keyPath: keyPath].contains(v) { copy[keyPath: keyPath].append(v) }
        if let v = remove, let pos = copy[keyPath: keyPath].firstIndex(of: v) { copy[keyPath: keyPath].remove(at: pos) }
        items[idx] = copy
        service.updateItem(id, data: copy.dictionary)                      // persist list change
    }

    // MARK: - Media

    func replacePhoto(_ item: WardrobeItem, with data: Data, contentType: String = "image/jpeg", fileExtension: String = "jpg") {
        guard let id = item.id else { return }
        let storage = Storage.storage()
        let path = "users/\(item.userId)/items/\(id)/primary.\(fileExtension)" // canonical path per item
        let ref  = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = contentType

        if let oldPath = item.imagePath, oldPath != path {
            storage.reference(withPath: oldPath).delete(completion: nil)       // best-effort cleanup
        }

        ref.putData(data, metadata: meta) { [weak self] _, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.error = error }
                return
            }
            ref.downloadURL { url, err in
                if let err {
                    DispatchQueue.main.async { self.error = err }
                    return
                }
                guard let url else { return }
                DispatchQueue.main.async {
                    if let idx = self.items.firstIndex(where: { $0.id == id }) {
                        self.items[idx].imageURL = url.absoluteString
                        self.items[idx].imagePath = path
                    }
                }
                self.service.updateItem(id, data: ["imageURL": url.absoluteString, "imagePath": path]) // persist fields
            }
        }
    }

    func replacePhotoAsync(_ item: WardrobeItem, with data: Data, contentType: String = "image/jpeg", fileExtension: String = "jpg") async throws {
        guard let id = item.id else { return }
        let storage = Storage.storage()
        let path = "users/\(item.userId)/items/\(id)/primary.\(fileExtension)"
        let ref  = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = contentType

        if let oldPath = item.imagePath, oldPath != path {
            try? await storage.reference(withPath: oldPath).delete()          // ignore if missing
        }

        _ = try await ref.putDataAsync(data, metadata: meta)                  // upload bytes
        let url = try await ref.downloadURL()                                 // fetch CDN URL

        await MainActor.run {
            if let idx = self.items.firstIndex(where: { $0.id == id }) {
                self.items[idx].imageURL = url.absoluteString
                self.items[idx].imagePath = path
            }
        }
        self.service.updateItem(id, data: ["imageURL": url.absoluteString, "imagePath": path]) // persist fields
    }

    // MARK: - Outfits (per-item for ItemDetailView)

    func setOutfits(_ outfits: [Outfit], for item: WardrobeItem) {
        guard let id = item.id else { return }
        outfitsByItem[id] = outfits                                         // inject preloaded outfits
    }

    func outfits(for item: WardrobeItem) -> [Outfit] {
        guard let id = item.id else { return [] }
        return outfitsByItem[id] ?? []
    }

    func toggleFavorite(_ outfit: Outfit) {
        guard let oid = outfit.id else { return }
        for (itemID, var arr) in outfitsByItem {
            if let idx = arr.firstIndex(where: { $0.id == oid }) {
                arr[idx].isFavorite.toggle()
                outfitsByItem[itemID] = arr
                break
            }
        }
        if let idx = allOutfits.firstIndex(where: { $0.id == oid }) {
            allOutfits[idx].isFavorite.toggle()
        }
        // TODO: persist outfit favorite flag to Firestore
    }

    func delete(_ outfit: Outfit) {
        guard let oid = outfit.id else { return }
        for (itemID, var arr) in outfitsByItem {
            if let idx = arr.firstIndex(where: { $0.id == oid }) {
                arr.remove(at: idx)
                outfitsByItem[itemID] = arr
                break
            }
        }
        allOutfits.removeAll { $0.id == oid }
        // TODO: delete outfit doc in Firestore
    }

    func removeTag(_ outfit: Outfit, tag: String) {
        guard let oid = outfit.id else { return }
        for (itemID, var arr) in outfitsByItem {
            if let idx = arr.firstIndex(where: { $0.id == oid }) {
                arr[idx].tags.removeAll { $0 == tag }
                outfitsByItem[itemID] = arr
                break
            }
        }
        if let idx = allOutfits.firstIndex(where: { $0.id == oid }) {
            allOutfits[idx].tags.removeAll { $0 == tag }
        }
        // TODO: persist tag removal to Firestore
    }

    func updateTags(_ outfit: Outfit, newTags: [String]) {
        guard let oid = outfit.id else { return }
        for (itemID, var arr) in outfitsByItem {
            if let idx = arr.firstIndex(where: { $0.id == oid }) {
                arr[idx].tags = newTags
                outfitsByItem[itemID] = arr
                break
            }
        }
        if let idx = allOutfits.firstIndex(where: { $0.id == oid }) {
            allOutfits[idx].tags = newTags
        }
        // TODO: persist tag update to Firestore
    }

    // MARK: - Outfits Firestore listeners (hydrated for itemIDs/createdAt)

    /// Live listener for all outfits of current user (drives Home/Stats usage & diversity)
    func startAllOutfitsListener() {
        guard let uid = Auth.auth().currentUser?.uid else {
            allOutfits = []
            return
        }
        allOutfitsListener?.remove()

        let q = Firestore.firestore()
            .collection("users")
            .document(uid)
            .collection("outfits")
            .order(by: "createdAt", descending: true)

        allOutfitsListener = q.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.error = error; self.allOutfits = [] }
                return
            }
            let arr: [Outfit] = snapshot?.documents.compactMap { doc in
                Self.decodeOutfit(from: doc)
            } ?? []
            DispatchQueue.main.async { self.allOutfits = arr }
        }
    }

    /// Listener for outfits that include a specific item (ItemDetailView)
    func startOutfitsListener(for item: WardrobeItem) {
        guard let itemId = item.id else { return }
        if outfitListeners[itemId] != nil { return }                          // avoid duplicates

        let query = Firestore.firestore()
            .collection("users")
            .document(item.userId)
            .collection("outfits")
            .whereField("itemIDs", arrayContains: itemId)

        let l = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }
            if let error {
                DispatchQueue.main.async { self.error = error }
                return
            }
            let outfits: [Outfit] = snapshot?.documents.compactMap { doc in
                Self.decodeOutfit(from: doc)
            } ?? []

            DispatchQueue.main.async {
                self.outfitsByItem[itemId] = outfits
            }
        }
        outfitListeners[itemId] = l
    }

    func stopOutfitsListener(for item: WardrobeItem) {
        guard let itemId = item.id else { return }
        outfitListeners[itemId]?.remove()
        outfitListeners[itemId] = nil
    }
}

// MARK: - Outfit decoding & fallback mapping

private extension WardrobeViewModel {
    /// Try Codable first, then hydrate from raw fields. Falls back to manual mapping.
    static func decodeOutfit(from doc: QueryDocumentSnapshot) -> Outfit? {
        // 1) Try Codable decode
        if var o = try? doc.data(as: Outfit.self) {
            hydrate(&o, from: doc.data(), id: doc.documentID)
            // If the essential fields are present, return
            if !o.imageURL.isEmpty { return o }
            // otherwise fallthrough to fallback
        }
        // 2) Fallback mapping
        return fallbackMapOutfit(doc)
    }

    /// Fill missing properties (id, itemIds, createdAt, etc.) from the raw dictionary.
    static func hydrate(_ o: inout Outfit, from d: [String: Any], id: String) {
        if o.id == nil { o.id = id }
        if o.itemIds.isEmpty {
            o.itemIds = (d["itemIDs"] as? [String]) ?? (d["itemIds"] as? [String]) ?? []
        }
        if o.itemImageURLs.isEmpty { o.itemImageURLs = d["itemImageURLs"] as? [String] ?? [] }
        if o.tags.isEmpty { o.tags = d["tags"] as? [String] ?? [] }
        if o.source.isEmpty { o.source = d["source"] as? String ?? "manual" }
        if o.createdAt == nil, let ts = d["createdAt"] as? Timestamp { o.createdAt = ts.dateValue() }
        if o.imageURL.isEmpty, let url = d["imageURL"] as? String { o.imageURL = url }
    }

    /// Manual decode used when Codable fails or fields differ.
    static func fallbackMapOutfit(_ doc: QueryDocumentSnapshot) -> Outfit? {
        let d = doc.data()

        guard let imageURL = d["imageURL"] as? String else { return nil }

        let name          = d["name"] as? String ?? ""
        let description   = d["description"] as? String
        let tags          = d["tags"] as? [String] ?? []
        let itemIDs       = (d["itemIDs"] as? [String]) ?? (d["itemIds"] as? [String]) ?? []
        let itemImageURLs = d["itemImageURLs"] as? [String] ?? []
        let isFavorite    = d["isFavorite"] as? Bool ?? false
        let wearCount     = d["wearCount"] as? Int ?? 0
        let source        = d["source"] as? String ?? "manual"
        let createdAt     = (d["createdAt"] as? Timestamp)?.dateValue()

        return Outfit(
            id: doc.documentID,
            name: name,
            description: description,
            imageURL: imageURL,
            itemImageURLs: itemImageURLs,
            itemIds: itemIDs,
            tags: tags,
            createdAt: createdAt,
            wearCount: wearCount,
            isFavorite: isFavorite,
            source: source
        )
    }
}

// MARK: - Filters & Sorting (Items)

extension WardrobeViewModel {
    func matchesFilters(_ item: WardrobeItem) -> Bool {
        let f = filters
        if f.category != "All", item.category.ci != f.category.ci { return false }                     // category
        if !f.colours.isEmpty {
            let itemColours = Set(item.colours.map(\.ci))
            if itemColours.isDisjoint(with: f.colours.map(\.ci)) { return false }                      // colours
        }
        if !f.tags.isEmpty {
            let itemTags = Set(item.customTags.map(\.ci))
            if itemTags.isDisjoint(with: f.tags.map(\.ci)) { return false }                            // tags
        }
        if f.dressCode != "Any", item.dressCode.ci != f.dressCode.ci { return false }
        if f.season != "All", item.season.ci != f.season.ci { return false }
        if f.size != "Any", item.size.ci != f.size.ci { return false }
        if f.material != "Any", item.material.ci != f.material.ci { return false }
        return true
    }

    func sort(_ items: [WardrobeItem]) -> [WardrobeItem] {
        switch filters.sortBy {
        case "Oldest":
            return items.sorted { ($0.addedAt ?? .distantPast) < ($1.addedAt ?? .distantPast) }        // oldest first
        case "A → Z":
            return items.sorted {
                ($0.category + " " + $0.subcategory)
                    .localizedCaseInsensitiveCompare($1.category + " " + $1.subcategory) == .orderedAscending
            }
        case "Z → A":
            return items.sorted {
                ($0.category + " " + $0.subcategory)
                    .localizedCaseInsensitiveCompare($1.category + " " + $1.subcategory) == .orderedDescending
            }
        default:
            return items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }        // newest first
        }
    }
}

// MARK: - Firebase Storage async helpers

private extension StorageReference {
    func putDataAsync(_ uploadData: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { cont in
            self.putData(uploadData, metadata: metadata) { meta, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: meta ?? StorageMetadata()) }
            }
        }
    }
    func downloadURL() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            self.downloadURL { url, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: url!) }
            }
        }
    }
}
