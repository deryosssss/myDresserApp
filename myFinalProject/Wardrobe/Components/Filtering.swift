//
//  Filtering.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import Foundation
import SwiftUI

extension WardrobeView {
    func searchableText(for item: WardrobeItem) -> String {
        [
            item.category, item.subcategory, item.style, item.designPattern,
            item.material, item.dressCode
        ].joined(separator: " ")
    }

    func categoryMatch(_ item: WardrobeItem, cat: Category) -> Bool {
        if cat == .all { return true }
        let c = item.category.lowercased()
        switch cat {
        case .top:
            return c == "top" || c == "tops"
        case .outerwear:
            return c == "outerwear" || c == "jacket" || c == "coat" || c == "blazer"
        case .dress:
            return c == "dress" || c == "dresses"
        case .bottoms:
            return c == "bottom" || c == "bottoms" || c == "pants" || c == "trousers"
            || c == "jeans" || c == "skirt" || c == "shorts" || c == "leggings"
        case .shoes:
            return c == "shoes" || c == "shoe" || c == "footwear"
        case .accessories:
            return c == "accessory" || c == "accessories"
        case .bag:
            return c == "bag" || c == "bags" || c == "handbag" || c == "purse"
        case .all:
            return true
        }
    }
}
