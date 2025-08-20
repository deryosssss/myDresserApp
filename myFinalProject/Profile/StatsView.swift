//
//  StatsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct StatsView: View {
    @StateObject private var wardrobeVM = WardrobeViewModel()

    // Disclosure toggles
    @State private var showWhatsIn = true
    @State private var showUsage   = true

    // Time window for usage/wear counts
    enum Window: String, CaseIterable, Identifiable {
        case all = "All", d90 = "90d", d30 = "30d"
        var id: String { rawValue }
        var days: Int? { self == .all ? nil : (self == .d90 ? 90 : 30) }
    }
    @State private var window: Window = .all

    // Sheet for drill-down from donuts
    @State private var showFilteredSheet = false
    @State private var filteredTitle = ""
    @State private var filteredItems: [WardrobeItem] = []

    // MARK: - Layout
    enum UX {
        static let pagePadding: CGFloat = 16
        static let sectionGap: CGFloat = 16
        static let stripThumbSize = CGSize(width: 86, height: 96)
        static let cardCorner: CGFloat = 12
        static let cardPadding: CGFloat = 12
        static let donutHeight: CGFloat = 240
        static let donutInset: CGFloat = 8
        static let legendMin: CGFloat = 132
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.sectionGap) {

                    Text("My Stats")
                        .font(AppFont.spicyRice(size: 28))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)

                    Picker("", selection: $window) {
                        ForEach(Window.allCases) { w in Text(w.rawValue).tag(w) }
                    }
                    .pickerStyle(.segmented)

                    usageCard

                    // New items
                    StatsSectionCard(title: "New items") {
                        if recentItems.isEmpty {
                            StatsEmptyRow(text: "No items yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(recentItems, id: \.id) { item in
                                        NavigationLink {
                                            ItemDetailView(item: item, wardrobeVM: wardrobeVM, onDelete: { })
                                        } label: {
                                            ItemThumb(url: item.imageURL)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    // New outfits
                    StatsSectionCard(title: "New outfits") {
                        if recentOutfits.isEmpty {
                            StatsEmptyRow(text: "No outfits yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(recentOutfitsRows) { row in
                                        NavigationLink {
                                            OutfitDetailView(outfit: row.outfit)
                                                .environmentObject(wardrobeVM)
                                        } label: {
                                            CollageCard(urls: row.outfit.itemImageURLs)
                                                .frame(width: 120, height: 96)
                                                .background(Color.white)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 6)
                            }
                        }
                    }

                    // What's in my wardrobe
                    StatsSectionDisclosure(title: "What's in my wardrobe", isExpanded: $showWhatsIn)
                    if showWhatsIn {
                        StatsSectionCard(title: "Categories") {
                            NiceDonutChart(
                                segments: categorySegments,
                                onSelect: { seg in
                                    filteredTitle = seg.label
                                    filteredItems = itemsForCategory(seg.label)
                                    showFilteredSheet = true
                                }
                            )
                        }
                        StatsSectionCard(title: "Colour") {
                            NiceDonutChart(
                                segments: colourSegments,
                                onSelect: { seg in
                                    filteredTitle = seg.label
                                    filteredItems = itemsForColour(seg.label)
                                    showFilteredSheet = true
                                }
                            )
                        }
                    }

                    // My usage
                    StatsSectionDisclosure(title: "My usage", isExpanded: $showUsage)
                    if showUsage {
                        StatsSectionCard(title: "Most worn items") {
                            ItemStrip(items: mostWornItems, vm: wardrobeVM)
                        }
                        StatsSectionCard(title: "Least worn items") {
                            ItemStrip(items: leastWornItems, vm: wardrobeVM)
                        }
                        StatsSectionCard(title: "Oldest items") {
                            ItemStrip(items: oldestItems, vm: wardrobeVM)
                        }
                    }

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, UX.pagePadding)
                .padding(.bottom, 24)
            }
            .background(Color.white.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { wardrobeVM.startAllOutfitsListener() }
            .sheet(isPresented: $showFilteredSheet) {
                ItemGridSheet(title: filteredTitle, items: filteredItems, vm: wardrobeVM)
            }
        }
    }
}

// MARK: - Derived data
private extension StatsView {
    // Limit outfits by time window
    var filteredOutfits: [Outfit] {
        guard let days = window.days else { return wardrobeVM.allOutfits }
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return wardrobeVM.allOutfits.filter { ($0.createdAt ?? .distantPast) >= from }
    }

    // Newest 6 items / outfits (independent of window)
    var recentItems: [WardrobeItem] {
        wardrobeVM.items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(6).map { $0 }
    }
    struct OutfitRow: Identifiable { let id: String; let outfit: Outfit }
    var recentOutfitsRows: [OutfitRow] {
        let sorted = wardrobeVM.allOutfits
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(6)
        return sorted.enumerated().map { idx, o in
            OutfitRow(id: o.id ?? "recent-\(idx)-\(o.imageURL)", outfit: o)
        }
    }
    var recentOutfits: [Outfit] { recentOutfitsRows.map(\.outfit) }

    // Usage %
    var usedItemIDs: Set<String> {
        Set(filteredOutfits.flatMap { $0.itemIds })
    }
    var usagePercent: Int {
        let total = wardrobeVM.items.count
        guard total > 0 else { return 0 }
        let used = wardrobeVM.items.filter { idOf($0).map(usedItemIDs.contains) ?? false }.count
        return Int((Double(used) / Double(total) * 100.0).rounded())
    }

    // Wear counts within the selected window
    var wearCounts: [String: Int] {
        var m: [String: Int] = [:]
        for o in filteredOutfits {
            for id in o.itemIds { m[id, default: 0] += 1 }
        }
        return m
    }
    func count(for item: WardrobeItem) -> Int {
        guard let id = idOf(item) else { return 0 }
        return wearCounts[id] ?? 0
    }

    // TOP / LEAST (no duplicates between the two)
    var mostWornItems: [WardrobeItem] {
        Array(
            wardrobeVM.items
                .sorted { a, b in
                    let ca = count(for: a), cb = count(for: b)
                    return (ca != cb) ? (ca > cb) :
                    ((a.addedAt ?? .distantPast) > (b.addedAt ?? .distantPast))
                }
                .prefix(6)
        )
    }
    var leastWornItems: [WardrobeItem] {
        let mostIDs = Set(mostWornItems.compactMap { $0.id })
        return Array(
            wardrobeVM.items
                .filter { item in !(item.id.map(mostIDs.contains) ?? false) }
                .sorted { a, b in
                    let ca = count(for: a), cb = count(for: b)
                    return (ca != cb) ? (ca < cb) :
                    ((a.addedAt ?? .distantFuture) < (b.addedAt ?? .distantFuture))
                }
                .prefix(6)
        )
    }
    var oldestItems: [WardrobeItem] {
        wardrobeVM.items
            .sorted { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) }
            .prefix(6).map { $0 }
    }

    func idOf(_ item: WardrobeItem) -> String? { item.id }

    // Donut data
    var categorySegments: [DonutSegment] {
        let groups = Dictionary(grouping: wardrobeVM.items) { normalizedCategory($0.category) }
        let total = max(groups.values.map(\.count).reduce(0,+), 1)
        return groups.keys.sorted().enumerated().map { idx, key in
            let count = groups[key]?.count ?? 0
            return DonutSegment(value: Double(count) / Double(total),
                                label: key,
                                color: palette[idx % palette.count],
                                rawCount: count)
        }
    }

    var colourSegments: [DonutSegment] {
        let names: [String] = wardrobeVM.items.flatMap { $0.colours }
        let counts = Dictionary(names.map { ($0.capitalized, 1) }, uniquingKeysWith: +)
        let total = max(counts.values.reduce(0,+), 1)
        let top = counts.sorted { $0.value > $1.value }.prefix(8)
        return Array(top.enumerated().map { idx, pair in
            DonutSegment(value: Double(pair.value) / Double(total),
                         label: pair.key,
                         color: colorFromName(pair.key) ?? palette[idx % palette.count],
                         rawCount: pair.value)
        })
    }

    func normalizedCategory(_ raw: String) -> String {
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

    func colorFromName(_ name: String) -> Color? {
        switch name.lowercased() {
        case "black": return .black
        case "white": return .white
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "brown": return Color(.brown)
        case "beige": return Color(.systemBrown).opacity(0.7)
        case "grey", "gray": return .gray
        default: return nil
        }
    }

    var palette: [Color] {
        [.brandBlue, .brandPeach, .brandGreen, .brandYellow, .pink, .purple, .orange, .teal]
    }

    // Drill-down helpers
    func itemsForCategory(_ label: String) -> [WardrobeItem] {
        wardrobeVM.items.filter { normalizedCategory($0.category) == label }
    }
    func itemsForColour(_ label: String) -> [WardrobeItem] {
        let key = label.lowercased()
        return wardrobeVM.items.filter { $0.colours.map { $0.lowercased() }.contains(key) }
    }
}

// MARK: - Usage Card
private extension StatsView {
    var usageCard: some View {
        StatsSectionCard(title: "Wardrobe usage") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(usedItemIDs.count) used")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(max(wardrobeVM.items.count - usedItemIDs.count, 0)) not used")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(usagePercent)%")
                        .font(.headline)
                }

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 22)

                    GeometryReader { geo in
                        let w = geo.size.width * CGFloat(usagePercent) / 100.0
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandGreen.opacity(0.65))
                            .frame(width: max(0, w), height: 22)
                            .animation(.easeInOut(duration: 0.4), value: usagePercent)
                    }
                }
                .frame(height: 22)
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Reusable Section bits

private struct StatsSectionCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: Content

    init(title: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppFont.agdasima(size: 22))
                    .foregroundColor(.black)
                Spacer()
                accessory()
            }
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StatsView.UX.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: StatsView.UX.cardCorner)
                    .fill(Color(.systemGray6))
            )
            .clipShape(RoundedRectangle(cornerRadius: StatsView.UX.cardCorner)) // clip halos
        }
    }
}

private struct StatsSectionDisclosure: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.black)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(StatsView.UX.cardPadding)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: StatsView.UX.cardCorner))
        }
        .buttonStyle(.plain)
    }
}

private struct StatsEmptyRow: View {
    let text: String
    var body: some View {
        HStack { Text(text).foregroundColor(.secondary); Spacer() }
            .padding(.vertical, 8)
    }
}

// MARK: - Thumbs & Strips

private struct ItemThumb: View {
    let url: String
    var body: some View {
        ZStack {
            Color.white
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .empty: Color.white
                default: Color.white
                }
            }
        }
        .frame(width: StatsView.UX.stripThumbSize.width,
               height: StatsView.UX.stripThumbSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

private struct ItemStrip: View {
    let items: [WardrobeItem]
    let vm: WardrobeViewModel

    var body: some View {
        if items.isEmpty {
            StatsEmptyRow(text: "No data")
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in
                        NavigationLink {
                            ItemDetailView(item: item, wardrobeVM: vm, onDelete: { })
                        } label: {
                            ItemThumb(url: item.imageURL)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Outfit Collage

private struct CollageCard: View {
    let urls: [String]
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, s: CGFloat = 2
            let col3W = (w - 2*s) / 3
            let row2H = (h - s) / 2

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                VStack(spacing: s) {
                    HStack(spacing: s) {
                        tile(0).frame(width: col3W, height: row2H)
                        tile(1).frame(width: col3W, height: row2H)
                        tile(2).frame(width: col3W, height: row2H)
                    }
                    HStack(spacing: s) {
                        tile(3).frame(width: col3W, height: row2H)
                        tile(4).frame(width: col3W, height: row2H)
                        tile(5).frame(width: col3W, height: row2H)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
        }
    }
    @ViewBuilder private func tile(_ i: Int) -> some View {
        if i < urls.count {
            ZStack {
                Color.white
                AsyncImage(url: URL(string: urls[i])) { ph in
                    switch ph {
                    case .success(let img): img.resizable().scaledToFit()
                    case .empty: Color.white
                    default: Color.white
                    }
                }
            }
        } else { Color.white }
    }
}

// MARK: - Donut Chart (polished, interactive, crash-safe)

private struct DonutSegment: Identifiable, Equatable {
    let id = UUID()
    let value: Double   // normalized weight (0..1)
    let label: String
    let color: Color
    let rawCount: Int
}

private struct NiceDonutChart: View {
    let segments: [DonutSegment]
    var onSelect: ((DonutSegment) -> Void)? = nil

    @State private var selectedIndex: Int?

    private var normalized: [DonutSegment] {
        let sum = max(segments.map(\.value).reduce(0, +), 0.0001)
        return segments.map {
            DonutSegment(value: $0.value / sum,
                         label: $0.label,
                         color: $0.color,
                         rawCount: $0.rawCount)
        }
    }

    var body: some View {
        let data = normalized

        if data.isEmpty {
            EmptyDonutPlaceholder()
                .frame(height: StatsView.UX.donutHeight)
        } else {
            let maxIdx = data.enumerated().max(by: { $0.element.value < $1.element.value })?.offset ?? 0
            let focusIndex = min(selectedIndex ?? maxIdx, data.count - 1)
            let focusSeg = data[focusIndex]

            VStack(spacing: 12) {
                ZStack {
                    GeometryReader { geo in
                        let size = min(geo.size.width, geo.size.height) - 2*StatsView.UX.donutInset
                        let radius = size / 2
                        let lineW = size * 0.26
                        let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                        let startAngles = cumulativeAngles(data)

                        ForEach(data.indices, id: \.self) { i in
                            let start = startAngles[i]
                            let end   = startAngles[i] + Angle(degrees: data[i].value * 360)
                            Circle()
                                .trim(from: CGFloat(start.radians / (2*Double.pi)),
                                      to:   CGFloat(end.radians   / (2*Double.pi)))
                                .stroke(data[i].color.opacity(i == focusIndex ? 1 : 0.35),
                                        style: StrokeStyle(lineWidth: lineW, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                                .frame(width: radius*2, height: radius*2)
                                .position(center)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        selectedIndex = i
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    onSelect?(data[i])
                                }
                        }

                        // Subtle halo around focus (kept inside card due to clip)
                        Circle()
                            .stroke(focusSeg.color.opacity(0.18), lineWidth: lineW * 0.15)
                            .frame(width: radius*2, height: radius*2)
                            .rotationEffect(.degrees(-90))
                            .position(center)
                            .blendMode(.plusLighter)
                            .opacity(0.9)
                    }
                    .frame(height: StatsView.UX.donutHeight)
                    .padding(.bottom, 40)
                    .padding(.top, 40)

                    // Center label
                    VStack(spacing: 4) {
                        Text(focusSeg.label)
                            .font(AppFont.agdasima(size: 20).weight(.medium))
                        Text("\(Int(round(focusSeg.value * 100)))%")
                            .font(.headline)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
                }

                // Legend (tappable)
                let cols = [GridItem(.adaptive(minimum: StatsView.UX.legendMin), spacing: 8)]
                LazyVGrid(columns: cols, alignment: .leading, spacing: 8) {
                    ForEach(data.indices, id: \.self) { i in
                        let s = data[i]
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedIndex = i
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            onSelect?(s)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(s.color.opacity(i == focusIndex ? 1 : 0.35))
                                    .frame(width: 10, height: 10)
                                Text(s.label).font(.caption)
                                Text("• \(s.rawCount)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.9)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(i == focusIndex ? s.color.opacity(0.65) : Color(.systemGray5), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .onChange(of: data.count) { _ in selectedIndex = nil }
        }
    }

    private func cumulativeAngles(_ segs: [DonutSegment]) -> [Angle] {
        var result: [Angle] = []
        var total = 0.0
        for s in segs {
            result.append(.degrees(total * 360))
            total += s.value
        }
        return result
    }
}

private struct EmptyDonutPlaceholder: View {
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 24)
                    .frame(height: StatsView.UX.donutHeight)
                Text("No data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Text("Add a few items to see insights.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Drill-down sheet

private struct ItemGridSheet: View {
    let title: String
    let items: [WardrobeItem]
    let vm: WardrobeViewModel

    private let cols = [GridItem(.adaptive(minimum: 110), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if items.isEmpty {
                    StatsEmptyRow(text: "No items for \(title)")
                        .padding(.top, 20)
                } else {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            NavigationLink {
                                ItemDetailView(item: item, wardrobeVM: vm, onDelete: { })
                            } label: {
                                ZStack {
                                    Color.white
                                    AsyncImage(url: URL(string: item.imageURL)) { ph in
                                        switch ph {
                                        case .success(let img): img.resizable().scaledToFit()
                                        case .empty: Color.white
                                        default: Color.white
                                        }
                                    }
                                }
                                .frame(height: 130)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
