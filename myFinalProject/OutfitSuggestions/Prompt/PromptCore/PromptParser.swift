//
//  PromptParser.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//  Parse a free-text outfit prompt (e.g., “smart casual all-white with boots”)
//  into a structured `PromptQuery` used by the outfit engine. The parser is
//  deliberately lightweight and keyword-based (no external NLP).
//

import Foundation

/// Normalized representation of a user prompt.
/// The outfit engine consumes this to constrain/score item selection.
public struct PromptQuery {
    /// Hard color filters bound to specific layers (e.g., only black shoes).
    public var requiredColorsByKind: [LayerKind: Set<String>] = [:]
    /// Hard subtype filters bound to specific layers (e.g., bottom: .jeans).
    public var requiredSubtypesByKind: [LayerKind: Set<CanonicalSubtype>] = [:]
    /// Soft subtype/style signals by layer (used for scoring, not strict filtering).
    public var subtypeByKind: [LayerKind: Set<String>] = [:]

    /// Ensure these layers appear in the final outfit (e.g., require .shoes).
    public var requiredKinds: Set<LayerKind> = []
    /// Global colors mentioned anywhere in the prompt (used as soft palette hints).
    public var globalColors: Set<String> = []

    /// High-level style words (minimal, sporty, chic, …).
    public var styleTags: Set<String> = []
    /// Target dress code bucket (e.g., "smart casual").
    public var dressCode: String? = nil
    /// Occasion extracted from the prompt (wedding, interview, office, …).
    public var occasion: String? = nil
    /// Requested palette mode (monochrome, neutral, pastel, earth, colorful, none).
    public var palette: PaletteMode = .none
    /// If true, prefer a dress-based outfit; if false, prefer top+bottom; nil = no bias.
    public var wantsDressBase: Bool? = nil
    /// Nudge: include outerwear (e.g., for “cold/winter/chilly” prompts).
    public var preferOuterwear = false
    /// Nudge: avoid outerwear (e.g., for “hot/summer/warm” prompts).
    public var avoidOuterwear = false
    /// Metallic accessory color preference (“gold” or “silver”).
    public var metallic: String? = nil
}

/// Tiny helpers for case/diacritic-insensitive substring matching.
public enum TextMatch {
    /// Normalize a string: strip diacritics, lowercase, and remove non-alphanumerics.
    @inline(__always) static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
    /// Returns true if `hay` contains `needle` ignoring case/diacritics/punctuation.
    @inline(__always) public static func containsInsensitive(_ hay: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return norm(hay).contains(norm(needle))
    }
}

/// Keyword → LayerKind mapping for quick detection of requested layers.
/// (Add synonyms as your taxonomy grows.)
private let kindLexicon: [String: LayerKind] = [
    // Dress family
    "dress": .dress, "gown": .dress, "slip": .dress,
    // Tops
    "top": .top, "shirt": .top, "tee": .top, "tshirt": .top, "blouse": .top, "hoodie": .top, "sweater": .top, "jumper": .top, "cardigan": .top, "tank": .top, "camisole": .top,
    // Bottoms
    "bottom": .bottom, "pants": .bottom, "trouser": .bottom, "trousers": .bottom, "jeans": .bottom, "denim": .bottom, "skirt": .bottom, "shorts": .bottom, "leggings": .bottom,
    // Shoes
    "shoes": .shoes, "shoe": .shoes, "heels": .shoes, "heel": .shoes, "pumps": .shoes, "sneakers": .shoes, "sneaker": .shoes, "trainers": .shoes, "trainer": .shoes, "boots": .shoes, "boot": .shoes, "loafers": .shoes, "loafer": .shoes, "sandals": .shoes, "sandal": .shoes, "mules": .shoes, "mule": .shoes,
    // Outerwear
    "outerwear": .outerwear, "jacket": .outerwear, "coat": .outerwear, "blazer": .outerwear, "trench": .outerwear, "parka": .outerwear,
    // Bags
    "bag": .bag, "purse": .bag, "handbag": .bag, "tote": .bag, "clutch": .bag, "crossbody": .bag,
    // Accessories
    "accessory": .accessory, "accessories": .accessory, "belt": .accessory, "scarf": .accessory, "hat": .accessory, "sunglasses": .accessory, "jewelry": .accessory
]

/// Parse a natural-language prompt into a structured `PromptQuery`.
/// The parser is intentionally “soft”: it records strict requirements only when
/// explicit (e.g., "red shoes"), and otherwise stores signals for scoring.
public func parsePrompt(_ text: String) -> PromptQuery {
    var q = PromptQuery()
    let lower = text.lowercased()

    // ─────────────────────────────────────────────────────────────────────────
    // Dress code / occasion (broad buckets via insensitive contains)
    // ─────────────────────────────────────────────────────────────────────────
    if TextMatch.containsInsensitive(lower, "smart casual") { q.dressCode = "smart casual" }
    else if TextMatch.containsInsensitive(lower, "smart")    { q.dressCode = "smart" }
    else if TextMatch.containsInsensitive(lower, "casual")   { q.dressCode = "casual" }

    if TextMatch.containsInsensitive(lower, "wedding")   { q.occasion = "wedding" }
    if TextMatch.containsInsensitive(lower, "interview") { q.occasion = "interview" }
    if TextMatch.containsInsensitive(lower, "office")    { q.occasion = "office" }
    if TextMatch.containsInsensitive(lower, "date")      { q.occasion = "date" }
    if TextMatch.containsInsensitive(lower, "party")     { q.occasion = "party" }
    if TextMatch.containsInsensitive(lower, "beach")     { q.occasion = "beach" }
    if TextMatch.containsInsensitive(lower, "gym")       { q.occasion = "gym" }

    // Weather hints → nudge outerwear on/off
    if TextMatch.containsInsensitive(lower, "cold") || TextMatch.containsInsensitive(lower, "winter") || TextMatch.containsInsensitive(lower, "chilly") {
        q.preferOuterwear = true
    }
    if TextMatch.containsInsensitive(lower, "hot") || TextMatch.containsInsensitive(lower, "summer") || TextMatch.containsInsensitive(lower, "warm") {
        q.avoidOuterwear = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Tokenize and drop common glue words to simplify windowed scans
    // ─────────────────────────────────────────────────────────────────────────
    let rawTokens = lower
        .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
        .split(separator: " ")
        .map(String.init)

    // Remove stopwords to make neighbor windows cleaner.
    let stop = Set(["and","with","in","for","to","a","an","the","please"])
    let tokens = rawTokens.filter { !stop.contains($0) }

    // ─────────────────────────────────────────────────────────────────────────
    // Palette detection (monochrome/neutral/pastel/earth/colorful)
    // Supports: "all <color>", "monochrome", "neutral", "pastel", "earth/earthy/…", "colorful/bright"
    // ─────────────────────────────────────────────────────────────────────────
    if let i = tokens.firstIndex(of: "all"), i+1 < tokens.count, let c = ColorLexicon.normalize(tokens[i+1]) {
        // "all <color>" → strict monochrome of that color
        q.palette = .monochrome(color: c, strict: true)
        q.globalColors.insert(c)
    } else if TextMatch.containsInsensitive(lower, "monochrome") {
        // Just “monochrome” with no color → engine can keep tones cohesive
        q.palette = .monochrome(color: nil, strict: true)
    } else if TextMatch.containsInsensitive(lower, "neutral") {
        q.palette = .neutral
    } else if ["pastel","soft","light","baby","muted"].contains(where: { TextMatch.containsInsensitive(lower, $0) }) {
        q.palette = .pastel
    } else if ["earth","earthy","terra","khaki","olive","camel","brown","beige","tan"].contains(where: { TextMatch.containsInsensitive(lower, $0) }) {
        q.palette = .earth
    } else if TextMatch.containsInsensitive(lower, "colorful") || TextMatch.containsInsensitive(lower, "bright") {
        q.palette = .colorful
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Style adjectives (soft tags)
    // ─────────────────────────────────────────────────────────────────────────
    let styles = ["minimal","sporty","edgy","boho","preppy","streetwear","vintage","romantic","chic","classy","elegant","bold","trendy"]
    q.styleTags = Set(styles.filter { TextMatch.containsInsensitive(lower, $0) })

    // Metallic accessories (simple preference signal)
    if TextMatch.containsInsensitive(lower, "gold")   { q.metallic = "gold" }
    if TextMatch.containsInsensitive(lower, "silver") { q.metallic = "silver" }

    // ─────────────────────────────────────────────────────────────────────────
    // Hard kind & subtype detection from individual tokens
    // - SubtypeLexicon.canonical(for:) maps a token to (LayerKind, CanonicalSubtype)
    // - kindLexicon maps explicit layer words to LayerKind
    // ─────────────────────────────────────────────────────────────────────────
    for t in tokens {
        if let (kind, canon) = SubtypeLexicon.canonical(for: t) {
            q.requiredSubtypesByKind[kind, default: []].insert(canon)
            q.requiredKinds.insert(kind)
            // Mentioning a bottom subtype implies we likely don't want a dress base.
            if kind == .bottom { q.wantsDressBase = false }
        }
        if let k = kindLexicon[t] {
            q.requiredKinds.insert(k)
        }
    }

    // Prefer a dress base if “dress/gown/slip” appears and we didn't already bias to bottoms.
    if tokens.contains(where: { ["dress","gown","slip"].contains($0) }) {
        q.wantsDressBase = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Forward window scan to bind colors to kinds:
    // e.g., "red shoes", "black blazer", "white dress" within a small distance.
    // Also collect all normalized color mentions into `globalColors`.
    // ─────────────────────────────────────────────────────────────────────────
    let window = 3
    for i in 0..<tokens.count {
        guard let colorBase = ColorLexicon.normalize(tokens[i]) else { continue }
        let family = ColorLexicon.expandFamily(for: colorBase) // include close shades if you want softer matching

        var j = i + 1
        while j < min(tokens.count, i + 1 + window) {
            let t = tokens[j]
            if let kind = kindLexicon[t] {
                // Bind this color family strictly to that layer (hard filter).
                q.requiredColorsByKind[kind, default: []].formUnion(family)
                q.requiredKinds.insert(kind)
                break
            }
            j += 1
        }
        // Track globally even if not bound to a specific kind.
        q.globalColors.insert(colorBase)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Soft subtype bag by coarse families (for scoring):
    // if any of these appear, attach them to the corresponding LayerKind.
    // ─────────────────────────────────────────────────────────────────────────
    let subtypeMap: [(words:[String], kind: LayerKind)] = [
        (["jeans","denim","trouser","trousers","pants","slacks","skirt","shorts","leggings"], .bottom),
        (["hoodie","sweater","jumper","cardigan","crewneck","blouse","shirt","tee","t-shirt","tank","camisole","top"], .top),
        (["heel","heels","pump","pumps","stiletto","sneaker","sneakers","trainer","trainers","boot","boots","chelsea","combat","knee","loafer","loafers","sandal","sandals","mule","mules","flat","flats"], .shoes),
        (["jacket","blazer","coat","trench","parka"], .outerwear),
    ]
    for (ws, kind) in subtypeMap where ws.contains(where: { tokens.contains($0) }) {
        q.subtypeByKind[kind, default: []].formUnion(ws)
    }

    return q
}
