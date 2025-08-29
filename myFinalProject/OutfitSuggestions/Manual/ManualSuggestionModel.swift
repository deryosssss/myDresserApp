//
//  ManualSuggestionModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 12/08/2025.
//

import Foundation

/// Logical layers that form an outfit. Order matters for preview stacking.
public enum LayerKind: String, CaseIterable, Identifiable, Codable, Hashable {
    case dress, top, bottom, shoes, outerwear, bag, accessory
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .dress: return "Dress"
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .shoes: return "Shoes"
        case .outerwear: return "Outerwear"
        case .bag: return "Bag"
        case .accessory: return "Accessory"
        }
    }

    /// Render order in the stacked preview (back -> front).
    public var stackOrder: Int {
        switch self {
        case .outerwear: return 0
        case .dress: return 1
        case .top: return 2
        case .bottom: return 3
        case .bag: return 4
        case .accessory: return 5
        case .shoes: return 6
        }
    }

    /// Heuristics for client-side matching (category/subcategory/tags)
    public var tagMatchers: [String] {
        switch self {
        case .dress: return ["dress", "gown", "jumpsuit", "overall"]
        case .top: return ["top", "shirt", "blouse", "t-shirt", "tee", "sweater", "hoodie", "cardigan"]
        case .bottom: return ["bottom", "pants", "jeans", "skirt", "shorts", "trouser", "trousers"]
        case .shoes: return ["shoe", "shoes", "footwear", "sneaker", "trainer", "boot", "heel", "sandals", "loafer"]
        case .outerwear: return ["outerwear", "jacket", "coat", "blazer", "parka"]
        case .bag: return ["bag", "handbag", "backpack", "tote", "crossbody", "purse"]
        case .accessory: return ["accessory", "belt", "scarf", "hat", "cap", "jewellery", "jewelry", "glove"]
        }
    }
}

/// User selection per layer
public struct LayerSelection: Identifiable, Codable, Hashable {
    public var id: String { kind.rawValue }
    public var kind: LayerKind
    public var itemID: String? = nil
    public var locked: Bool = false

    public init(kind: LayerKind, itemID: String? = nil, locked: Bool = false) {
        self.kind = kind
        self.itemID = itemID
        self.locked = locked
    }
}

/// Preset “layer combinations” (chips in the bottom strip)
public enum LayerPreset: String, CaseIterable, Identifiable, Codable, Equatable {
    case two_DressShoes
    case three_DressShoesBag
    case three_TopBottomShoes
    case four_TopBottomShoesAccessory
    case four_TopBottomOuterwearShoes
    case five_TopBottomOuterwearShoesBag
    case six_TopBottomOuterwearShoesBagAccessory

    public var id: String { rawValue }

    public var kinds: [LayerKind] {
        switch self {
        case .two_DressShoes:
            return [.dress, .shoes]
        case .three_DressShoesBag:
            return [.dress, .shoes, .bag]
        case .three_TopBottomShoes:
            return [.top, .bottom, .shoes]
        case .four_TopBottomShoesAccessory:
            return [.top, .bottom, .shoes, .accessory]
        case .four_TopBottomOuterwearShoes:
            // Always show outerwear first in the list
            return [.outerwear, .top, .bottom, .shoes]
        case .five_TopBottomOuterwearShoesBag:
            return [.outerwear, .top, .bottom, .shoes, .bag]
        case .six_TopBottomOuterwearShoesBagAccessory:
            return [.outerwear, .top, .bottom, .shoes, .bag, .accessory]
        }
    }

    public var shortTitle: String {
        switch self {
        case .two_DressShoes: return "2: Dress+Shoes"
        case .three_DressShoesBag: return "3: Dress+Shoes+Bag" 
        case .three_TopBottomShoes: return "3: Top+Bottom+Shoes"
        case .four_TopBottomShoesAccessory: return "4: Top+Bottom+Shoes+Acc"
        case .four_TopBottomOuterwearShoes: return "4: +Outerwear"
        case .five_TopBottomOuterwearShoesBag: return "5: +Bag"
        case .six_TopBottomOuterwearShoesBagAccessory: return "6: +Accessory"
        }
    }

    /// SF Symbol used in the chip
    public var icon: String {
        switch self {
        case .two_DressShoes: return "square.grid.2x2"
        case .three_DressShoesBag: return "rectangle.grid.3x2"
        case .three_TopBottomShoes: return "rectangle.grid.3x2"
        case .four_TopBottomShoesAccessory: return "square.grid.2x2"
        case .four_TopBottomOuterwearShoes: return "rectangle.grid.1x2"
        case .five_TopBottomOuterwearShoesBag: return "square.grid.3x2"
        case .six_TopBottomOuterwearShoesBagAccessory: return "rectangle.3.group"
        }
    }
}
