//
//  SubtypeLexicon.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//  Map many free-text subtype tokens (e.g., “sneakers”, “chelsea”, “mom jeans”)
//  into a small canonical set used by the outfit engine. Also provides helpers
//  to check if an item matches a required set of canonical subtypes and to
//  render human-friendly labels.
//

import Foundation

/// Canonical subtype labels we’ll use in queries & messages.
/// Many user/item synonyms are normalized to one of these values.
public enum CanonicalSubtype: String {
    // shoes
    case trainers, heels, boots, loafers, sandals, flats
    // bottoms
    case skirt, jeans, trousers, shorts, leggings
    // tops
    case hoodie, sweater, blouse, tee, tank
    // outerwear
    case blazer, jacket, coat, trench, parka
    // bags
    case tote, crossbody, clutch, shoulder
    // accessories
    case belt, scarf, hat, sunglasses, jewelry
}

public enum SubtypeLexicon {
    /// Normalize text for matching:
    /// - strip diacritics, lowercase, remove non-alphanumerics.
    /// Keeps matching fast and robust to formatting.
    @inline(__always) private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Synonyms (already normalized via `norm`) for each canonical subtype.
    /// Add new tokens here to broaden recognition without changing engine logic.
    private static let synonyms: [CanonicalSubtype: Set<String>] = [
        // Shoes
        .trainers: ["trainer","trainers","sneaker","sneakers","tennisshoe","tennisshoes","runningshoe","runningshoes","plimsoll","plimsolls","kicks","athleticshoe","gymshoe"],
        .heels:    ["heel","heels","pump","pumps","stiletto","stilettos","slingback","slingbacks"],
        .boots:    ["boot","boots","chelsea","combat","ankleboot","ankleboots","kneeboot","kneeboots","knee","kneehigh"],
        .loafers:  ["loafer","loafers","pennyloafer","pennyloafers","drivingloafer","drivingloafers"],
        .sandals:  ["sandal","sandals","slide","slides","flipflop","flipflops","mule","mules"],
        .flats:    ["flat","flats","balletflat","balletflats"],

        // Bottoms
        .skirt:    ["skirt","miniskirt","midiskirt","maxiskirt","slipskirt","pleatedskirt"],
        .jeans:    ["jean","jeans","denim","momjeans","skinnyjeans","straightjeans","widejeans"],
        .trousers: ["trouser","trousers","pants","slacks","tailoredpants","suitpants","chinos"],
        .shorts:   ["short","shorts","denimshorts","bikershorts","bermudashorts"],
        .leggings: ["legging","leggings","yogapants"],

        // Tops
        .hoodie:   ["hoodie","hooded","ziphoodie"],
        .sweater:  ["sweater","jumper","crewneck","knit","cardigan"],
        .blouse:   ["blouse","shirt","buttondown","buttonup"],
        .tee:      ["tee","tshirt","tshirt","t","graphictee"], // NOTE: "tshirt" appears twice—harmless duplication
        .tank:     ["tank","camisole","cami","singlet"],

        // Outerwear
        .blazer:   ["blazer"],
        .jacket:   ["jacket","bikerjacket","denimjacket","bomber"],
        .coat:     ["coat","overcoat","woolcoat"],
        .trench:   ["trench","trenchoat","trenchcoat"],
        .parka:    ["parka","puffer","downjacket"],

        // Bags
        .tote:     ["tote","totebag","shopper"],
        .crossbody:["crossbody","crossbodybag","messenger"],
        .clutch:   ["clutch","eveningbag"],
        .shoulder: ["shoulderbag","shoulder"],

        // Accessories
        .belt:     ["belt","waistbelt"],
        .scarf:    ["scarf","shawl","wrap"],
        .hat:      ["hat","beanie","cap","bucket"],
        .sunglasses:["sunglass","sunglasses","sunnies","shade","shades"],
        .jewelry:  ["jewelry","jewellery","necklace","bracelet","earring","earrings","ring","rings"]
    ]

    /// Map a single token to `(LayerKind, CanonicalSubtype)` if recognized.
    /// - Parameter raw: any raw token; will be normalized via `norm`.
    /// - Returns: (kind, canonicalSubtype) or `nil` if not recognized.
    public static func canonical(for raw: String) -> (LayerKind, CanonicalSubtype)? {
        let t = norm(raw)
        for (canon, syns) in synonyms {
            if syns.contains(t) {
                // Route the canonical subtype to its parent LayerKind.
                switch canon {
                case .trainers, .heels, .boots, .loafers, .sandals, .flats:
                    return (.shoes, canon)
                case .skirt, .jeans, .trousers, .shorts, .leggings:
                    return (.bottom, canon)
                case .hoodie, .sweater, .blouse, .tee, .tank:
                    return (.top, canon)
                case .blazer, .jacket, .coat, .trench, .parka:
                    return (.outerwear, canon)
                case .tote, .crossbody, .clutch, .shoulder:
                    return (.bag, canon)
                case .belt, .scarf, .hat, .sunglasses, .jewelry:
                    return (.accessory, canon)
                }
            }
        }
        return nil
    }

    /// Check if an item (by searchable text) matches *any* of the required canonical subtypes.
    ///
    /// - Parameters:
    ///   - itemHaystack: prebuilt searchable text for the item (category, tags, etc.).
    ///   - itemSubcategory: the item’s subcategory field (included to catch precise labels).
    ///   - kind: the layer kind we’re testing against (shoes, bottom, …).
    ///   - required: set of canonical subtypes to satisfy; empty means “no constraint”.
    /// - Returns: `true` if at least one canonical subtype is found in the haystack.
    public static func matches(itemHaystack: String, itemSubcategory: String, kind: LayerKind, required: Set<CanonicalSubtype>) -> Bool {
        if required.isEmpty { return true } // no constraint to enforce
        let hay = norm(itemHaystack) + " " + norm(itemSubcategory)
        for canon in required {
            guard let syns = synonyms[canon] else { continue }
            if syns.contains(where: { hay.contains($0) }) { return true }
        }
        return false
    }

    /// Human-readable label for a set of canonical subtypes (for UI/tooltips).
    /// Produces short, user-friendly strings like "jeans" or "jeans / skirt" or "jeans, skirt, …".
    public static func humanLabel(_ set: Set<CanonicalSubtype>) -> String {
        let names = set.map { $0.rawValue }.sorted()
        if names.isEmpty { return "" }
        if names.count == 1 { return names[0] }
        if names.count == 2 { return names.joined(separator: " / ") }
        return names.prefix(3).joined(separator: ", ") + "…"
    }
}
