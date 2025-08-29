//
//  HomeViewModel.swift
//  myDresser
//

import Foundation
import SwiftUI

/// ViewModel powering the Home dashboard. It computes all derived stats (recent items,
/// usage %, diversity, streaks, challenge text, etc.) from the shared WardrobeViewModel.

@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Inputs

    /// Time window used to compute *window-bound* stats (usage %, diversity, etc.).
    /// Keeps the raw label for UI and maps to an optional day count for filtering.
    enum Window: String, CaseIterable, Identifiable {
        case all = "All", d90 = "90d", d30 = "30d"
        var id: String { rawValue }
        /// nil = no filter; 90/30 = look back this many days
        var days: Int? { self == .all ? nil : (self == .d90 ? 90 : 30) }
    }
    /// Default to 90 days to surface meaningful usage out of the box.
    @Published var window: Window = .d90

    // MARK: - Outputs (read by the View)

    /// Total items in wardrobe (independent of window).
    @Published private(set) var totalItems: Int = 0
    /// Last 6 added items (independent of window).
    @Published private(set) var recentItems: [WardrobeItem] = []

    // Usage (bound to `window`)
    @Published private(set) var usedItemCount: Int = 0
    @Published private(set) var usagePercent: Int = 0
    /// Count of items not used in 90 days (explicitly *not* tied to the selected window).
    @Published private(set) var unused90Count: Int = 0

    // Month / CO₂
    /// Outfits logged since the start of the current calendar month.
    @Published private(set) var outfitsThisMonth: Int = 0
    /// Friendly sentence used by the header card.
    var monthlyHeadline: String {
        "Well done – you wore \(outfitsThisMonth) outfit\(outfitsThisMonth == 1 ? "" : "s") this month!"
    }
    /// Super-simple avoided-CO₂ heuristic: 0.8 kg per outfit re-wear.
    var co2SavedThisMonth: Double { Double(outfitsThisMonth) * 0.8 }
    /// 7-day streak of days where at least one outfit was logged.
    @Published private(set) var streak7: Int = 0

    // Diversity (computed over *used* items in the window)
    @Published private(set) var diversityScore: Double = 0
    /// Bucket the score into Low/Medium/High for easy UI.
    var diversityLevel: String {
        switch diversityScore {
        case ..<0.35: return "Low"
        case ..<0.65: return "Medium"
        default:      return "High"
        }
    }

    // Challenge (UX nudges)
    @Published private(set) var challengeText: String = "Tap spin to get today’s suprise!"
    @Published private(set) var challengeImages: [String] = []         // preview images (e.g., focus item)
    @Published private(set) var challengeFocusItem: WardrobeItem? = nil // concrete item challenge, if any
    @Published var spinning = false                                     // drives the spin animation

    // MARK: - Local cache
    /// Snapshot of items/outfits from the shared VM; avoids re-reading during window flips.
    private var cachedItems: [WardrobeItem] = []
    private var cachedOutfits: [Outfit] = []

    // MARK: - Public API
    func refresh(from vm: WardrobeViewModel) {
        cachedItems = vm.items
        cachedOutfits = vm.allOutfits
        totalItems = cachedItems.count

        // Recent items: newest first, limited to 6 for the strip.
        recentItems = cachedItems
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(6).map { $0 }

        // Month KPIs independent of the window (e.g., CO₂ headline).
        outfitsThisMonth = cachedOutfits.filter { ($0.createdAt ?? .distantPast) >= monthStart }.count

        // Streak over the last 7 days, based on distinct days with logged outfits.
        streak7 = computeStreak7(from: cachedOutfits)

        // Window-dependent aggregates (usage, diversity, etc.)
        recalcWindowBoundStats()
    }

    /// Bound to the segmented picker; recompute stats using the cached arrays.
    func onWindowChanged() {
        recalcWindowBoundStats()
    }

    // MARK: - Challenge

    /// Spins a light-weight “nudge” challenge:
    /// 1) Prefer surfacing an *unused-in-90d* item to encourage rediscovery.
    /// 2) Otherwise pick a generic category/colour challenge.
    /// Keeps UX reactive via a short spin animation flag.
    func spinChallenge(from vm: WardrobeViewModel) {
        spinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.spinning = false

            // Build the 90d unused pool.
            let from = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
            let recentlyUsedIDs = Set(
                vm.allOutfits
                    .filter { ($0.createdAt ?? .distantPast) >= from }
                    .flatMap { $0.itemIds }
            )
            let unused90 = vm.items.filter { item in
                guard let id = item.id else { return false }
                return !recentlyUsedIDs.contains(id)
            }

            // 50/50 chance to do an item-based challenge (if we have items).
            let useItemChallenge = Bool.random() && (!unused90.isEmpty || !vm.items.isEmpty)

            if useItemChallenge {
                // Prefer the unused pool; fall back to any item if empty.
                let pool = unused90.isEmpty ? vm.items : unused90
                if let pick = pool.randomElement() {
                    self.challengeFocusItem = pick
                    self.challengeImages = [pick.imageURL].compactMap { $0 }
                    self.challengeText = "Make an outfit with this item"
                    return
                }
            }

            // Otherwise craft a generic prompt using available categories/colours for variety.
            let categories = Set(vm.items.map { self.normalizeCategory($0.category) })
            let colours    = Set(vm.items.flatMap { $0.colours.map { $0.capitalized } })
            let prompts: [String] = [
                ifLet(categories.randomElement()) { "Wear something from \($0)" },
                ifLet(colours.randomElement())    { "Build an outfit around \($0)" },
                "Pick one item you haven’t worn in 90 days",
                "Create a look using only two colours",
                "Try a new layering combo today"
            ].compactMap { $0 }

            self.challengeFocusItem = nil
            self.challengeImages = []
            if let pick = prompts.randomElement() {
                self.challengeText = pick
            }
        }
    }

    /// Builds an AI seed prompt. If we have a concrete focus item, include its category and colours
    /// to steer the model; otherwise keep it generic.
    func aiPrompt() -> String {
        if let focus = challengeFocusItem {
            let coloursList = focus.colours.joined(separator: ", ")
            return "Create an outfit featuring my \(focus.category) \(focus.subcategory). Prefer colors \(coloursList). Use items from my wardrobe."
        } else {
            return "Create an outfit using my wardrobe."
        }
    }

    // MARK: - Internals
    /// Recomputes *window-bound* metrics:
    /// - usage (count and %)
    /// - unused in 90d (always 90, not tied to picker)
    /// - diversity (Simpson index over normalized categories of used items)
    private func recalcWindowBoundStats() {
        // 1) Filter outfits by selected window (or use all).
        let outfits: [Outfit] = {
            guard let days = window.days else { return cachedOutfits }
            let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
            return cachedOutfits.filter { ($0.createdAt ?? .distantPast) >= from }
        }()

        // 2) Usage: how many distinct items appear in the (window) outfits.
        let usedIDs = Set(outfits.flatMap { $0.itemIds })
        usedItemCount = cachedItems.filter { $0.id.map(usedIDs.contains) ?? false }.count
        // Guard divide-by-zero; round to nearest whole number for display.
        usagePercent = totalItems == 0 ? 0 : Int((Double(usedItemCount) / Double(totalItems) * 100).rounded())

        // 3) Unused in 90d (fixed horizon, regardless of window selection).
        let from90 = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentUsed = Set(
            cachedOutfits
                .filter { ($0.createdAt ?? .distantPast) >= from90 }
                .flatMap { $0.itemIds }
        )
        unused90Count = cachedItems.filter { !($0.id.map(recentUsed.contains) ?? false) }.count

        // 4) Diversity: Simpson index 1 - Σ(p_i^2) over normalized categories of *used* items.
        //    Produces [0,1], where higher means more diverse usage.
        let usedItems = cachedItems.filter { $0.id.map(usedIDs.contains) ?? false }
        if usedItems.isEmpty {
            diversityScore = 0
        } else {
            let groups = Dictionary(grouping: usedItems) { normalizeCategory($0.category) }
            let n = Double(usedItems.count)
            let sumPi2 = groups.values
                .map { Double($0.count) / n }
                .map { $0 * $0 }
                .reduce(0, +)
            diversityScore = max(0, min(1, 1 - sumPi2))
        }
    }

    /// Start of current month for month-scoped KPIs (outfits, CO₂).
    private var monthStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    /// Counts a 7-day streak of *days with at least one outfit*.
    /// Uses startOfDay to avoid time-of-day mismatches; allows “ended yesterday” to not feel punitive.
    private func computeStreak7(from outfits: [Outfit]) -> Int {
        let cal = Calendar.current
        // De-duplicate by day.
        let daysSet: Set<Date> = Set(outfits.compactMap { o in
            guard let d = o.createdAt else { return nil }
            return cal.startOfDay(for: d)
        })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        for _ in 0..<7 {
            if daysSet.contains(cursor) {
                streak += 1
            } else if daysSet.contains(cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor) && streak == 0 {
                // If yesterday had an outfit but today not yet, show 0 without breaking UX momentarily.
                streak += 0
            } else {
                break
            }
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    // MARK: - Utils
    /// Normalizes free-text categories into stable buckets used across the app/analytics.
    func normalizeCategory(_ raw: String) -> String {
        let c = raw.lowercased()
        if ["top","tops","shirt","blouse","tshirt"].contains(where: c.contains) { return "Top" }
        if ["outerwear","jacket","coat","blazer"].contains(where: c.contains) { return "Outerwear" }
        if ["dress","dresses"].contains(where: c.contains) { return "Dress" }
        if ["bottom","bottoms","pants","trousers","jeans","skirt","shorts","leggings"].contains(where: c.contains) { return "Bottoms" }
        if ["shoes","shoe","footwear","sneaker","boot"].contains(where: c.contains) { return "Shoes" }
        if ["accessory","accessories","jewelry","jewellery"].contains(where: c.contains) { return "Accessories" }
        if ["bag","handbag","purse"].contains(where: c.contains) { return "Bag" }
        return raw.capitalized
    }

    /// Tiny helper to make “optional to string” mapping terse when composing prompts.
    private func ifLet<T>(_ value: T?, map: (T) -> String) -> String? {
        value.map(map)
    }
}
