//
//  PromptSuggestionViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//
 

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Card / candidate

struct PSOutfitCandidate: Identifiable, Equatable {
    let id = UUID()
    var itemsByKind: [LayerKind: WardrobeItem]

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

// MARK: - Prompt preferences (lightweight rules – no external API required)

fileprivate struct PromptPrefs {
    var colors: [String] = []
    var dressCode: String? = nil   // "casual", "smart casual", "smart"
    var wantDress = false
    var wantSkirt = false
    var wantJeans = false
    var wantSneakers = false
    var wantBoots = false
    var wantHeels = false
    var wantOuter = false
    var wantBag   = false
    var wantAccessories = false
    var vibeWords: [String] = []   // sporty, chic, minimalist, edgy…

    var isAllBlack: Bool { colors.map { $0.lowercased() }.contains("black") && colors.count == 1 }
}

@MainActor
final class PromptSuggestionViewModel: ObservableObject {
    @Published var cards: [PSOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    let userId: String
    private let store = ManualSuggestionStore()

    init(userId: String) {
        self.userId = userId
    }

    // MARK: Public actions

    func generate(prompt: String, count: Int = 2) async {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.errorMessage = "Please enter a short prompt."
            return
        }
        let prefs = parse(prompt: prompt)
        isLoading = true
        defer { isLoading = false }
        cards.removeAll()
        for _ in 0..<count {
            if let c = await buildCandidate(prefs: prefs) { cards.append(c) }
        }
        if cards.isEmpty {
            errorMessage = "I couldn’t find items that match this prompt. Try loosening it a little."
        }
    }

    func skip(_ id: PSOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }
        // Rebuild with last known prefs if available by peeking a simple one from the remaining card,
        // otherwise just create a generic one (no strict prefs).
        let prefs = latestPrefsFromCurrentCards() ?? PromptPrefs()
        if let c = await buildCandidate(prefs: prefs) {
            cards.append(c)
        }
    }

    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {
        let uid = Auth.auth().currentUser?.uid ?? userId
        guard !uid.isEmpty else {
            errorMessage = "Please sign in."
            return
        }

        do {
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

            let ref = Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()

            try await ref.setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            self.errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Core building

    private func buildCandidate(prefs: PromptPrefs) async -> PSOutfitCandidate? {
        // Pull buckets
        async let dresses = store.fetchItems(userId: userId, for: .dress,     limit: 300)
        async let tops    = store.fetchItems(userId: userId, for: .top,       limit: 400)
        async let bottoms = store.fetchItems(userId: userId, for: .bottom,    limit: 400)
        async let shoes   = store.fetchItems(userId: userId, for: .shoes,     limit: 300)
        async let outer   = store.fetchItems(userId: userId, for: .outerwear, limit: 200)
        async let bags    = store.fetchItems(userId: userId, for: .bag,       limit: 200)
        async let accs    = store.fetchItems(userId: userId, for: .accessory, limit: 200)

        var D = (try? await dresses) ?? []
        var T = (try? await tops) ?? []
        var B = (try? await bottoms) ?? []
        var S = (try? await shoes) ?? []
        var O = (try? await outer) ?? []
        var G = (try? await bags) ?? []
        var A = (try? await accs) ?? []

        // Preference filters
        D = filter(D, with: prefs, kind: .dress)
        T = filter(T, with: prefs, kind: .top)
        B = filter(B, with: prefs, kind: .bottom)
        S = filter(S, with: prefs, kind: .shoes)
        O = filter(O, with: prefs, kind: .outerwear)
        G = filter(G, with: prefs, kind: .bag)
        A = filter(A, with: prefs, kind: .accessory)

        // Shoes with preference
        guard let shoesPick = pickShoes(from: S, prefs: prefs) else { return nil }
        var items: [LayerKind: WardrobeItem] = [.shoes: shoesPick]

        // Base: forced dress if asked; otherwise 50/50
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
                items[.dress] = d
            } else {
                return nil
            }
        }

        // Optional layers (probabilistic + prompt nudges)
        if (!O.isEmpty && (prefs.wantOuter || Int.random(in: 0...100) < 40)),
           let o = O.randomElement() { items[.outerwear] = o }

        if (!G.isEmpty && (prefs.wantBag || Int.random(in: 0...100) < 35)),
           let g = G.randomElement() { items[.bag] = g }

        if (!A.isEmpty && (prefs.wantAccessories || Int.random(in: 0...100) < 35)),
           let a = A.randomElement() { items[.accessory] = a }

        // Keep combos to a readable 2–5 items
        if items.count > 5 {
            let dropOrder: [LayerKind] = [.accessory, .bag, .outerwear]
            for k in dropOrder where items.count > 5 { items.removeValue(forKey: k) }
        }

        return PSOutfitCandidate(itemsByKind: items)
    }

    // MARK: - Filtering helpers

    private func filter(_ items: [WardrobeItem], with prefs: PromptPrefs, kind: LayerKind) -> [WardrobeItem] {
        var arr = items

        // Dress code
        if let code = prefs.dressCode {
            let token = code.lowercased()
            let filtered = arr.filter { $0.dressCode.lowercased().contains(token) }
            if !filtered.isEmpty { arr = filtered }
        }

        // Color preference (simple contains on colours/customTags/category/subcategory)
        if !prefs.colors.isEmpty {
            let wantColors = Set(prefs.colors.map { $0.lowercased() })
            let filtered = arr.filter { item in
                let bucket = (
                    item.colours.joined(separator: " ") + " " +
                    item.customTags.joined(separator: " ") + " " +
                    item.category + " " + item.subcategory
                ).lowercased()
                return wantColors.contains(where: { bucket.contains($0) })
            }
            if !filtered.isEmpty { arr = filtered }
        }

        // Shoes subtype preferences
        if kind == .shoes {
            if prefs.wantSneakers {
                let f = arr.filter { cts($0).contains("sneaker") || cts($0).contains("trainer") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantBoots {
                let f = arr.filter { cts($0).contains("boot") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantHeels {
                let f = arr.filter { cts($0).contains("heel") || cts($0).contains("pump") }
                if !f.isEmpty { arr = f }
            }
        }

        // Category nudges: skirt / jeans
        if kind == .bottom {
            if prefs.wantSkirt {
                let f = arr.filter { cts($0).contains("skirt") }
                if !f.isEmpty { arr = f }
            } else if prefs.wantJeans {
                let f = arr.filter { cts($0).contains("jean") || cts($0).contains("denim") }
                if !f.isEmpty { arr = f }
            }
        }

        return arr
    }

    private func cts(_ item: WardrobeItem) -> String {
        (item.category + " " + item.subcategory).lowercased()
    }

    private func pickShoes(from items: [WardrobeItem], prefs: PromptPrefs) -> WardrobeItem? {
        if prefs.wantBoots {
            return items.first { cts($0).contains("boot") } ?? items.randomElement()
        }
        if prefs.wantHeels {
            return items.first { cts($0).contains("heel") || cts($0).contains("pump") } ?? items.randomElement()
        }
        if prefs.wantSneakers {
            return items.first { cts($0).contains("sneaker") || cts($0).contains("trainer") } ?? items.randomElement()
        }
        return items.randomElement()
    }

    // MARK: - Prompt parsing

    private func parse(prompt: String) -> PromptPrefs {
        let p = prompt.lowercased()
        var prefs = PromptPrefs()

        // Colors
        let colors = ["black","white","red","blue","green","pink","beige","brown","grey","gray","yellow","purple","orange","cream","ivory"]
        prefs.colors = colors.filter { p.contains($0) }
        if p.contains("all black") || p.contains("monochrome black") { prefs.colors = ["black"] }

        // Dress code
        if p.contains("smart casual") || p.contains("business casual") { prefs.dressCode = "smart casual" }
        else if p.contains("smart") || p.contains("formal") || p.contains("elegant") { prefs.dressCode = "smart" }
        else if p.contains("casual") || p.contains("comfy") || p.contains("relaxed") { prefs.dressCode = "casual" }

        // Categories
        prefs.wantDress = p.contains("dress")
        prefs.wantSkirt = p.contains("skirt")
        prefs.wantJeans = p.contains("jeans") || p.contains("denim")

        // Shoes signals
        prefs.wantSneakers = p.contains("sneaker") || p.contains("trainer") || p.contains("sporty")
        prefs.wantBoots    = p.contains("boot")
        prefs.wantHeels    = p.contains("heel") || p.contains("pump") || p.contains("stiletto")

        // Layers / extras
        prefs.wantOuter        = p.contains("jacket") || p.contains("coat") || p.contains("blazer") || p.contains("hoodie") || p.contains("cardigan")
        prefs.wantBag          = p.contains("bag") || p.contains("handbag") || p.contains("tote") || p.contains("crossbody")
        prefs.wantAccessories  = p.contains("accessor") || p.contains("belt") || p.contains("scarf") || p.contains("hat") || p.contains("cap") || p.contains("jewel")

        // Vibes (kept for future scoring)
        let vibes = ["sporty","chic","minimal","edgy","girly","street","y2k","preppy","boho","retro","vintage"]
        prefs.vibeWords = vibes.filter { p.contains($0) }

        return prefs
    }

    private func latestPrefsFromCurrentCards() -> PromptPrefs? {
        // This simple heuristic just keeps any dress code/color bias from first card
        guard let first = cards.first else { return nil }
        var prefs = PromptPrefs()
        let items = first.orderedItems

        // Pull some colors that appear frequently in the selected items
        let colorSet = Set(items.flatMap(\.colours).map { $0.lowercased() })
        prefs.colors = Array(colorSet.prefix(2))

        // Guess dress code from the most common in items
        let codes = items.map { $0.dressCode.lowercased() }
        if let c = codes.max(by: { a, b in
            codes.filter { $0 == a }.count < codes.filter { $0 == b }.count
        }) {
            if !c.isEmpty { prefs.dressCode = c }
        }

        // Remember whether it used dress vs top+bottom
        let hasDress = items.contains { ($0.category + " " + $0.subcategory).lowercased().contains("dress") }
        prefs.wantDress = hasDress

        return prefs
    }
}

