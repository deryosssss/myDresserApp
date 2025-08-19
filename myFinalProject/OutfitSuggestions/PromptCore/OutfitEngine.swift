//
//  OutfitEngine.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//

import Foundation

struct PCOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind: WardrobeItem]
    var softMatchNote: String? = nil // when we had to relax

    var orderedItems: [WardrobeItem] {
        var arr: [WardrobeItem] = []
        if let d   = itemsByKind[.dress]     { arr.append(d) }
        if let t   = itemsByKind[.top]       { arr.append(t) }
        if let o   = itemsByKind[.outerwear] { arr.append(o) }
        if let b   = itemsByKind[.bottom]    { arr.append(b) }
        if let s   = itemsByKind[.shoes]     { arr.append(s) }
        if let bag = itemsByKind[.bag]       { arr.append(bag) }
        if let acc = itemsByKind[.accessory] { arr.append(acc) }
        return arr
    }

    static func == (lhs: PCOutfitCandidate, rhs: PCOutfitCandidate) -> Bool { lhs.id == rhs.id }
}

final class OutfitEngine {

    private let query: PromptQuery
    private let store: ManualSuggestionStore
    private let userId: String

    init(userId: String, query: PromptQuery, store: ManualSuggestionStore) {
        self.userId = userId
        self.query = query
        self.store = store
    }

    // MARK: - Fetch
    private func fetch(_ kind: LayerKind, limit: Int = 600) async -> [WardrobeItem] {
        (try? await store.fetchItems(userId: userId, for: kind, limit: limit)) ?? []
    }

    private func normalizedColors(of item: WardrobeItem) -> Set<String> {
        Set(item.colours.compactMap { ColorLexicon.normalize($0) })
    }

    // MARK: - Filtering

    private func hardColorSet(for kind: LayerKind, coherence: String?) -> Set<String>? {
        if let required = query.requiredColorsByKind[kind], !required.isEmpty {
            return required
        }
        if case .monochrome(let c, let strict) = query.palette, strict {
            if let chosen = c ?? coherence { return [chosen] }
        }
        return nil
    }

    private func softColorSet() -> Set<String> {
        if !query.globalColors.isEmpty {
            // broaden to families for nicer coverage
            return Set(query.globalColors.flatMap { ColorLexicon.expandFamily(for: $0) })
        }
        return []
    }

    private func prefilter(items: [WardrobeItem], kind: LayerKind, coherence: String?) -> (strict: [WardrobeItem], relaxed: [WardrobeItem]) {
        let hard = hardColorSet(for: kind, coherence: coherence)
        let soft = softColorSet()

        var strict: [WardrobeItem] = []
        var relaxed: [WardrobeItem] = []
        for it in items {
            let cols = normalizedColors(of: it)
            if let hard = hard, !cols.isDisjoint(with: hard) {
                strict.append(it); continue
            }
            if let hard = hard, cols.isDisjoint(with: hard) {
                continue // reject if strict required and not matched
            }
            if !soft.isEmpty, !cols.isDisjoint(with: soft) {
                relaxed.append(it); continue
            }
            relaxed.append(it)
        }
        return (strict, relaxed)
    }

    // MARK: - Scoring

    private func searchableText(for item: WardrobeItem) -> String {
        var parts: [String] = [
            item.category, item.subcategory, item.style, item.designPattern,
            item.material, item.fit, item.dressCode
        ]
        parts.append(contentsOf: item.customTags)
        parts.append(contentsOf: item.moodTags)
        return TextMatch.norm(parts.joined(separator: " "))
    }

    private func score(_ item: WardrobeItem, kind: LayerKind, coherenceColor: String?) -> Int {
        var score = 0
        let hay = searchableText(for: item)
        let its = normalizedColors(of: item)

        // Dress code / occasion
        if let dc = query.dressCode, !dc.isEmpty, TextMatch.containsInsensitive(item.dressCode, dc) { score += 25 }
        if let occ = query.occasion, TextMatch.containsInsensitive(hay, occ) { score += 15 }

        // Explicit required pairs get a big boost
        if let req = query.requiredColorsByKind[kind], !req.isEmpty, !its.isDisjoint(with: req) { score += 60 }

        // Global colors (soft preference)
        let soft = softColorSet()
        if !soft.isEmpty, !its.isDisjoint(with: soft) { score += 25 }

        // Monochrome coherence
        if case .monochrome(let cOpt, _) = query.palette {
            let candidate = coherenceColor ?? cOpt
            if let coh = candidate, its.contains(coh) { score += 35 } else { score -= 10 }
        }

        // Palette vibes
        switch query.palette {
        case .neutral:
            if !its.isDisjoint(with: ColorLexicon.neutrals) { score += 20 }
        case .pastel:
            if TextMatch.containsInsensitive(item.style, "pastel") { score += 15 }
        case .earth:
            if its.contains("brown") || its.contains("beige") || its.contains("green") { score += 15 }
        default: break
        }

        // Subtypes
        if let subs = query.subtypeByKind[kind], !subs.isEmpty,
           subs.contains(where: { TextMatch.containsInsensitive(hay, $0) }) { score += 35 }

        // Style adjectives
        if !query.styleTags.isEmpty, query.styleTags.contains(where: { TextMatch.containsInsensitive(hay, $0) }) {
            score += 18
        }

        // Metallic accessories
        if kind == .accessory, let metal = query.metallic, TextMatch.containsInsensitive(hay, metal) { score += 25 }

        // Outerwear preference/avoidance
        if kind == .outerwear {
            if query.preferOuterwear { score += 30 }
            if query.avoidOuterwear  { score -= 40 }
        }

        return score
    }

    private func pick(kind: LayerKind, from items: [WardrobeItem], coherenceColor: String?) -> WardrobeItem? {
        guard !items.isEmpty else { return nil }
        let scored = items.map { ($0, score($0, kind: kind, coherenceColor: coherenceColor)) }
        let maxScore = scored.map(\.1).max() ?? 0
        let topBand = max(0, maxScore - 10)
        let top = scored.filter { $0.1 >= topBand }.map(\.0)
        return (top.isEmpty ? items : top).randomElement()
    }

    // MARK: - Public-ish API (internal by default)

    func generateCandidate() async -> PCOutfitCandidate? {
        async let dresses = fetch(.dress)
        async let tops    = fetch(.top)
        async let bottoms = fetch(.bottom)
        async let shoes   = fetch(.shoes)
        async let outer   = fetch(.outerwear)
        async let bags    = fetch(.bag)
        async let accs    = fetch(.accessory)

        var d = await dresses, t = await tops, b = await bottoms, s = await shoes, o = await outer, g = await bags, a = await accs

        // Decide a coherence color in monochrome
        var coherenceColor: String? = nil
        if case .monochrome(let c, _) = query.palette {
            coherenceColor = c ?? query.globalColors.first
        }

        // Pre-filter by color constraints
        let pfShoes = prefilter(items: s, kind: .shoes, coherence: coherenceColor)
        let pfDress = prefilter(items: d, kind: .dress, coherence: coherenceColor)
        let pfTop   = prefilter(items: t, kind: .top, coherence: coherenceColor)
        let pfBot   = prefilter(items: b, kind: .bottom, coherence: coherenceColor)
        let pfOut   = prefilter(items: o, kind: .outerwear, coherence: coherenceColor)
        let pfBag   = prefilter(items: g, kind: .bag, coherence: coherenceColor)
        let pfAcc   = prefilter(items: a, kind: .accessory, coherence: coherenceColor)

        var softNote: String? = nil
        func pool(_ pair: (strict:[WardrobeItem], relaxed:[WardrobeItem])) -> [WardrobeItem] {
            if !pair.strict.isEmpty { return pair.strict }
            softNote = "Closest match (relaxed color)."
            return pair.relaxed
        }

        var picked: [LayerKind: WardrobeItem] = [:]

        // Shoes first
        guard let shoe = pick(kind: .shoes, from: pool(pfShoes), coherenceColor: coherenceColor) else { return nil }
        picked[.shoes] = shoe

        // Base: Dress OR Top+Bottom
        let useDress = query.wantsDressBase ?? Bool.random()

        if useDress, let dress = pick(kind: .dress, from: pool(pfDress), coherenceColor: coherenceColor) {
            picked[.dress] = dress
            if coherenceColor == nil, case .monochrome = query.palette {
                coherenceColor = normalizedColors(of: dress).first
            }
        } else if
            let top = pick(kind: .top, from: pool(pfTop), coherenceColor: coherenceColor),
            let bottom = pick(kind: .bottom, from: pool(pfBot), coherenceColor: coherenceColor) {
            picked[.top] = top
            picked[.bottom] = bottom
            if coherenceColor == nil, case .monochrome = query.palette {
                let shared = normalizedColors(of: top).intersection(normalizedColors(of: bottom))
                coherenceColor = shared.first ?? coherenceColor
            }
        } else if let dress = pick(kind: .dress, from: pool(pfDress), coherenceColor: coherenceColor) {
            picked[.dress] = dress
        } else {
            return nil
        }

        // Optionals
        if (!query.avoidOuterwear && Bool.random()) || query.preferOuterwear {
            if let coat = pick(kind: .outerwear, from: pool(pfOut), coherenceColor: coherenceColor) {
                picked[.outerwear] = coat
            }
        }
        if Int.random(in: 0...1) == 0, let bag = pick(kind: .bag, from: pool(pfBag), coherenceColor: coherenceColor) {
            picked[.bag] = bag
        }
        if Int.random(in: 0...1) == 0, let ac = pick(kind: .accessory, from: pool(pfAcc), coherenceColor: coherenceColor) {
            picked[.accessory] = ac
        }

        return PCOutfitCandidate(itemsByKind: picked, softMatchNote: softNote)
    }
}
