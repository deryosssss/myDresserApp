//
//  WardrobeView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//


import SwiftUI

// Shared chip sizing (visible to CategoryChip and WardrobeView)
private enum CatChipLayout {
    static let boxSize: CGFloat = 56
    static let corner: CGFloat = 10
}

struct WardrobeView: View {
    @StateObject private var viewModel: WardrobeViewModel
    @State private var selectedTab: Tab = .items
    @State private var selectedCategory: Category = .all
    @State private var searchText: String = ""
    @State private var showOnlyFavorites: Bool = false
    @State private var showFilterSheet: Bool = false

    /// One sort control used for both Items and Outfits (nil → use VM default for items)
    @State private var sortOption: SortOption? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    init(viewModel: WardrobeViewModel = WardrobeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                tabPicker

                if selectedTab == .items {
                    categoryScroll
                }

                searchFilters

                ScrollView {
                    if selectedTab == .items {
                        itemsGrid
                    } else {
                        outfitsGrid
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                WardrobeFilterView()
                    .environmentObject(viewModel)
            }
            .background(Color.white.ignoresSafeArea())
            .onAppear { viewModel.startAllOutfitsListener() }
        }
    }

    // MARK: — Header

    private var header: some View {
        ZStack {
            Text("My Wardrobe")
                .font(AppFont.spicyRice(size: 28))
                .foregroundColor(.black)
                .offset(y: 8)
        }
        .padding(.bottom, 16)
    }

    // MARK: — Tabs

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    // MARK: — Category Scroll (Items only)

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Button { selectedCategory = cat } label: {
                        CategoryChip(
                            title: cat.label,
                            imageURL: thumbURL(for: cat),
                            isSelected: selectedCategory == cat,
                            isAll: cat == .all
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: — Search + Favorites + Filter + Sort (shared UI)

    private var searchFilters: some View {
        HStack(spacing: 16) {
            SearchBar(
                text: $searchText,
                placeholder: selectedTab == .items ? "Search items" : "Search outfits"
            )

            Button { showOnlyFavorites.toggle() } label: {
                Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                    .foregroundColor(.red)
            }

            Button { showFilterSheet = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.black)
                    .accessibilityLabel("Filter")
            }

            Menu {
                sortButton(.newest, title: "Newest")
                sortButton(.oldest, title: "Oldest")
                sortButton(.az,     title: "A–Z")
                sortButton(.za,     title: "Z–A")
                if sortOption != nil {
                    Divider()
                    Button("Clear sort", role: .destructive) { sortOption = nil }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundColor(sortOption == nil ? .black : .brandBlue)
                    .accessibilityLabel("Sort")
            }
            .accessibilityIdentifier("sortMenuButton")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: — Items Grid

    private var itemsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredItems) { item in
                NavigationLink {
                    ItemDetailView(item: item, wardrobeVM: viewModel) {
                        viewModel.delete(item)
                    }
                } label: {
                    WardrobeItemCard(
                        item: item,
                        isFavorite: viewModel.isFavorite(item),
                        toggleFavorite: { viewModel.toggleFavorite(item) }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    private var filteredItems: [WardrobeItem] {
        let base = viewModel.items
            .filter { categoryMatch($0, cat: selectedCategory) }
            .filter { searchText.isEmpty || searchableText(for: $0).localizedCaseInsensitiveContains(searchText) }
            .filter { !showOnlyFavorites || viewModel.isFavorite($0) }
            .filter { viewModel.matchesFilters($0) }

        if let opt = sortOption {
            return applyLocalSortItems(base, by: opt)
        } else {
            return viewModel.sort(base)
        }
    }

    // MARK: — Outfits Grid (collage previews) + filtering/sorting

    private struct OutfitRowModel: Identifiable {
        let id: String           // stable id for ForEach
        let outfit: Outfit
    }

    private var outfitsGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredOutfitRows) { row in
                NavigationLink {
                    OutfitDetailView(outfit: row.outfit)
                        .environmentObject(viewModel)
                } label: {
                    OutfitCollageCard(outfit: row.outfit)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    /// Full pipeline for outfits: favorites → search → tag filter (from WardrobeFilters) → sort
    private var filteredOutfits: [Outfit] {
        var list = viewModel.allOutfits

        if showOnlyFavorites {
            list = list.filter { $0.isFavorite }
        }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                (!$0.name.isEmpty && $0.name.lowercased().contains(q)) ||
                ($0.description?.lowercased().contains(q) ?? false) ||
                $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }

        // Apply WardrobeFilters tags (if provided); we only filter by tags for outfits.
        let tagFilters = Set(viewModel.filters.tags.map { $0.lowercased() })
        if !tagFilters.isEmpty {
            list = list.filter {
                !Set($0.tags.map { $0.lowercased() }).isDisjoint(with: tagFilters)
            }
        }

        // Sort (same control as items; if nil, default to "Newest")
        if let opt = sortOption {
            return applyLocalSortOutfits(list, by: opt)
        } else {
            // default newest
            return list.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
    }

    private var filteredOutfitRows: [OutfitRowModel] {
        filteredOutfits.enumerated().map { idx, o in
            OutfitRowModel(id: o.id ?? "local-\(idx)-\(o.imageURL)", outfit: o)
        }
    }

    // MARK: — Helpers

    private func thumbURL(for cat: Category) -> String? {
        guard cat != .all else { return nil }
        let itemsInCat = viewModel.items.filter { categoryMatch($0, cat: cat) }
        guard !itemsInCat.isEmpty else { return nil }
        if let fav = itemsInCat.first(where: { viewModel.isFavorite($0) }) { return fav.imageURL }
        return itemsInCat.first?.imageURL
    }

    private func searchableText(for item: WardrobeItem) -> String {
        [
            item.category, item.subcategory, item.style, item.designPattern,
            item.material, item.dressCode
        ].joined(separator: " ")
    }

    private func categoryMatch(_ item: WardrobeItem, cat: Category) -> Bool {
        if cat == .all { return true }
        let c = item.category.lowercased()
        switch cat {
        case .top: return c == "top" || c == "tops"
        case .outerwear: return c == "outerwear" || c == "jacket" || c == "coat" || c == "blazer"
        case .dress: return c == "dress" || c == "dresses"
        case .bottoms:
            return c == "bottom" || c == "bottoms" || c == "pants" || c == "trousers"
                || c == "jeans" || c == "skirt" || c == "shorts" || c == "leggings"
        case .shoes: return c == "shoes" || c == "shoe" || c == "footwear"
        case .accessories: return c == "accessory" || c == "accessories"
        case .bag: return c == "bag" || c == "bags" || c == "handbag" || c == "purse"
        case .all: return true
        }
    }

    // MARK: — Sorting

    private enum SortOption: Hashable { case newest, oldest, az, za }

    // Items A–Z key
    private func sortKeyAZ(for item: WardrobeItem) -> String {
        let parts = [item.category, item.subcategory, item.style]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.joined(separator: " ").lowercased()
    }

    private func applyLocalSortItems(_ items: [WardrobeItem], by option: SortOption) -> [WardrobeItem] {
        switch option {
        case .newest: return items.sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
        case .oldest: return items.sorted { ($0.addedAt ?? .distantFuture) < ($1.addedAt ?? .distantFuture) }
        case .az:     return items.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedAscending }
        case .za:     return items.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedDescending }
        }
    }

    // Outfits A–Z key (fallbacks to tags/URL when name is empty)
    private func sortKeyAZ(for outfit: Outfit) -> String {
        let name = outfit.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name.lowercased() }
        if !outfit.tags.isEmpty { return outfit.tags.joined(separator: " ").lowercased() }
        return outfit.imageURL.lowercased()
    }

    private func applyLocalSortOutfits(_ outfits: [Outfit], by option: SortOption) -> [Outfit] {
        switch option {
        case .newest: return outfits.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest: return outfits.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
        case .az:     return outfits.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedAscending }
        case .za:     return outfits.sorted { sortKeyAZ(for: $0).localizedCompare(sortKeyAZ(for: $1)) == .orderedDescending }
        }
    }

    // Sort menu button with checkmark
    @ViewBuilder
    private func sortButton(_ option: SortOption, title: String) -> some View {
        Button { sortOption = option } label: {
            HStack { Text(title); Spacer(); if sortOption == option { Image(systemName: "checkmark") } }
        }
    }
}

// MARK: — Category chip with user thumbnail (white box, bordered)

private struct CategoryChip: View {
    let title: String
    let imageURL: String?
    let isSelected: Bool
    let isAll: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: CatChipLayout.corner)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: CatChipLayout.corner)
                            .stroke(isSelected ? Color.brandBlue : Color.brandGrey, lineWidth: isSelected ? 2 : 1)
                    )
                    .frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)

                if isAll {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .padding(6)
                                .frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)
                        case .empty:
                            ProgressView().frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)
                        default:
                            Image(systemName: "photo").foregroundColor(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "photo").foregroundColor(.secondary)
                }
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: — Supporting Types

extension WardrobeView {
    enum Tab: String, CaseIterable { case items = "Items", outfits = "Outfits" }

    enum Category: CaseIterable, Hashable {
        case all, top, outerwear, dress, bottoms, shoes, accessories, bag

        var label: String {
            switch self {
            case .all: return "All"
            case .top: return "Top"
            case .outerwear: return "Outerwear"
            case .dress: return "Dress"
            case .bottoms: return "Bottoms"
            case .shoes: return "Shoes"
            case .accessories: return "Accessories"
            case .bag: return "Bag"
            }
        }

        static var allCases: [Category] { [.all, .top, .outerwear, .dress, .bottoms, .shoes, .accessories, .bag] }
    }

    struct SearchBar: View {
        @Binding var text: String
        var placeholder: String

        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: — Item Card

private struct WardrobeItemCard: View {
    let item: WardrobeItem
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: item.imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(width: 160, height: 180)
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 180)
                        .background(Color(.white))
                default:
                    Color(.white).frame(width: 160, height: 180)
                }
            }
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .offset(x: -8, y: -8)
        }
    }
}

// MARK: - Collage card (now supports up to 6 items)

private struct OutfitCollageCard: View {
    let outfit: Outfit

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OutfitCollageView(urls: outfit.itemImageURLs)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            if outfit.isFavorite {
                Image(systemName: "heart.fill")
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(6)
            }
        }
    }
}

private struct OutfitCollageView: View {
    let urls: [String]

    private func tile(_ url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty: Color(.secondarySystemBackground)
            case .success(let img): img.resizable().scaledToFit()
            default: Color(.tertiarySystemFill)
            }
        }
        .clipped()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let s: CGFloat = 2

            // 2-col metrics
            let col2W = (w - s) / 2
            let row2H = (h - s) / 2

            // 3-col metrics (used for 3, 5, 6)
            let col3W = (w - 2*s) / 3
            let row3H = (h - s) / 2     // two rows max

            ZStack {
                switch min(urls.count, 6) {
                case 0:
                    Color(.secondarySystemBackground)

                case 1:
                    tile(urls[0]).frame(width: w, height: h)

                case 2:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col2W, height: h)
                        tile(urls[1]).frame(width: col2W, height: h)
                    }

                case 3:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col3W, height: h)
                        tile(urls[1]).frame(width: col3W, height: h)
                        tile(urls[2]).frame(width: col3W, height: h)
                    }

                case 4:
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col2W, height: row2H)
                            tile(urls[1]).frame(width: col2W, height: row2H)
                        }
                        HStack(spacing: s) {
                            tile(urls[2]).frame(width: col2W, height: row2H)
                            tile(urls[3]).frame(width: col2W, height: row2H)
                        }
                    }

                case 5, 6:
                    // 3×2 grid; if only 5, last cell is a subtle placeholder to keep symmetry
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col3W, height: row3H)
                            tile(urls[1]).frame(width: col3W, height: row3H)
                            tile(urls[2]).frame(width: col3W, height: row3H)
                        }
                        HStack(spacing: s) {
                            tile(urls[3]).frame(width: col3W, height: row3H)
                            tile(urls[4]).frame(width: col3W, height: row3H)
                            if urls.count >= 6 {
                                tile(urls[5]).frame(width: col3W, height: row3H)
                            } else {
                                Color(.secondarySystemBackground)
                                    .frame(width: col3W, height: row3H)
                            }
                        }
                    }

                default:
                    EmptyView() // never reached due to min(...,6)
                }
            }
        }
    }
}
