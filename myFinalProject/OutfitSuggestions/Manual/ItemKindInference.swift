//
//  ItemKindInference.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import Foundation

enum ItemKindInference {
    /// Minimal heuristic mirroring your store matching.
    static func inferKind(for item: WardrobeItem) -> LayerKind? {
        let c = item.category.lowercased()
        let s = item.subcategory.lowercased()
        let joined = "\(c) \(s)"

        func has(_ terms: [String]) -> Bool { terms.contains { joined.contains($0) } }

        if has(["dress","gown","jumpsuit","overall"]) { return .dress }
        if has(["jacket","coat","blazer","outerwear","parka"]) { return .outerwear }
        if has(["bottom", "pants", "jeans", "skirt", "shorts", "trouser", "trousers"]) { return .bottom }
        if has(["shoe","shoes","sneaker","trainer","boot","boots","sandal","loafer","heel","footwear"]) { return .shoes }
        if has(["bag","handbag","backpack","tote","crossbody","purse","wallet"]) { return .bag }
        if has(["belt","scarf","hat","cap","jewellery","jewelry","glove","accessory"]) { return .accessory }
        return .top
    }
}
