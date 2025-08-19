//
//  WardrobeFilters.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import Foundation

struct WardrobeFilters: Equatable {
    var category: String = "All"
    var sortBy: String = "Newest"
    var colours: Set<String> = []
    var tags: Set<String> = []
    var dressCode: String = "Any"
    var season: String = "All"
    var size: String = "Any"
    var material: String = "Any"

    static let `default` = WardrobeFilters()
}

extension String {
    /// Case-insensitive normalized string (trim + lowercased)
    var ci: String { trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
}
