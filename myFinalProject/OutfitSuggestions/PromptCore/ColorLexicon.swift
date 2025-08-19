//
//  ColorLexicon.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//  Canonicalize arbitrary color words from user input and item metadata
//  into a small set of base color tokens (e.g., "charcoal" → "grey") and
//  provide simple palette/grouping helpers (e.g., expand "beige" to include
//  "camel", "taupe", …). This keeps matching/scoring consistent across the app.
//

import Foundation

/// Optional strength flag for matching colors elsewhere in the app.
/// - exact: item contains the exact normalized base (e.g., "black").
/// - family: item contains any synonym/neighbor in that base family (e.g., "charcoal" for "grey").
/// - any: no strict constraint; treat as a soft preference.
/// (Defined here for convenience; not used directly in this file.)
public enum ColorMatchStrength {
    case exact, family, any
}

/// High-level palette modes parsed from prompts.
/// - `.monochrome(color:strict:)`
///   * color == nil → "monochrome" with no single hue specified (engine infers).
///   * strict == true → treat as hard constraint (e.g., "all black/white/red").
///   * strict == false → preference only (not currently used; reserved for future).
public enum PaletteMode: Equatable {
    case none
    case monochrome(color: String?, strict: Bool) // strict when “all <color>” or “monochrome”
    case neutral, pastel, earth, colorful
}

/// Central color vocabulary + normalization helpers.
public struct ColorLexicon {
    // MARK: - Canonical bases

    /// The reduced set of "base" colors we normalize into.
    /// Keep this list small and stable—most logic relies on these tokens.
    public static let bases: Set<String> = [
        "black","white","red","blue","green","yellow","pink","beige","brown","grey","purple","orange"
    ]

    /// Neutral family used for palette scoring (separate from `families` below).
    public static let neutrals: Set<String> = ["black","white","grey","beige","brown","camel","taupe","tan","ivory"]

    // MARK: - Synonyms & families

    /// Strong aliases/synonyms → base. Use *normalized* (no spaces/punctuation) keys.
    /// Examples:
    ///  - "charcoal" → "grey"
    ///  - "ivory"    → "white"
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

    /// Descriptive modifiers we remove when they appear at the *start* of a color phrase.
    /// e.g., "lightbrown" → "brown", "pastel pink" → "pink" (after normalization).
    private static let prefixMods: [String] = [
        "light","dark","bright","deep","neon","soft","muted","pale","baby","pastel","warm","cool","rich"
    ]

    /// Family expansions broaden a base query to nearby shades/synonyms.
    /// Used when matching "brown outfit" against items tagged "camel"/"taupe", etc.
    /// (Values should be *normalized* and include plausible user/item tokens.)
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

    // MARK: - Normalization core

    /// Lowercase, strip diacritics, and remove non-alphanumeric chars.
    /// e.g., "Pálé  Brown!" → "palebrown"
    @inline(__always) private static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    /// Normalize any arbitrary color label to a known base (black, brown, …).
    ///
    /// Steps:
    ///  1) Normalize (`norm`).
    ///  2) Strip leading modifiers (e.g., "light", "pastel", …).
    ///  3) Remove trailing "-ish" (e.g., "bluish" → "blu").
    ///  4) Check hard aliases (e.g., "ivory" → "white").
    ///  5) If the token is itself a base, return it.
    ///  6) Generic suffix rule: if it *ends with* a base (e.g., "woodbrown") → that base.
    ///
    /// - Returns: base color string or `nil` if unrecognized.
    public static func normalize(_ raw: String) -> String? {
        var s = norm(raw)

        // 2) strip leading modifiers (pale brown → brown)
        for m in prefixMods where s.hasPrefix(m) {
            s.removeFirst(m.count)
            break
        }

        // 3) remove trailing -ish (bluish → blu → then may match suffix "blue")
        if s.hasSuffix("ish") { s.removeLast(3) }

        // 4) strong alias mapping (e.g., "charcoal" → "grey")
        if let mapped = alias[s] { return mapped }

        // 5) already a base
        if bases.contains(s) { return s }

        // 6) suffix heuristic: anything ending with a base (e.g., "woodbrown") → that base
        if let base = bases.first(where: { s.hasSuffix($0) }) { return base }

        // unrecognized
        return nil
    }

    /// Expand a base color to its "family" (synonyms/nearby shades) including the base.
    /// If no family is defined, returns a set containing just the base.
    public static func expandFamily(for base: String) -> Set<String> {
        var set = families[base] ?? [base]
        set.insert(base)
        return set
    }
}
