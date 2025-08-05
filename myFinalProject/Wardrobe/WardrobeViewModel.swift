//
//  WardrobeViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
//

import SwiftUI
import FirebaseFirestore

class WardrobeViewModel: ObservableObject {
    // The full list of items from Firestore:
    @Published var items: [WardrobeItem] = []
    // A simple in-memory favorites store (by document ID):
    @Published private var favorites = Set<String>()

    private let service = WardrobeFirestoreService()
    private var listener: ListenerRegistration?

    init() {
        // Start listening to Firestore collection
        listener = service.listen { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.items = items
                case .failure(let err):
                    print("❌ Error fetching items:", err)
                }
            }
        }
    }

    deinit {
        listener?.remove()
    }

    // MARK: - Favorites API

    func isFavorite(_ item: WardrobeItem) -> Bool {
        guard let id = item.id else { return false }
        return favorites.contains(id)
    }

    func toggleFavorite(_ item: WardrobeItem) {
        guard let id = item.id else { return }
        if favorites.contains(id) {
            favorites.remove(id)
        } else {
            favorites.insert(id)
        }
    }
}
