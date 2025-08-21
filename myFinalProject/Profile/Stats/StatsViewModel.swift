//
//  StatsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import Foundation
import SwiftUI

@MainActor
final class StatsViewModel: ObservableObject {

    // MARK: Inputs & UI state
    enum Window: String, CaseIterable, Identifiable {
        case all = "All", d90 = "90d", d30 = "30d"
        var id: String { rawValue }
        var days: Int? { self == .all ? nil : (self == .d90 ? 90 : 30) }
    }
    @Published var window: Window = .all

    // MARK: Outputs consumed by the View
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var usedItemCount: Int = 0
    @Published private(set) var usagePercent: Int = 0

    @Published private(set) var recentItems: [WardrobeItem] = []
    struct OutfitRow: Identifiable { let id: String; let outfit: Outfit }
    @Published private(set) var recentOutfitsRows: [OutfitRow] = []
    var recentOutfits: [Outfit] { recentOutfitsRows.map(\.outfit) }

    @Published private(set) var mostWornItems: [WardrobeItem] = []
    @Published private(set) var leastWornItems: [WardrobeItem] = []
    @Published private(set) var oldestItems: [WardrobeItem] = []

    @Published private(set) var categorySegments: [DonutSegment] = []
    @Published private(set) var colourSegments: [DonutSegment] = []

    // MARK: Refresh from shared data VM
    func refresh(from vm: WardrobeViewModel) {
        let items = vm.items
        let outfits = filteredOutfits(vm.allOutfits, window: window)

        totalItems = items.count

        // Recent items/outfits (independent of window)
        recentItems = items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(6).map { $0 }

        let sortedOutfits = vm.allOutfits
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(6)

        recentOutfitsRows = Array(sortedOutfits.enumerated().map { idx, o in
            OutfitRow(id: o.id ?? "recent-\(idx)-\(o.imageURL)", outfit: o)
        })

        // Usage %
        let usedIDs = Set(outfits.flatMap { $0.itemIds })
        usedItemCount = items.filter { $0.id.map(usedIDs.contains) ?? false }.count
        usagePercent = totalItems == 0 ? 0 : Int((Double(usedItemCount) / Double(totalItems) * 100).rounded())

        // Wear counts within window
        let wear = wearCounts(outfits: outfits)

        // Top / Least / Oldest
        mostWornItems = Array(items.sorted { a, b in
            let ca = wear[idOf(a) ?? ""] ?? 0
            let cb = wear[idOf(b) ?? ""] ?? 0
            return (ca != cb) ? (ca > cb) :
                ((a.addedAt ?? .distantPast) > (b.addedAt ?? .distantPast))
        }.prefix(6))

        let mostIDs = Set(mostWornItems.compactMap { $0.id })
        leastWornItems = Array(items
            .filter { !($0.id.map(mostIDs.contains) ?? false) }
            .sorted { a, b in
                let ca = wear[idOf(a) ?? ""] ?? 0
                let cb = wear[idOf(b) ?? ""] ?? 0
                return (ca != cb) ? (ca < cb) :
                    ((a.addedAt ?? .distantFuture) < (b.addedAt ?? .distantFuture))
            }
            .prefix(6))

        oldestItems = items
            .sorted { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) }
            .prefix(6).map { $0 }

        // Donuts
        categorySegments = makeCategorySegments(items)
        colourSegments   = makeColourSegments(items)
    }

    // MARK: Drilldown helpers exposed to the View
    func itemsForCategory(_ label: String, in items: [WardrobeItem]) -> [WardrobeItem] {
        return items.filter { normalizedCategory($0.category) == label }
    }
    func itemsForColour(_ label: String, in items: [WardrobeItem]) -> [WardrobeItem] {
        let key = label.lowercased()
        return items.filter { item in
            item.colours.contains { $0.lowercased() == key }
        }
    }

    // MARK: Private utils
    private func filteredOutfits(_ all: [Outfit], window: Window) -> [Outfit] {
        guard let days = window.days else { return all }
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return all.filter { ($0.createdAt ?? .distantPast) >= from }
    }
    private func wearCounts(outfits: [Outfit]) -> [String:Int] {
        var m: [String:Int] = [:]
        for o in outfits { for id in o.itemIds { m[id, default: 0] += 1 } }
        return m
    }
    private func idOf(_ item: WardrobeItem) -> String? { item.id }

    private func normalizedCategory(_ raw: String) -> String {
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

    private var palette: [Color] { [.brandBlue, .brandPeach, .brandGreen, .brandYellow, .pink, .purple, .orange, .teal] }

    // Deterministic hash for stable color slots on unknown names
    private func djb2(_ s: String) -> Int {
        var hash: UInt64 = 5381
        for b in s.lowercased().utf8 { hash = ((hash << 5) &+ hash) &+ UInt64(b) }
        return Int(hash & 0x7fffffff)
    }

    private func stableColor(for name: String) -> Color {
        if let exact = colorFromName(name) { return exact }
        let idx = djb2(name) % palette.count
        return palette[idx]
    }

    private func makeCategorySegments(_ items: [WardrobeItem]) -> [DonutSegment] {
        let groups = Dictionary(grouping: items) { normalizedCategory($0.category) }
        let total = max(groups.values.map(\.count).reduce(0,+), 1)

        // Sorted by key → stable order/colors
        return groups.keys.sorted().enumerated().map { idx, key in
            let count = groups[key]?.count ?? 0
            return DonutSegment(
                id: key,                                     // stable identity
                value: Double(count) / Double(total),
                label: key,
                color: palette[idx % palette.count],
                rawCount: count
            )
        }
    }

    private func makeColourSegments(_ items: [WardrobeItem]) -> [DonutSegment] {
        // Normalize names (trim, uniform casing)
        let names = items.flatMap { $0.colours }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.capitalized }

        let counts = Dictionary(names.map { ($0, 1) }, uniquingKeysWith: +)

        // Stable sort: count desc, then label asc (prevents flip-flop on ties)
        let sortedTop = counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }.prefix(8)

        // Chart will normalize; keep raw counts as values
        return sortedTop.map { (name, count) in
            DonutSegment(
                id: name,                             // stable id by label
                value: Double(count),
                label: name,
                color: stableColor(for: name),        // deterministic hue per label
                rawCount: count
            )
        }
    }

    private func colorFromName(_ name: String) -> Color? {
        switch name.lowercased() {
        case "black", "eerie black": return .black
        case "white", "ceramic white": return .white
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "brown", "tuscan brown", "zinnwaldite brown": return Color(.brown)
        case "beige": return Color(.systemBrown).opacity(0.7)
        case "grey", "gray", "smokey grey", "spanish gray", "davy's grey", "dark gray": return .gray
        case "silver": return .gray.opacity(0.6)
        default: return nil
        }
    }
}
