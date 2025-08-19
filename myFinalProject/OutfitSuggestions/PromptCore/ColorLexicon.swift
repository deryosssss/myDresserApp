//
//  ColorLexicon.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import Foundation

public enum ColorMatchStrength {
    case exact, family, any
}

public enum PaletteMode: Equatable {
    case none
    case monochrome(color: String?, strict: Bool) // strict when “all <color>” or “monochrome”
    case neutral, pastel, earth, colorful
}

public struct ColorLexicon {
    // Base “buckets” we normalize into
    public static let bases: Set<String> = [
        "black","white","red","blue","green","yellow","pink","beige","brown","grey","purple","orange"
    ]

    // Extra neutral keywords
    public static let neutrals: Set<String> = ["black","white","grey","beige","brown","camel","taupe","tan","ivory"]

    // Aliases and strong synonyms → base
    private static let alias: [String:String] = [
        // greys & blacks
        "gray":"grey","charcoal":"grey","graphite":"grey","slate":"grey","ash":"grey",
        "jet":"black","ebony":"black","noir":"black","ink":"black","obsidian":"black",

        // blues & greens
        "navy":"blue","cobalt":"blue","azul":"blue","skyblue":"blue","teal":"blue",
        "forestgreen":"green","olive":"green","sage":"green","mint":"green",

        // browns / beiges
        "cream":"beige","nude":"beige","taupe":"beige","tan":"beige","camel":"beige",
        "sand":"beige","khaki":"beige","stone":"beige","oat":"beige","oatmeal":"beige",
        "chocolate":"brown","mocha":"brown","coffee":"brown","cognac":"brown","chestnut":"brown",
        "woodbrown":"brown","dirtbrown":"brown","zinnwalditebrown":"brown",

        // others
        "lilac":"purple","lavender":"purple",
        "coral":"orange","peach":"orange",
        "blush":"pink","rose":"pink",
        "offwhite":"white","ivory":"white"
    ]

    // Modifiers we strip when they appear at the start (pale, dark, etc.)
    private static let prefixMods: [String] = [
        "light","dark","bright","deep","neon","soft","muted","pale","baby","pastel","warm","cool","rich"
    ]

    // Families broaden a base color query
    // (e.g. “brown outfit” should happily match camel/taupe/tan)
    private static let families: [String:Set<String>] = [
        "black": ["black","jet","ebony","noir","ink"],
        "grey":  ["grey","gray","charcoal","graphite","slate","ash"],
        "brown": ["brown","mocha","chocolate","coffee","cognac","chestnut"],
        "beige": ["beige","camel","taupe","tan","sand","khaki","stone","oat","oatmeal","cream","nude"],
        "green": ["green","olive","sage","mint","forestgreen"],
        "blue":  ["blue","navy","cobalt","skyblue","teal","azul"],
        "pink":  ["pink","blush","rose"],
        "purple":["purple","lilac","lavender"],
        "orange":["orange","coral","peach"],
        "white": ["white","ivory","offwhite"]
    ]

    @inline(__always) private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Normalize any arbitrary color label to a known base (black, brown, …).
    /// - Returns: base color string or `nil` if unrecognized.
    public static func normalize(_ raw: String) -> String? {
        var s = norm(raw)
        // strip leading modifiers (pale brown → brown)
        for m in prefixMods where s.hasPrefix(m) {
            s.removeFirst(m.count)
            break
        }
        // remove trailing -ish
        if s.hasSuffix("ish") { s.removeLast(3) }

        if let mapped = alias[s] { return mapped }
        if bases.contains(s) { return s }

        // Generic suffix rule: anything ending with a base (e.g. woodbrown) → that base
        if let base = bases.first(where: { s.hasSuffix($0) }) { return base }

        return nil
    }

    /// Expand a base color to its family set (includes the base).
    public static func expandFamily(for base: String) -> Set<String> {
        var set = families[base] ?? [base]
        set.insert(base)
        return set
    }
}
