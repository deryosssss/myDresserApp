//
//  PromptParser.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//

import Foundation

public struct PromptQuery {
    public var requiredColorsByKind: [LayerKind: Set<String>] = [:] // strict color per kind
    public var subtypeByKind: [LayerKind: Set<String>] = [:]
    public var globalColors: Set<String> = []
    public var styleTags: Set<String> = []
    public var dressCode: String? = nil
    public var occasion: String? = nil
    public var palette: PaletteMode = .none
    public var wantsDressBase: Bool? = nil
    public var preferOuterwear = false
    public var avoidOuterwear = false
    public var metallic: String? = nil
}

public enum TextMatch {
    @inline(__always) static func norm(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
         .lowercased()
         .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }
    @inline(__always) public static func containsInsensitive(_ hay: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return true }
        return norm(hay).contains(norm(needle))
    }
}

private let kindLexicon: [String: LayerKind] = [
    // core
    "dress": .dress, "gown": .dress, "slip": .dress,
    "top": .top, "shirt": .top, "tee": .top, "tshirt": .top, "blouse": .top, "hoodie": .top, "sweater": .top, "jumper": .top, "cardigan": .top, "tank": .top, "camisole": .top,
    "bottom": .bottom, "pants": .bottom, "trouser": .bottom, "trousers": .bottom, "jeans": .bottom, "denim": .bottom, "skirt": .bottom, "shorts": .bottom, "leggings": .bottom,
    "shoes": .shoes, "shoe": .shoes, "heels": .shoes, "heel": .shoes, "pumps": .shoes, "sneakers": .shoes, "sneaker": .shoes, "trainers": .shoes, "boots": .shoes, "boot": .shoes, "loafers": .shoes, "loafer": .shoes, "sandals": .shoes, "sandal": .shoes, "mules": .shoes, "mule": .shoes,
    "outerwear": .outerwear, "jacket": .outerwear, "coat": .outerwear, "blazer": .outerwear, "trench": .outerwear, "parka": .outerwear,
    "bag": .bag, "purse": .bag, "handbag": .bag, "tote": .bag, "clutch": .bag,
    "accessory": .accessory, "accessories": .accessory, "belt": .accessory, "scarf": .accessory, "hat": .accessory, "jewelry": .accessory, "earrings": .accessory, "necklace": .accessory, "bracelet": .accessory
]

public func parsePrompt(_ text: String) -> PromptQuery {
    var q = PromptQuery()
    let lower = text.lowercased()

    // Dress code / occasion
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

    if TextMatch.containsInsensitive(lower, "cold") || TextMatch.containsInsensitive(lower, "winter") || TextMatch.containsInsensitive(lower, "chilly") {
        q.preferOuterwear = true
    }
    if TextMatch.containsInsensitive(lower, "hot") || TextMatch.containsInsensitive(lower, "summer") || TextMatch.containsInsensitive(lower, "warm") {
        q.avoidOuterwear = true
    }

    // Palette
    let words = lower.replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
                     .split(separator: " ").map(String.init)

    if let allIdx = words.firstIndex(of: "all"), allIdx + 1 < words.count, let c = ColorLexicon.normalize(words[allIdx + 1]) {
        q.palette = .monochrome(color: c, strict: true)
        q.globalColors.insert(c)
    } else if TextMatch.containsInsensitive(lower, "monochrome") {
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

    // Style adjectives
    let styles = ["minimal","sporty","edgy","boho","preppy","streetwear","vintage","romantic","chic","classy","elegant","bold","trendy"]
    q.styleTags = Set(styles.filter { TextMatch.containsInsensitive(lower, $0) })

    // Metallic accessories
    if TextMatch.containsInsensitive(lower, "gold")   { q.metallic = "gold" }
    if TextMatch.containsInsensitive(lower, "silver") { q.metallic = "silver" }

    // tokens for structured parsing
    let tokens = words

    // Prefer dress if “dress/gown/slip” mentioned
    if tokens.contains(where: { ["dress","gown","slip"].contains($0) }) {
        q.wantsDressBase = true
    }

    // Forward-only windowed scan: <color> [adj?] <kind>
    let window = 3
    for i in 0..<tokens.count {
        guard let colorBase = ColorLexicon.normalize(tokens[i]) else { continue }
        let family = ColorLexicon.expandFamily(for: colorBase)

        var j = i + 1
        while j < min(tokens.count, i + 1 + window) {
            let t = tokens[j]
            if let kind = kindLexicon[t] {
                q.requiredColorsByKind[kind, default: []].formUnion(family)
                break
            }
            j += 1
        }
        q.globalColors.insert(colorBase) // record anyway for palette biasing
    }

    // Subtype lexicon (unchanged from your logic, trimmed a bit)
    let subtypeMap: [(words:[String], kind: LayerKind)] = [
        (["jeans","denim","trouser","trousers","pants","slacks","skirt","shorts"], .bottom),
        (["hoodie","sweater","jumper","cardigan","crewneck","blouse","shirt","tee","t-shirt","tank","camisole","top"], .top),
        (["heel","heels","pump","pumps","stiletto","sneaker","sneakers","trainer","trainers","boot","boots","chelsea","combat","knee","loafer","loafers","sandal","sandals","mule","mules"], .shoes),
        (["jacket","blazer","coat","trench","parka"], .outerwear),
    ]
    for (ws, kind) in subtypeMap where ws.contains(where: { tokens.contains($0) }) {
        q.subtypeByKind[kind, default: []].formUnion(ws)
    }

    return q
}
