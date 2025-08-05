//
//  WardrobeItemCategoryMatching.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
// Matcher for the “Category” tabs in WardrobeView.

import Foundation

extension WardrobeItem {
    /// Returns true if this item falls under the given Category tab
    func matches(category: WardrobeView.Category) -> Bool {
        let pri = self.category.lowercased()
        let sub = self.subcategory.lowercased()

        switch category {
        case .all:
            return true
        case .top:
            return pri.contains("top") || sub.contains("top")
        case .outerwear:
            return pri.contains("outerwear") || sub.contains("outerwear")
        case .dress:
            return pri.contains("dress") || sub.contains("dress")
        case .bottoms:
            // “bottoms” or “pants”
            return pri.contains("bottom") || pri.contains("pant")
                || sub.contains("bottom") || sub.contains("pant")
        case .footwear:
            // “shoe”, “sneaker”, etc.
            return pri.contains("shoe") || pri.contains("footwear")
                || sub.contains("shoe") || sub.contains("footwear")
        }
    }
}
