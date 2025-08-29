//  OutfitsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 07/08/2025.
//

import Combine
import FirebaseFirestore

class OutfitsViewModel: ObservableObject {
    @Published var outfits: [Outfit] = []

    func toggleFavorite(_ outfit: Outfit) {
        guard let idx = outfits.firstIndex(where: { $0.id == outfit.id }) else { return }
        outfits[idx].isFavorite.toggle()
    }

    func updateTags(_ outfit: Outfit, newTags: [String]) {
        guard let idx = outfits.firstIndex(where: { $0.id == outfit.id }) else { return }
        outfits[idx].tags = newTags
    }

    func delete(_ outfit: Outfit) {
        outfits.removeAll { $0.id == outfit.id }
    }
}
