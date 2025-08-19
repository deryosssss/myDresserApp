//
//  WardrobeItemCategoryMatching.swift
//  myFinalProject
//
//  Created by Derya Baglan on 05/08/2025.
// Matcher for the “Category” tabs in WardrobeView.
//

import Foundation

extension WardrobeItem {
    /// Returns true if this item falls under the given Category tab.
    /// Checks both `category` and `subcategory` with relaxed synonyms.
    func matches(category tab: WardrobeView.Category) -> Bool {
        let pri = normalize(self.category)     // <- use the item's string
        let sub = normalize(self.subcategory)  // <- use the item's string

        func hasAny(_ tokens: [String]) -> Bool {
            tokens.contains { pri.contains($0) || sub.contains($0) }
        }

        switch tab {
        case .all:
            return true

        case .top:
            return hasAny([
                "top","shirt","tee","tshirt","blouse",
                "hoodie","sweater","jumper","cardigan","tank","camisole","cami"
            ])

        case .outerwear:
            return hasAny([
                "outerwear","jacket","coat","blazer","trench","parka","puffer","overcoat","bomber","denimjacket"
            ])

        case .dress:
            return hasAny([
                "dress","gown","jumpsuit","overall","slipdress"
            ])

        case .bottoms:
            return hasAny([
                "bottom","pant","pants","trouser","trousers",
                "jean","jeans","skirt","short","shorts","legging","leggings",
                "trackpant","trackpants","culotte","cargo"
            ])

        // If your enum is `.footwear` instead of `.shoes`, just rename this case to `.footwear`.
        case .shoes:
            return hasAny([
                "shoe","footwear","sneaker","sneakers","trainer","trainers",
                "boot","boots","heel","heels","loafer","loafers",
                "sandal","sandals","mule","mules","flat","flats"
            ])

        case .accessories:
            return hasAny([
                "accessory","accessories","belt","scarf","hat","cap","beanie",
                "glove","gloves","sunglass","sunglasses",
                "jewelry","jewellery","necklace","bracelet","earring","earrings","ring","rings"
            ])

        case .bag:
            return hasAny([
                "bag","bags","handbag","purse","tote","clutch",
                "crossbody","shoulder","backpack","wallet"
            ])
        }
    }
}

// MARK: - Helpers

private func normalize(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: .current)
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
}
