//
//  PromptResultsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

// MARK: - Layout

private enum PRLayout {
    static let cardCorner: CGFloat   = 14
    static let cardPadding: CGFloat  = 12
    static let gridSpacing: CGFloat  = 12
    static let thumbSize: CGSize     = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

// MARK: - Candidate

struct PCOutfitCandidate: Identifiable, Equatable {
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

    static func == (lhs: PCOutfitCandidate, rhs: PCOutfitCandidate) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Normalization helpers (case/space-insensitive)

@inline(__always)
private func norm(_ s: String) -> String {
    s.folding(options: .diacriticInsensitive, locale: .current)
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
}

@inline(__always)
private func containsInsensitive(_ haystack: String, _ needle: String) -> Bool {
    guard !needle.isEmpty else { return true }
    return norm(haystack).contains(norm(needle))
}

// MARK: - Prompt model + parser

private enum PaletteMode: Equatable {
    case none
    case monochrome(color: String?)   // ← optional color
    case neutral
    case pastel
    case earth
    case colorful
}

private struct PromptQuery {
    var requiredColorsByKind: [LayerKind: Set<String>] = [:]
    var subtypeByKind: [LayerKind: Set<String>] = [:]
    var globalColors: Set<String> = []
    var styleTags: Set<String> = []
    var dressCode: String? = nil
    var occasion: String? = nil
    var palette: PaletteMode = .none
    var wantsDressBase: Bool? = nil
    var preferOuterwear = false
    var avoidOuterwear = false
    var metallic: String? = nil
}

// Color aliases (normalize to these bases)
private let baseColorAliases: [String: String] = [
    "gray":"grey",
    "maroon":"red","burgundy":"red","crimson":"red","wine":"red","scarlet":"red","ruby":"red",
    "navy":"blue","cobalt":"blue","azul":"blue","skyblue":"blue","teal":"blue",
    "forestgreen":"green","olive":"green","mint":"green","sage":"green",
    "cream":"beige","nude":"beige","taupe":"beige","tan":"beige","camel":"beige",
    "chocolate":"brown","mocha":"brown","coffee":"brown",
    "lilac":"purple","lavender":"purple",
    "coral":"orange","peach":"orange",
    "blush":"pink","rose":"pink",
    "offwhite":"white","ivory":"white"
]

private let neutralColors: Set<String> = ["black","white","grey","beige","brown","camel","taupe","tan","ivory"]
private let pastelHints: Set<String> = ["pastel","soft","light","baby","pale","muted"]
private let earthHints: Set<String>  = ["earth","earthy","terra","khaki","olive","camel","brown","beige","tan"]

/// Fully case/space/punctuation-insensitive color normalization.
private func normalizeColor(_ raw: String) -> String? {
    var s = norm(raw) // lowercased + no spaces/punct

    // Strip common modifiers at the start
    let modifiers = ["light","dark","bright","deep","neon","soft","muted","pale","baby","pastel"]
    for m in modifiers where s.hasPrefix(m) {
        s.removeFirst(m.count)
        break
    }

    // Remove "-ish" suffix
    if s.hasSuffix("ish") { s = String(s.dropLast(3)) }

    if let mapped = baseColorAliases[s] { return mapped }

    let base = Set(["black","white","red","blue","green","yellow","pink","beige","brown","grey","purple","orange"])
    if base.contains(s) { return s }

    if s == "skyblue" { return "blue" }

    return nil
}

private func parsePrompt(_ text: String) -> PromptQuery {
    var q = PromptQuery()
    let lower = text.lowercased()

    // Dress code / occasion
    if containsInsensitive(lower, "smart casual") { q.dressCode = "smart casual" }
    else if containsInsensitive(lower, "smart")    { q.dressCode = "smart" }
    else if containsInsensitive(lower, "casual")   { q.dressCode = "casual" }

    if containsInsensitive(lower, "wedding")   { q.occasion = "wedding" }
    if containsInsensitive(lower, "interview") { q.occasion = "interview" }
    if containsInsensitive(lower, "office")    { q.occasion = "office" }
    if containsInsensitive(lower, "date")      { q.occasion = "date" }
    if containsInsensitive(lower, "party")     { q.occasion = "party" }
    if containsInsensitive(lower, "beach")     { q.occasion = "beach" }
    if containsInsensitive(lower, "gym")       { q.occasion = "gym" }

    if containsInsensitive(lower, "cold") || containsInsensitive(lower, "winter") || containsInsensitive(lower, "chilly") {
        q.preferOuterwear = true
    }
    if containsInsensitive(lower, "hot") || containsInsensitive(lower, "summer") || containsInsensitive(lower, "warm") {
        q.avoidOuterwear = true
    }

    // Palette
    if containsInsensitive(lower, "monochrome") || lower.contains("all ") {
        // try to capture “all <color>”
        let words = lower
            .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
            .split(separator: " ").map(String.init)
        if let i = words.firstIndex(of: "all"), i+1 < words.count {
            q.palette = .monochrome(color: normalizeColor(words[i+1]))
            if case .monochrome(let c) = q.palette, let c { q.globalColors.insert(c) }
        } else { q.palette = .monochrome(color: nil) }
    } else if containsInsensitive(lower, "neutral") {
        q.palette = .neutral
    } else if pastelHints.contains(where: { containsInsensitive(lower, $0) }) {
        q.palette = .pastel
    } else if earthHints.contains(where: { containsInsensitive(lower, $0) }) {
        q.palette = .earth
    } else if containsInsensitive(lower, "colorful") || containsInsensitive(lower, "bright") {
        q.palette = .colorful
    }

    // Style adjectives
    let styles = ["minimal","sporty","edgy","boho","preppy","streetwear",
                  "vintage","romantic","chic","classy","elegant","bold","trendy"]
    q.styleTags = Set(styles.filter { containsInsensitive(lower, $0) })

    // Metallic accessories
    if containsInsensitive(lower, "gold")   { q.metallic = "gold" }
    if containsInsensitive(lower, "silver") { q.metallic = "silver" }

    // subtype lexicons
    let subtypeMap: [(words:[String], kind: LayerKind)] = [
        (["jeans","denim"], .bottom),
        (["trouser","trousers","pants","slacks"], .bottom),
        (["skirt"], .bottom),
        (["shorts"], .bottom),

        (["hoodie","sweater","jumper","cardigan","crewneck"], .top),
        (["blouse","shirt","tee","t-shirt","tank","camisole","top"], .top),

        (["heel","heels","pump","pumps","stiletto"], .shoes),
        (["sneaker","sneakers","trainer","trainers"], .shoes),
        (["boot","boots","chelsea","combat","knee"], .shoes),
        (["loafer","loafers"], .shoes),
        (["sandal","sandals","mule","mules"], .shoes),

        (["jacket","blazer","coat","trench","parka"], .outerwear),
    ]

    // tokens
    let tokens = lower
        .replacingOccurrences(of: "[^a-z0-9\\s-]", with: " ", options: .regularExpression)
        .split(separator: " ").map(String.init)

    // Prefer dress base if "dress" present
    if tokens.contains(where: { containsInsensitive($0, "dress") || containsInsensitive($0, "gown") || containsInsensitive($0, "slip") }) {
        q.wantsDressBase = true
    }

    // color + kind bigrams (both orders)
    func tryColorKind(_ a: String, _ b: String) {
        if let col = normalizeColor(a) {
            switch b.lowercased() {
            case "dress","gown","slip":
                q.requiredColorsByKind[.dress, default: []].insert(col); q.wantsDressBase = true
            case "shoe","shoes","heel","heels","sneaker","sneakers","trainer","trainers","boot","boots","loafer","loafers","sandal","sandals","mule","mules","pump","pumps":
                q.requiredColorsByKind[.shoes, default: []].insert(col)
            case "top","shirt","tee","t-shirt","blouse","sweater","hoodie","cardigan","tank","camisole":
                q.requiredColorsByKind[.top, default: []].insert(col)
            case "pants","trousers","jeans","shorts","skirt","leggings":
                q.requiredColorsByKind[.bottom, default: []].insert(col)
            case "jacket","coat","blazer","outerwear","parka","trench":
                q.requiredColorsByKind[.outerwear, default: []].insert(col)
            default: break
            }
        }
    }
    for i in 0..<max(tokens.count-1, 0) {
        tryColorKind(tokens[i], tokens[i+1])
        tryColorKind(tokens[i+1], tokens[i])
    }

    // global color words
    for w in tokens {
        if let c = normalizeColor(w) { q.globalColors.insert(c) }
    }

    // subtypes
    for (ws, kind) in subtypeMap {
        for w in ws where containsInsensitive(lower, w) {
            q.subtypeByKind[kind, default: []].insert(w)
        }
    }

    return q
}

// MARK: - ViewModel

@MainActor
final class PromptResultsViewModel: ObservableObject {
    @Published var cards: [PCOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    let userId: String
    let prompt: String
    private let query: PromptQuery
    private let store = ManualSuggestionStore()

    init(userId: String, prompt: String) {
        self.userId = userId
        self.prompt = prompt
        self.query = parsePrompt(prompt)
    }

    func loadInitial(count: Int = 2) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        cards.removeAll()
        for _ in 0..<count {
            if let c = await generateCandidate() { cards.append(c) }
        }
        if cards.isEmpty { errorMessage = "Couldn't match your prompt yet. Try rephrasing or add more items." }
    }

    func skip(_ id: PCOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }
        if let c = await generateCandidate() { cards.append(c) }
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
                "name": name.isEmpty ? prompt : name,
                "description": description ?? "",
                "imageURL": urls.first ?? "",
                "itemImageURLs": urls,
                "itemIDs": itemIDs,
                "tags": [],
                "occasion": occasion ?? (query.occasion ?? ""),
                "wearCount": 0,
                "isFavorite": isFavorite,
                "source": "prompt",
                "createdAt": FieldValue.serverTimestamp(),
                "date": date != nil ? Timestamp(date: date!) : FieldValue.serverTimestamp()
            ]
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()
                .setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    // MARK: - Candidate generation

    private func fetchBucket(_ kind: LayerKind, limit: Int = 500) async -> [WardrobeItem] {
        (try? await store.fetchItems(userId: userId, for: kind, limit: limit)) ?? []
    }

    private func searchableText(for item: WardrobeItem) -> String {
        var parts: [String] = [
            item.category, item.subcategory, item.style, item.designPattern,
            item.material, item.fit, item.dressCode
        ]
        parts.append(contentsOf: item.customTags)
        parts.append(contentsOf: item.moodTags)
        return parts.map { norm($0) }.joined(separator: " ")
    }

    private func normalizedColors(of item: WardrobeItem) -> Set<String> {
        Set(item.colours.compactMap { normalizeColor($0) })
    }

    private func score(_ item: WardrobeItem, kind: LayerKind, coherenceColor: String?) -> Int {
        var score = 0

        let hay = searchableText(for: item) // already normalized
        let its = normalizedColors(of: item)

        // Dress code / occasion
        if let dc = query.dressCode, !dc.isEmpty, containsInsensitive(item.dressCode, dc) {
            score += 25
        }
        if let occ = query.occasion, containsInsensitive(hay, occ) {
            score += 15
        }

        // Colors
        if let need = query.requiredColorsByKind[kind], !need.isEmpty {
            if !its.isDisjoint(with: need) { score += 45 }
        } else if !query.globalColors.isEmpty {
            if !its.isDisjoint(with: query.globalColors) { score += 25 }
        }

        // Monochrome coherence (fixed binding)
        if case .monochrome(let cOpt) = query.palette {
            let candidate = coherenceColor ?? cOpt
            if let coh = candidate, its.contains(coh) { score += 30 }
        }

        // Palette vibes
        switch query.palette {
        case .neutral:
            if !its.isDisjoint(with: neutralColors) { score += 20 }
        case .pastel:
            if containsInsensitive(item.style, "pastel") { score += 15 }
        case .earth:
            if its.contains("brown") || its.contains("beige") || its.contains("green") { score += 15 }
        default: break
        }

        // Subtypes
        if let subs = query.subtypeByKind[kind], !subs.isEmpty {
            if subs.contains(where: { containsInsensitive(hay, $0) }) { score += 40 }
        }

        // Style adjectives
        if !query.styleTags.isEmpty {
            if query.styleTags.contains(where: { containsInsensitive(hay, $0) }) { score += 18 }
        }

        // Metallic accessories
        if kind == .accessory, let metal = query.metallic, containsInsensitive(hay, metal) {
            score += 25
        }

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

    private func generateCandidate() async -> PCOutfitCandidate? {
        async let dresses = fetchBucket(.dress)
        async let tops    = fetchBucket(.top)
        async let bottoms = fetchBucket(.bottom)
        async let shoes   = fetchBucket(.shoes)
        async let outer   = fetchBucket(.outerwear)
        async let bags    = fetchBucket(.bag)
        async let accs    = fetchBucket(.accessory)

        let d = await dresses
        let t = await tops
        let b = await bottoms
        let s = await shoes
        let o = await outer
        let g = await bags
        let a = await accs

        var picked: [LayerKind: WardrobeItem] = [:]
        var coherenceColor: String? = nil

        if case .monochrome(let c) = query.palette {
            coherenceColor = c ?? query.globalColors.first
        }

        // Shoes first
        guard let shoe = pick(kind: .shoes, from: s, coherenceColor: coherenceColor) else { return nil }
        picked[.shoes] = shoe

        // Base: Dress OR Top+Bottom
        let useDress = query.wantsDressBase ?? Bool.random()

        if useDress, let dress = pick(kind: .dress, from: d, coherenceColor: coherenceColor) {
            picked[.dress] = dress
            if coherenceColor == nil, case .monochrome = query.palette {
                coherenceColor = normalizedColors(of: dress).first
            }
        } else if
            let top = pick(kind: .top, from: t, coherenceColor: coherenceColor),
            let bottom = pick(kind: .bottom, from: b, coherenceColor: coherenceColor) {
            picked[.top] = top
            picked[.bottom] = bottom
            if coherenceColor == nil, case .monochrome = query.palette {
                let shared = normalizedColors(of: top).intersection(normalizedColors(of: bottom))
                coherenceColor = shared.first ?? coherenceColor
            }
        } else if let dress = pick(kind: .dress, from: d, coherenceColor: coherenceColor) {
            picked[.dress] = dress
        } else {
            return nil
        }

        // Optionals
        if (!query.avoidOuterwear && Bool.random()) || query.preferOuterwear {
            if let coat = pick(kind: .outerwear, from: o, coherenceColor: coherenceColor) {
                picked[.outerwear] = coat
            }
        }
        if Int.random(in: 0...1) == 0, let bag = pick(kind: .bag, from: g, coherenceColor: coherenceColor) {
            picked[.bag] = bag
        }
        if Int.random(in: 0...1) == 0, let ac = pick(kind: .accessory, from: a, coherenceColor: coherenceColor) {
            picked[.accessory] = ac
        }

        return PCOutfitCandidate(itemsByKind: picked)
    }
}

// MARK: - View

struct PromptResultsView: View {
    @StateObject private var vm: PromptResultsViewModel

    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    init(userId: String, initialPrompt: String) {
        _vm = StateObject(wrappedValue: PromptResultsViewModel(userId: userId, prompt: initialPrompt))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Outfit")
                    .font(AppFont.spicyRice(size: 24))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                Text("“\(vm.prompt)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if vm.cards.isEmpty && !vm.isLoading {
                    emptyState.padding(.horizontal)
                } else {
                    ForEach(vm.cards) { card in
                        SuggestionCard(
                            candidate: card,
                            onSkip: { Task { await vm.skip(card.id) } },
                            onSave: {
                                previewItems = card.orderedItems
                                showPreview = true
                            }
                        )
                    }
                }

                if vm.isLoading {
                    ProgressView().padding(.vertical, 24)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadInitial() }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showPreview) {
            OutfitPreviewSheet(
                items: previewItems,
                onClose: { showPreview = false },
                onSave: { name, occasion, date, description, isFav in
                    Task {
                        await vm.saveOutfit(
                            name: name,
                            occasion: occasion,
                            description: description,
                            date: date,
                            isFavorite: isFav,
                            items: previewItems
                        )
                        showPreview = false
                    }
                }
            )
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No suggestions matched exactly")
                .font(.headline)
            Text("Try “red dress and black heels”, “all black smart casual”, “neutral minimal office with loafers”, or add more wardrobe items.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.loadInitial() }
            } label: {
                Text("Try again")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(minWidth: 140, minHeight: PRLayout.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGreen)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
        )
    }
}

// MARK: - Card

private struct SuggestionCard: View {
    let candidate: PCOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    private let cols = [
        GridItem(.flexible(), spacing: PRLayout.gridSpacing),
        GridItem(.flexible(), spacing: PRLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: cols, spacing: PRLayout.gridSpacing) {
                ForEach(candidate.orderedItems, id: \.id) { item in
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                        default:
                            Color(.tertiarySystemFill)
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            HStack(spacing: 10) {
                Button(role: .cancel, action: onSkip) {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: PRLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: PRLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            }
        }
        .padding(PRLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: PRLayout.cardCorner)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationStack {
        PromptResultsView(userId: "demo-user", initialPrompt: "Red dress and black shoes, elegant minimal smart casual")
    }
}
