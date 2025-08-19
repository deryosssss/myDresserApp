//
//  OutfitEngine.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//
//  Given a parsed `PromptQuery` and the user's wardrobe (via `ManualSuggestionStore`),
//  assemble a single outfit candidate composed of 2–5 items (dress OR top+bottom,
//  plus shoes and optional layers). The engine:
//    1) fetches items by LayerKind,
//    2) applies hard prefilters (color/subtype) with graceful relaxation,
//    3) scores remaining items against the prompt,
//    4) picks from a top band to keep variation,
//    5) returns `PCOutfitCandidate` noting if we had to relax constraints.
//

import Foundation

/// One outfit suggestion built by the engine.
struct PCOutfitCandidate: Identifiable, Equatable {
    let id = UUID()

    /// Concrete picks by logical layer (e.g. [.top: tee, .bottom: jeans, .shoes: sneakers])
    var itemsByKind: [LayerKind: WardrobeItem]

    /// Optional note for UI when we relaxed a hard constraint (color/subtype).
    var softMatchNote: String? = nil

    /// Stable thumbnail order for rendering in the UI.
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

/// Turns a `PromptQuery` into outfit candidates using the user’s wardrobe.
final class OutfitEngine {

    private let query: PromptQuery
    private let store: ManualSuggestionStore
    private let userId: String

    init(userId: String, query: PromptQuery, store: ManualSuggestionStore) {
        self.userId = userId
        self.query = query
        self.store = store
    }

    /// Convenience: fetch a bucket of items for a `LayerKind`.
    private func fetch(_ kind: LayerKind, limit: Int = 600) async -> [WardrobeItem] {
        (try? await store.fetchItems(userId: userId, for: kind, limit: limit)) ?? []
    }

    /// Normalizes item colors to our lexicon tokens (e.g., "Grey" -> "gray").
    private func normalizedColors(of item: WardrobeItem) -> Set<String> {
        Set(item.colours.compactMap { ColorLexicon.normalize($0) })
    }

    // MARK: - Prefilter with hard Color + Subtype

    /// Why we had to relax prefilters (helpful for UX copy).
    private enum RelaxReason {
        case none
        case color
        case subtype(Set<CanonicalSubtype>)
        case both(Set<CanonicalSubtype>)
    }

    /// Calculates a *hard* color set for a layer (bound color, or monochrome coherence).
    private func hardColorSet(for kind: LayerKind, coherence: String?) -> Set<String>? {
        // 1) Explicit hard colors for this kind win.
        if let required = query.requiredColorsByKind[kind], !required.isEmpty { return required }
        // 2) Monochrome palette: if strict, enforce a single hue (chosen or inferred).
        if case .monochrome(let c, let strict) = query.palette, strict {
            if let chosen = c ?? coherence { return [chosen] }
        }
        return nil
    }

    /// Applies hard color/subtype filters. If nothing survives, produces a relaxed pool and a reason.
    ///
    /// - Returns:
    ///   - strict: items passing *all* hard constraints (color + subtype)
    ///   - relaxed: fallback items (used only when `strict` is empty)
    ///   - reason: why we had to relax (for user-facing note)
    private func prefilter(items: [WardrobeItem],
                           kind: LayerKind,
                           coherence: String?) -> (strict: [WardrobeItem], relaxed: [WardrobeItem], reason: RelaxReason)
    {
        let hardColors = hardColorSet(for: kind, coherence: coherence)
        let hardSub = query.requiredSubtypesByKind[kind] ?? []

        // Soft color pool built from all global mentions (expanded to families/shades).
        let softColors: Set<String> = !query.globalColors.isEmpty
            ? Set(query.globalColors.flatMap { ColorLexicon.expandFamily(for: $0) })
            : []

        var strict: [WardrobeItem] = []
        var relaxed: [WardrobeItem] = []

        // 1) Collect items that satisfy *all* hard constraints.
        for it in items {
            let cols = normalizedColors(of: it)
            let hay  = searchableText(for: it)

            // Hard subtype check using SubtypeLexicon
            let subOK = SubtypeLexicon.matches(itemHaystack: hay,
                                               itemSubcategory: it.subcategory,
                                               kind: kind,
                                               required: hardSub)

            // Hard color check
            let colorOK = hardColors.map { !cols.isDisjoint(with: $0) } ?? true

            if colorOK && subOK {
                strict.append(it)
            } else {
                // Hard-failing items are not considered strict; we may still use them in relaxed later.
                continue
            }
        }

        // 2) If nothing passed hard constraints, assemble a relaxed pool (soft color bias first).
        if strict.isEmpty {
            for it in items {
                let cols = normalizedColors(of: it)
                if !softColors.isEmpty, !cols.isDisjoint(with: softColors) {
                    relaxed.append(it); continue
                }
                relaxed.append(it)
            }
        }

        // 3) Explain the relaxation reason (if any) for the UI.
        let reason: RelaxReason = {
            if !strict.isEmpty { return .none }
            if hardColors != nil && !hardSub.isEmpty { return .both(hardSub) }
            if hardColors != nil { return .color }
            if !hardSub.isEmpty { return .subtype(hardSub) }
            return .none
        }()

        return (strict, relaxed, reason)
    }

    // MARK: - Scoring

    /// Builds a normalized searchable string for an item combining multiple fields/tags.
    private func searchableText(for item: WardrobeItem) -> String {
        var parts: [String] = [
            item.category, item.subcategory, item.style, item.designPattern,
            item.material, item.fit, item.dressCode
        ]
        parts.append(contentsOf: item.customTags)
        parts.append(contentsOf: item.moodTags)
        return TextMatch.norm(parts.joined(separator: " "))
    }

    /// Assigns a score to an item for a given layer, considering prompt signals.
    /// Higher is better; used to pick from a top performance band.
    private func score(_ item: WardrobeItem, kind: LayerKind, coherenceColor: String?) -> Int {
        var score = 0
        let hay = searchableText(for: item)
        let its = normalizedColors(of: item)

        // Dress code and occasion
        if let dc = query.dressCode, !dc.isEmpty, TextMatch.containsInsensitive(item.dressCode, dc) { score += 25 }
        if let occ = query.occasion, TextMatch.containsInsensitive(hay, occ) { score += 15 }

        // Hard bound colors for this kind (reward strongly)
        if let req = query.requiredColorsByKind[kind], !req.isEmpty, !its.isDisjoint(with: req) { score += 60 }

        // Soft global color hints (bonus)
        let soft = !query.globalColors.isEmpty ? Set(query.globalColors.flatMap { ColorLexicon.expandFamily(for: $0) }) : []
        if !soft.isEmpty, !its.isDisjoint(with: soft) { score += 25 }

        // Monochrome coherence: reward matching the chosen/propagated hue
        if case .monochrome(let cOpt, _) = query.palette {
            let candidate = coherenceColor ?? cOpt
            if let coh = candidate, its.contains(coh) { score += 35 } else { score -= 10 }
        }

        // Palette modes (simple heuristics)
        switch query.palette {
        case .neutral:
            if !its.isDisjoint(with: ColorLexicon.neutrals) { score += 20 }
        case .pastel:
            if TextMatch.containsInsensitive(item.style, "pastel") { score += 15 }
        case .earth:
            if its.contains("brown") || its.contains("beige") || its.contains("green") { score += 15 }
        default: break
        }

        // Subtype/vibe (soft)
        if let subs = query.subtypeByKind[kind], !subs.isEmpty,
           subs.contains(where: { TextMatch.containsInsensitive(hay, $0) }) { score += 35 }

        if !query.styleTags.isEmpty,
           query.styleTags.contains(where: { TextMatch.containsInsensitive(hay, $0) }) { score += 18 }

        // Metallic preference mainly for accessories
        if kind == .accessory, let metal = query.metallic,
           TextMatch.containsInsensitive(hay, metal) { score += 25 }

        // Weather nudges for outerwear
        if kind == .outerwear {
            if query.preferOuterwear { score += 30 }
            if query.avoidOuterwear  { score -= 40 }
        }

        return score
    }

    /// Picks a single item from a bucket: score everything, keep a top band, then randomize.
    private func pick(kind: LayerKind, from items: [WardrobeItem], coherenceColor: String?) -> WardrobeItem? {
        guard !items.isEmpty else { return nil }
        let scored = items.map { ($0, score($0, kind: kind, coherenceColor: coherenceColor)) }
        let maxScore = scored.map(\.1).max() ?? 0
        let topBand = max(0, maxScore - 10)       // allow small diversity within 10 points of the best
        let top = scored.filter { $0.1 >= topBand }.map(\.0)
        return (top.isEmpty ? items : top).randomElement()
    }

    // MARK: - Generate

    /// Builds one `PCOutfitCandidate` honoring the prompt as much as possible.
    func generateCandidate() async -> PCOutfitCandidate? {
        // 1) Fetch buckets concurrently (faster than sequential awaits).
        async let dresses = fetch(.dress)
        async let tops    = fetch(.top)
        async let bottoms = fetch(.bottom)
        async let shoes   = fetch(.shoes)
        async let outer   = fetch(.outerwear)
        async let bags    = fetch(.bag)
        async let accs    = fetch(.accessory)

        var d = await dresses, t = await tops, b = await bottoms, s = await shoes, o = await outer, g = await bags, a = await accs

        // 2) If monochrome, propagate a coherence hue (explicit or inferred later).
        var coherenceColor: String? = nil
        if case .monochrome(let c, _) = query.palette { coherenceColor = c ?? query.globalColors.first }

        // 3) Hard prefilter by kind (color/subtype), remembering relaxation reasons.
        let pfShoes = prefilter(items: s, kind: .shoes,     coherence: coherenceColor)
        let pfDress = prefilter(items: d, kind: .dress,     coherence: coherenceColor)
        let pfTop   = prefilter(items: t, kind: .top,       coherence: coherenceColor)
        let pfBot   = prefilter(items: b, kind: .bottom,    coherence: coherenceColor)
        let pfOut   = prefilter(items: o, kind: .outerwear, coherence: coherenceColor)
        let pfBag   = prefilter(items: g, kind: .bag,       coherence: coherenceColor)
        let pfAcc   = prefilter(items: a, kind: .accessory, coherence: coherenceColor)

        // When strict pool is empty, use relaxed pool and set a user-facing note.
        var softNote: String? = nil
        func pool(_ p: (strict:[WardrobeItem], relaxed:[WardrobeItem], reason: RelaxReason)) -> [WardrobeItem] {
            switch p.reason {
            case .none: break
            case .color:
                softNote = "Closest match (relaxed color)."
            case .subtype(let set):
                softNote = "Closest match (no \(SubtypeLexicon.humanLabel(set)) found)."
            case .both(let set):
                softNote = "Closest match (relaxed color & no \(SubtypeLexicon.humanLabel(set)) found)."
            }
            return p.strict.isEmpty ? p.relaxed : p.strict
        }

        var picked: [LayerKind: WardrobeItem] = [:]

        // 4) Shoes first (users respond strongly to footwear; often the anchor).
        guard let shoe = pick(kind: .shoes, from: pool(pfShoes), coherenceColor: coherenceColor) else { return nil }
        picked[.shoes] = shoe

        // 5) Base: prefer Top+Bottom when bottom is explicitly requested; otherwise follow prompt bias or random.
        let hasBottomRequirement =
            !(query.requiredSubtypesByKind[.bottom] ?? []).isEmpty || query.requiredKinds.contains(.bottom)
        let useDress = hasBottomRequirement ? false : (query.wantsDressBase ?? Bool.random())

        if useDress, let dress = pick(kind: .dress, from: pool(pfDress), coherenceColor: coherenceColor) {
            picked[.dress] = dress
            // If monochrome hue is not chosen yet, infer from dress.
            if coherenceColor == nil, case .monochrome = query.palette {
                coherenceColor = normalizedColors(of: dress).first
            }
        } else if
            let top = pick(kind: .top, from: pool(pfTop), coherenceColor: coherenceColor),
            let bottom = pick(kind: .bottom, from: pool(pfBot), coherenceColor: coherenceColor) {
            picked[.top] = top
            picked[.bottom] = bottom

            // If monochrome hue is not chosen yet, prefer a shared color between top & bottom.
            if coherenceColor == nil, case .monochrome = query.palette {
                let shared = normalizedColors(of: top).intersection(normalizedColors(of: bottom))
                coherenceColor = shared.first ?? coherenceColor
            }
        } else if let dress = pick(kind: .dress, from: pool(pfDress), coherenceColor: coherenceColor) {
            // Fallback to a dress if we couldn't assemble top+bottom.
            picked[.dress] = dress
        } else {
            // No viable base → abort candidate.
            return nil
        }

        // 6) Optional layers: outerwear (weather/prompt nudges), bag, accessory.
        if (!query.avoidOuterwear && Bool.random()) || query.preferOuterwear {
            if let coat = pick(kind: .outerwear, from: pool(pfOut), coherenceColor: coherenceColor) {
                picked[.outerwear] = coat
            }
        }
        if Int.random(in: 0...1) == 0,
           let bag = pick(kind: .bag, from: pool(pfBag), coherenceColor: coherenceColor) {
            picked[.bag] = bag
        }
        if Int.random(in: 0...1) == 0,
           let ac = pick(kind: .accessory, from: pool(pfAcc), coherenceColor: coherenceColor) {
            picked[.accessory] = ac
        }

        // 7) Return the completed candidate (with soft-match note if any).
        return PCOutfitCandidate(itemsByKind: picked, softMatchNote: softNote)
    }
}
