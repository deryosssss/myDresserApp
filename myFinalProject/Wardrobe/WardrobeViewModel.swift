//  WardrobeViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
//


import Combine
import FirebaseFirestore

protocol WardrobeDataService {
    func listen(_ callback: @escaping (Result<[WardrobeItem], Error>) -> Void) -> ListenerRegistration
    func deleteItem(_ id: String)
    func updateItem(_ id: String, data: [String: Any])
}

class WardrobeViewModel: ObservableObject {
    @Published var items: [WardrobeItem] = []
    @Published var favoriteIDs = Set<String>()
    @Published private(set) var outfitsByItem: [String: [Outfit]] = [:]
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

    deinit { listener?.remove() }

    func isFavorite(_ item: WardrobeItem) -> Bool {
        guard let id = item.id else { return false }
        return favoriteIDs.contains(id)
    }

    func toggleFavorite(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        if favoriteIDs.contains(id) {
            favoriteIDs.remove(id)
            service.updateItem(id, data: ["isFavorite": false])
        } else {
            favoriteIDs.insert(id)
            service.updateItem(id, data: ["isFavorite": true])
        }
    }

    func delete(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        items.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        outfitsByItem[id] = nil
        service.deleteItem(id)
    }

    func outfits(for item: WardrobeItem) -> [Outfit] {
        guard let id = item.id else { return [] }
        return outfitsByItem[id] ?? []
    }

    func setOutfits(_ outfits: [Outfit], for item: WardrobeItem) {
        guard let id = item.id else { return }
        outfitsByItem[id] = outfits
    }

    func updateItem(_ item: WardrobeItem, transform: (inout WardrobeItem) -> Void) {
        guard let id = item.id,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
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
        guard let id = item.id,
              let idx = items.firstIndex(where: { $0.id == id }) else { return }
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
}

// Simple Outfit model
struct Outfit: Identifiable {
    let id: String
    let imageURL: String
    let itemImageURLs: [String]
    let tags: [String]
}
