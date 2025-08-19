//
//  WardrobeViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
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
    // MARK: — Published state
    @Published var items: [WardrobeItem] = []
    @Published var favoriteIDs = Set<String>()

    // Per-item outfits (ItemDetailView)
    @Published var outfitsByItem: [String: [Outfit]] = [:]

    // All outfits for Wardrobe → Outfits tab
    @Published var allOutfits: [Outfit] = []

    @Published var error: Error?

    // Filters (sheet → list)
    @Published var filters: WardrobeFilters = .default

    private let service: WardrobeDataService
    private var itemsListener: ListenerRegistration?

    // Per-item listeners
    private var outfitListeners: [String: ListenerRegistration] = [:]
    // Global listener
    private var allOutfitsListener: ListenerRegistration?

    init(service: WardrobeDataService = WardrobeFirestoreService()) {
        self.service = service

        // Items
        itemsListener = service.listen { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newItems):
                    self?.items = newItems
                    self?.favoriteIDs = Set(newItems.filter { $0.isFavorite }.compactMap { $0.id })
                case .failure(let err):
                    self?.error = err
                }
            }
        }

        // All outfits
        startAllOutfitsListener()
    }

    deinit {
        itemsListener?.remove()
        allOutfitsListener?.remove()
        outfitListeners.values.forEach { $0.remove() }
    }

    // MARK: — WardrobeItem APIs

    func toggleFavorite(_ item: WardrobeItem) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isFavorite.toggle()
        let newVal = items[idx].isFavorite
        if newVal { favoriteIDs.insert(id) } else { favoriteIDs.remove(id) }
        service.updateItem(id, data: ["isFavorite": newVal])
    }

    func isFavorite(_ item: WardrobeItem) -> Bool {
        if let id = item.id, let latest = items.first(where: { $0.id == id }) {
            return latest.isFavorite
        }
        return item.isFavorite
    }

    func delete(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        items.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        stopOutfitsListener(for: item)
        outfitsByItem[id] = nil
        service.deleteItem(id)
    }

    func updateItem(_ item: WardrobeItem, transform: (inout WardrobeItem) -> Void) {
        guard let id = item.id, let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var copy = items[idx]
        transform(&copy)
        items[idx] = copy
        service.updateItem(id, data: copy.dictionary)
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
        service.updateItem(id, data: copy.dictionary)
    }

    // MARK: — Media

    func replacePhoto(_ item: WardrobeItem, with data: Data, contentType: String = "image/jpeg", fileExtension: String = "jpg") {
        guard let id = item.id else { return }
        let storage = Storage.storage()
        let path = "users/\(item.userId)/items/\(id)/primary.\(fileExtension)"
        let ref  = storage.reference(withPath: path)

        let meta = StorageMetadata()
        meta.contentType = contentType

        if let oldPath = item.imagePath, oldPath != path {
            storage.reference(withPath: oldPath).delete(completion: nil)
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
                self.service.updateItem(id, data: ["imageURL": url.absoluteString, "imagePath": path])
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
            try? await storage.reference(withPath: oldPath).delete()
        }

        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL()

        await MainActor.run {
            if let idx = self.items.firstIndex(where: { $0.id == id }) {
                self.items[idx].imageURL = url.absoluteString
                self.items[idx].imagePath = path
            }
        }
        self.service.updateItem(id, data: ["imageURL": url.absoluteString, "imagePath": path])
    }

    // MARK: — Outfits (per-item for ItemDetailView)

    func setOutfits(_ outfits: [Outfit], for item: WardrobeItem) {
        guard let id = item.id else { return }
        outfitsByItem[id] = outfits
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
        // TODO: delete in Firestore
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
        // TODO: persist to Firestore
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
        // TODO: persist to Firestore
    }

    // MARK: — Outfits Firestore listeners

    /// Live listener for all outfits of current user (drives Wardrobe → Outfits)
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
                if var o = try? doc.data(as: Outfit.self) {
                    if o.id == nil { o.id = doc.documentID }   // ✅ ensure non-nil id
                    return o
                }
                return Self.fallbackMapOutfit(doc)
            } ?? []
            DispatchQueue.main.async { self.allOutfits = arr }
        }
    }

    /// Listener for outfits that include a specific item (ItemDetailView)
    func startOutfitsListener(for item: WardrobeItem) {
        guard let itemId = item.id else { return }
        if outfitListeners[itemId] != nil { return }

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
                if var o = try? doc.data(as: Outfit.self) {
                    if o.id == nil { o.id = doc.documentID }   // ✅ ensure non-nil id
                    return o
                }
                return Self.fallbackMapOutfit(doc)
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

    /// Fallback mapping if Codable decoding isn’t perfect for Outfit.
    private static func fallbackMapOutfit(_ doc: DocumentSnapshot) -> Outfit? {
        let d = doc.data() ?? [:]
        guard let imageURL = d["imageURL"] as? String else { return nil }
        let name          = d["name"] as? String ?? ""
        let description   = d["description"] as? String
        let tags          = d["tags"] as? [String] ?? []
        let itemIDs       = (d["itemIDs"] as? [String]) ?? (d["itemIds"] as? [String]) ?? []
        let itemImageURLs = d["itemImageURLs"] as? [String] ?? []
        let isFavorite    = d["isFavorite"] as? Bool ?? false
        let wearCount     = d["wearCount"] as? Int ?? 0
        let source        = d["source"] as? String ?? "manual"

        return Outfit(
            id: doc.documentID,              // ✅ always set id
            name: name,
            description: description,
            imageURL: imageURL,
            itemImageURLs: itemImageURLs,
            itemIds: itemIDs,
            tags: tags,
            wearCount: wearCount,
            isFavorite: isFavorite,
            source: source
        )
    }
}

// MARK: — Filters & Sorting (Items)

extension WardrobeViewModel {
    func matchesFilters(_ item: WardrobeItem) -> Bool {
        let f = filters
        if f.category != "All", item.category.ci != f.category.ci { return false }
        if !f.colours.isEmpty {
            let itemColours = Set(item.colours.map(\.ci))
            if itemColours.isDisjoint(with: f.colours.map(\.ci)) { return false }
        }
        if !f.tags.isEmpty {
            let itemTags = Set(item.customTags.map(\.ci))
            if itemTags.isDisjoint(with: f.tags.map(\.ci)) { return false }
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
            return items.sorted { ($0.addedAt ?? .distantPast) < ($1.addedAt ?? .distantPast) }
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
            return items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
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

