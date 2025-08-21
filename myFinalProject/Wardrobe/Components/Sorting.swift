//
//  Sorting.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import Foundation

extension WardrobeView {
    enum SortOption: Hashable { case newest, oldest, az, za }

    // Items A–Z key
    func sortKeyAZ(for item: WardrobeItem) -> String {
        let parts = [item.category, item.subcategory, item.style]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ").lowercased()
    }

    func applyLocalSortItems(_ items: [WardrobeItem], by option: SortOption) -> [WardrobeItem] {
        switch option {
        case .newest: return items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        case .oldest: return items.sorted { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) }
        case .az:     return items.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedAscending }
        case .za:     return items.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedDescending }
        }
    }

    // Outfits A–Z key (fallbacks to tags/URL when name is empty)
    func sortKeyAZ(for outfit: Outfit) -> String {
        let name = outfit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name.lowercased() }
        if !outfit.tags.isEmpty { return outfit.tags.joined(separator: " ").lowercased() }
        return outfit.imageURL.lowercased()
    }

    func applyLocalSortOutfits(_ outfits: [Outfit], by option: SortOption) -> [Outfit] {
        switch option {
        case .newest: return outfits.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest: return outfits.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
        case .az:     return outfits.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedAscending }
        case .za:     return outfits.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedDescending }
        }
    }
}
