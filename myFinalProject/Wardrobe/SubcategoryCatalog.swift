//
//  SubcategoryCatalog.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import Foundation

enum SubcategoryCatalog {
    /// Map any free-form category to our canonical tab labels.
    static func canonicalCategory(_ raw: String) -> String? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                   .lowercased()
        let map: [String:String] = [
            "dress":"Dress", "dresses":"Dress",
            "top":"Top", "tops":"Top",
            "bottom":"Bottom", "bottoms":"Bottom", "trousers":"Bottom", "pants":"Bottom",
            "shoes":"Shoes", "shoe":"Shoes", "footwear":"Shoes",
            "outer":"Outerwear", "outerwear":"Outerwear", "coat":"Outerwear", "jacket":"Outerwear",
            "bag":"Bag", "bags":"Bag",
            "accessory":"Accessory", "accessories":"Accessory"
        ]
        return map[s]
    }

    static let allTabs: [String] = ["Dress","Top","Bottom","Shoes","Outerwear","Bag","Accessory"]

    static func options(for category: String) -> [String] {
        switch category.lowercased() {
        case "dress":     return ["Dress", "Gown", "Jumpsuit", "Overall"]
        case "top":       return ["Top", "Shirt", "Blouse", "T-Shirt", "Sweater", "Hoodie", "Cardigan", "Tank"]
        case "bottom":    return ["Pants", "Jeans", "Skirt", "Shorts", "Trouser", "Trousers", "Leggings", "Trackpants"]
        case "shoes":     return ["Sneaker", "Trainer", "Boots", "Heels", "Sandals", "Loafers","Flats","Mules"]
        case "outerwear": return ["Jacket", "Coat", "Blazer", "Parka", "Outerwear","Trench"]
        case "bag":       return ["Handbag", "Backpack", "Tote", "Crossbody", "Purse", "Wallet","Clutch","Shoulder Bag"]
        case "accessory": return ["Belt", "Scarf", "Hat", "Cap", "Jewellery", "Jewelry", "Glove","Sunglasses","Necklace","Bracelet","Earrings"]
        default:
            return Array(Set(
                options(for: "dress") + options(for: "top") + options(for: "bottom") +
                options(for: "shoes") + options(for: "outerwear") + options(for: "bag") +
                options(for: "accessory")
            )).sorted()
        }
    }
}
