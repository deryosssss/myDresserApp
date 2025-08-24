//
//  WardrobeView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//  Updated: 22/08/2025 – allow external initial tab (Items/Outfits).
//

import SwiftUI

struct WardrobeView: View {
    @StateObject private var viewModel: WardrobeViewModel
    @State private var selectedTab: Tab
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

    /// NEW: choose starting tab from the caller (defaults to .items).
    init(viewModel: WardrobeViewModel = WardrobeViewModel(), initialTab: Tab = .items) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _selectedTab = State(initialValue: initialTab)
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

    // MARK: — Search + Favorites + Filter + Sort
    private var searchFilters: some View {
        HStack(spacing: 16) {
            WardrobeSearchBar(
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

    // MARK: — Outfits Grid
    private struct OutfitRowModel: Identifiable {
        let id: String
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

    private var filteredOutfits: [Outfit] {
        var list = viewModel.allOutfits

        if showOnlyFavorites { list = list.filter { $0.isFavorite } }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                (!$0.name.isEmpty && $0.name.lowercased().contains(q)) ||
                ($0.description?.lowercased().contains(q) ?? false) ||
                $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }

        let tagFilters = Set(viewModel.filters.tags.map { $0.lowercased() })
        if !tagFilters.isEmpty {
            list = list.filter { !Set($0.tags.map { $0.lowercased() }).isDisjoint(with: tagFilters) }
        }

        if let opt = sortOption {
            return applyLocalSortOutfits(list, by: opt)
        } else {
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
}

// MARK: — Supporting Types kept on the screen
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
}

extension WardrobeView {
    @ViewBuilder
    func sortButton(_ option: SortOption, title: String) -> some View {
        Button { sortOption = option } label: {
            HStack {
                Text(title)
                Spacer()
                if sortOption == option { Image(systemName: "checkmark") }
            }
        }
    }
}
