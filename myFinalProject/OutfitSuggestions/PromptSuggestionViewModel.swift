//
//  PromptSuggestionViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//
 
//  Purpose:
//  Turn a short, natural-language prompt (e.g. “smart casual, all white, boots”)
//  into concrete outfit suggestions built from the user’s own wardrobe.
//  This is local (no external AI): parse keywords → derive prefs →
//  fetch items by layer → soft-filter → assemble 2–5 item looks → save to Firestore.
//

import Foundation
import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Card / Candidate

/// One outfit suggestion card (one item per logical layer).
struct PSOutfitCandidate: Identifiable, Equatable {
    let id = UUID()

    /// Concrete picks by layer, e.g. [.top: tee, .bottom: jeans, .shoes: sneakers]
    var itemsByKind: [LayerKind: WardrobeItem]

    /// Stable display order for thumbnails in the UI.
    /// (Dress first; if no dress, top → outerwear → bottom → shoes → bag → accessory.)
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

    static func == (lhs: PSOutfitCandidate, rhs: PSOutfitCandidate) -> Bool { lhs.id == rhs.id }
}

// MARK: - Prompt Preferences (lightweight rules – no external API)

/// Parsed intent from the user's free-text prompt.
/// Flags are "soft" constraints: we try to honor them without over-filtering to zero.
fileprivate struct PromptPrefs {
    // Colors
    var colors: [String] = []            // tokens we’d like to see (soft “any-of”)
    var onlyColor: String? = nil         // set when user says “all <color>” / “monochrome <color>”

    // Dress code
    var dressCode: String? = nil         // "casual" | "smart casual" | "smart"

    // Category / item-type nudges
    var wantDress = false
    var wantSkirt = false
    var wantJeans = false

    // Shoes
    var wantSneakers = false
    var wantBoots = false
    var wantHeels = false

    // Layers / extras
    var wantOuter = false
    var wantBag   = false
    var wantAccessories = false

    // Vibes (kept for future scoring)
    var vibeWords: [String] = []

    /// True when user explicitly asked for a single monochrome color.
    var isMonochrome: Bool { onlyColor != nil }
}

@MainActor
final class PromptSuggestionViewModel: ObservableObject {
    // MARK: Published UI state

    /// Deck of suggestion cards currently shown.
    @Published var cards: [PSOutfitCandidate] = []

    /// Work indicator for the generator.
    @Published var isLoading = false

    /// User-visible error (shown via an alert).
    @Published var errorMessage: String? = nil

    // MARK: Inputs / dependencies

    let userId: String
    /// Repository used to fetch items by layer (already filtered by your rules).
    private let store = ManualSuggestionStore()

    init(userId: String) {
        self.userId = userId
    }

    // MARK: Public actions

    /// Parses a prompt → builds `count` candidates.
    func generate(prompt: String, count: Int = 2) async {
        // Guard: empty prompt
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "Please enter a short prompt."
            return
        }

        let prefs = parse(prompt: prompt)   // 1) derive soft constraints
        isLoading = true
        defer { isLoading = false }

        cards.removeAll()

        // 2) Try to build up to `count` suggestions
        for _ in 0..<count {
            if let c = await buildCandidate(prefs: prefs) { cards.append(c) }
        }

        // 3) Friendly message if nothing matched
        if cards.isEmpty {
            errorMessage = "I couldn’t find items that match this prompt. Try loosening it a little."
        }
    }

    /// Removes a card and replaces it with a new one in the same “preference neighborhood”.
    func skip(_ id: PSOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }

        // Try to infer prefs from remaining cards to keep continuity; else neutral prefs.
        let prefs = latestPrefsFromCurrentCards() ?? PromptPrefs()
        if let c = await buildCandidate(prefs: prefs) {
            cards.append(c)
        }
    }

    /// Persists the chosen outfit under `/users/{uid}/outfits/{doc}` in Firestore.
    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {
        // Resolve current user (fallback to injected userId).
        let uid = Auth.auth().currentUser?.uid ?? userId
        guard !uid.isEmpty else {
            errorMessage = "Please sign in."
            return
        }

        do {
            // Compose a minimal outfit document. First item image acts as hero.
            let itemIDs = items.compactMap { $0.id }
            let urls = items.map { $0.imageURL }
            let payload: [String: Any] = [
                "name": name,
                "description": description ?? "",
                "imageURL": urls.first ?? "",
                "itemImageURLs": urls,
                "itemIDs": itemIDs,
                "tags": [],
                "occasion": occasion ?? "",
                "wearCount": 0,
                "isFavorite": isFavorite,
                "source": "prompt",
                "createdAt": FieldValue.serverTimestamp(),
                "date": date != nil ? Timestamp(date: date!) : FieldValue.serverTimestamp()
            ]

            // Write and notify success.
            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()

            try await ref.setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            // Surface failure and haptic.
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Core building

    /// Builds one candidate using the given prefs, or returns nil if impossible.
    private func buildCandidate(prefs: PromptPrefs) async -> PSOutfitCandidate? {
        // 1) Pull buckets concurrently (faster than sequential awaits).
        async let dresses = store.fetchItems(userId: userId, for: .dress,     limit: 300)
        async let tops    = store.fetchItems(userId: userId, for: .top,       limit: 400)
        async let bottoms = store.fetchItems(userId: userId, for: .bottom,    limit: 400)
        async let shoes   = store.fetchItems(userId: userId, for: .shoes,     limit: 300)
        async let outer   = store.fetchItems(userId: userId, for: .outerwear, limit: 200)
        async let bags    = store.fetchItems(userId: userId, for: .bag,       limit: 200)
        async let accs    = store.fetchItems(userId: userId, for: .accessory, limit: 200)

        // 2) Gracefully default to empty arrays on fetch errors.
        var D = (try? await dresses) ?? []
        var T = (try? await tops) ?? []
        var B = (try? await bottoms) ?? []
        var S = (try? await shoes) ?? []
        var O = (try? await outer) ?? []
        var G = (try? await bags) ?? []
        var A = (try? await accs) ?? []

        // 3) Apply soft filters derived from the prompt.
        D = filter(D, with: prefs, kind: .dress)
        T = filter(T, with: prefs, kind: .top)
        B = filter(B, with: prefs, kind: .bottom)
        S = filter(S, with: prefs, kind: .shoes)
        O = filter(O, with: prefs, kind: .outerwear)
        G = filter(G, with: prefs, kind: .bag)
        A = filter(A, with: prefs, kind: .accessory)

        // 4) Shoes first (users react strongly to footwear); try honoring specific shoe prefs.
        guard let shoesPick = pickShoes(from: S, prefs: prefs) else { return nil }
        var items: [LayerKind: WardrobeItem] = [.shoes: shoesPick]

        // 5) Base: if explicitly asked for a dress, prefer it; else 50/50 dress vs top+bottom.
        if prefs.wantDress, let d = D.randomElement() {
            items[.dress] = d
        } else {
            let chooseDress = Bool.random()
            if chooseDress, let d = D.randomElement() {
                items[.dress] = d
            } else if let t = T.randomElement(), let b = B.randomElement() {
                items[.top] = t
                items[.bottom] = b
            } else if let d = D.randomElement() {
                // Fallback if we have no valid top/bottom.
                items[.dress] = d
            } else {
                // Can't build a coherent base → abort.
                return nil
            }
        }

        // 6) Optionals: nudge by prefs with some randomness to keep variety.
        if (!O.isEmpty && (prefs.wantOuter || Int.random(in: 0...100) < 40)),
           let o = O.randomElement() { items[.outerwear] = o }

        if (!G.isEmpty && (prefs.wantBag || Int.random(in: 0...100) < 35)),
           let g = G.randomElement() { items[.bag] = g }

        if (!A.isEmpty && (prefs.wantAccessories || Int.random(in: 0...100) < 35)),
           let a = A.randomElement() { items[.accessory] = a }

        // 7) Keep the card tidy: hard cap to 5 items total.
        if items.count > 5 {
            let dropOrder: [LayerKind] = [.accessory, .bag, .outerwear]
            for k in dropOrder where items.count > 5 { items.removeValue(forKey: k) }
        }

        return PSOutfitCandidate(itemsByKind: items)
    }

    // MARK: - Filtering helpers

    /// Single lowercased text bucket used by color and subtype matching.
    private func textBucket(_ item: WardrobeItem) -> String {
        (
            item.colours.joined(separator: " ") + " " +
            item.customTags.joined(separator: " ") + " " +
            item.category + " " + item.subcategory
        ).lowercased()
    }

    /// Applies soft constraints for dress code, color (including monochrome), and subtype nudges by layer.
    private func filter(_ items: [WardrobeItem], with prefs: PromptPrefs, kind: LayerKind) -> [WardrobeItem] {
        var arr = items

        // Monochrome (“all <color>” / “monochrome <color>”): prefer items that explicitly match that color.
        if let only = prefs.onlyColor {
            let mono = arr.filter { textBucket($0).contains(only) }
            if !mono.isEmpty { arr = mono } // soft: only apply if non-empty
        }

        // Dress code: keep items whose dressCode contains the target token.
        if let code = prefs.dressCode {
            let token = code.lowercased()
            let filtered = arr.filter { $0.dressCode.lowercased().contains(token) }
            if !filtered.isEmpty { arr = filtered } // soft
        }

        // Colors (any-of): keep items that mention any of the desired colors.
        if !prefs.colors.isEmpty {
            let want = Set(prefs.colors.map { $0.lowercased() })
            let filtered = arr.filter { item in want.contains(where: { textBucket(item).contains($0) }) }
            if !filtered.isEmpty { arr = filtered } // soft
        }

        // Shoes: narrow to sneakers / boots / heels if explicitly requested (softly).
        if kind == .shoes {
            if prefs.wantSneakers {
                let f = arr.filter { let b = textBucket($0); return b.contains("sneaker") || b.contains("trainer") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantBoots {
                let f = arr.filter { textBucket($0).contains("boot") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantHeels {
                let f = arr.filter { let b = textBucket($0); return b.contains("heel") || b.contains("pump") }
                if !f.isEmpty { arr = f }
            }
        }

        // Bottoms: nudge to skirt or jeans if asked (soft).
        if kind == .bottom {
            if prefs.wantSkirt {
                let f = arr.filter { textBucket($0).contains("skirt") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantJeans {
                let f = arr.filter { let b = textBucket($0); return b.contains("jean") || b.contains("denim") }
                if !f.isEmpty { arr = f }
            }
        }

        return arr
    }

    /// Picks shoes honoring explicit sub-type preferences when possible; falls back to random.
    private func pickShoes(from items: [WardrobeItem], prefs: PromptPrefs) -> WardrobeItem? {
        if prefs.wantBoots {
            return items.first { textBucket($0).contains("boot") } ?? items.randomElement()
        }
        if prefs.wantHeels {
            return items.first { let b = textBucket($0); return b.contains("heel") || b.contains("pump") } ?? items.randomElement()
        }
        if prefs.wantSneakers {
            return items.first { let b = textBucket($0); return b.contains("sneaker") || b.contains("trainer") } ?? items.randomElement()
        }
        return items.randomElement()
    }

    // MARK: - Prompt parsing

    /// Keyword-based parser to derive `PromptPrefs` from a short natural-language prompt.
    private func parse(prompt: String) -> PromptPrefs {
        let p = prompt.lowercased()
        var prefs = PromptPrefs()

        // Normalize gray/grey to one token so matching is consistent.
        func normColor(_ c: String) -> String { (c == "grey") ? "gray" : c }

        // Color vocabulary (extend as needed).
        let colors = ["black","white","red","blue","green","pink","beige","brown","grey","gray","yellow","purple","orange","cream","ivory"]

        // Detect "all <color>" / "all-<color>" / "monochrome <color>" → monochrome intent.
        if let mono = colors.first(where: {
            p.contains("all \($0)") || p.contains("all-\($0)") || p.contains("monochrome \($0)")
        }) {
            let c = normColor(mono)
            prefs.colors    = [c]   // keep normal color wish list for the soft filter
            prefs.onlyColor = c     // but also mark as monochrome → stronger filter
        } else {
            // Fallback: collect any color mentions (soft “any-of”)
            prefs.colors = colors.filter { p.contains($0) }.map(normColor)
        }

        // Dress code buckets (loosely mapped).
        if p.contains("smart casual") || p.contains("business casual") { prefs.dressCode = "smart casual" }
        else if p.contains("smart") || p.contains("formal") || p.contains("elegant") { prefs.dressCode = "smart" }
        else if p.contains("casual") || p.contains("comfy") || p.contains("relaxed") { prefs.dressCode = "casual" }

        // Category nudges.
        prefs.wantDress = p.contains("dress")
        prefs.wantSkirt = p.contains("skirt")
        prefs.wantJeans = p.contains("jeans") || p.contains("denim")

        // Shoes.
        prefs.wantSneakers = p.contains("sneaker") || p.contains("trainer") || p.contains("sporty")
        prefs.wantBoots    = p.contains("boot")
        prefs.wantHeels    = p.contains("heel") || p.contains("pump") || p.contains("stiletto")

        // Layers / extras.
        prefs.wantOuter        = p.contains("jacket") || p.contains("coat") || p.contains("blazer") || p.contains("hoodie") || p.contains("cardigan")
        prefs.wantBag          = p.contains("bag") || p.contains("handbag") || p.contains("tote") || p.contains("crossbody")
        prefs.wantAccessories  = p.contains("accessor") || p.contains("belt") || p.contains("scarf") || p.contains("hat") || p.contains("cap") || p.contains("jewel")

        // Vibes (not yet used in scoring; kept for future).
        let vibes = ["sporty","chic","minimal","edgy","girly","street","y2k","preppy","boho","retro","vintage"]
        prefs.vibeWords = vibes.filter { p.contains($0) }

        return prefs
    }

    /// Heuristic to keep replacement suggestions “similar” to the current deck:
    /// derive a minimal prefs profile from the first card (colors, dress code, base type).
    private func latestPrefsFromCurrentCards() -> PromptPrefs? {
        guard let first = cards.first else { return nil }
        var prefs = PromptPrefs()
        let items = first.orderedItems

        // Colors: pick up to two commonly occurring colors across item tags.
        let colorSet = Set(items.flatMap(\.colours).map { $0.lowercased() })
        prefs.colors = Array(colorSet.prefix(2))

        // Dress code: pick the most frequent code token from items.
        let codes = items.map { $0.dressCode.lowercased() }
        if let c = codes.max(by: { a, b in
            codes.filter { $0 == a }.count < codes.filter { $0 == b }.count
        }) {
            if !c.isEmpty { prefs.dressCode = c }
        }

        // Remember whether the card used a dress, to bias the next build.
        let hasDress = items.contains { ($0.category + " " + $0.subcategory).lowercased().contains("dress") }
        prefs.wantDress = hasDress

        return prefs
    }
}
