//
//  WardrobeView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI

// MARK: — Single Item Card

private struct WardrobeItemCard: View {
    let item: WardrobeItem
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: item.imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 160, height: 180)
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFill()
                        .frame(width: 160, height: 180)
                        .clipped()
                default:
                    Color(.systemGray5)
                        .frame(width: 160, height: 180)
                }
            }
            .background(Color(.systemGray5))


            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 1)
            }
            .offset(x: -8, y: -8)
        }
    }
}

struct WardrobeView: View {
    @StateObject private var viewModel: WardrobeViewModel
    @State private var selectedTab: Tab = .items
    @State private var selectedCategory: Category = .all
    @State private var searchText: String = ""
    @State private var showOnlyFavorites: Bool = false
    @State private var showFilterSheet: Bool = false

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
                tabs
                categoryScroll       // <= uses fixed .renderingMode
                searchFilters
                itemsGrid
            }
            .sheet(isPresented: $showFilterSheet) {
                WardrobeFilterView()
            }
            .background(Color.white.ignoresSafeArea())
        }
    }

    // MARK: — Sections

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color.orange.opacity(0.5),
                        Color.pink.opacity(0.4),
                        Color.yellow.opacity(0.4),
                        Color.pink.opacity(0.4),
                        Color.orange.opacity(0.5)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 110)
                .padding(.horizontal, 20)
                .padding(.top, 10)

            Text("My Wardrobe")
                .font(AppFont.spicyRice(size: 28))
                .foregroundColor(.black)
                .offset(y: 8)
        }
        .padding(.bottom, 16)
    }

    private var tabs: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue)
                        .font(.subheadline).bold()
                        .foregroundColor(selectedTab == tab ? .primary : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(Color.white)
        .overlay(Divider(), alignment: .bottom)
    }

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(Category.allCases, id: \.self) { cat in
                    VStack(spacing: 4) {
                        Button(action: { selectedCategory = cat }) {
                            Image(systemName: cat.iconName)
                                .resizable()                         // → first, make it resizable
                                .renderingMode(.template)            // then apply template mode
                                .scaledToFit()                       // then scale to fit
                                .frame(width: 36, height: 36)
                                .foregroundColor(.black)             // color the symbol
                                .padding(8)
                                .background(
                                    selectedCategory == cat
                                        ? Color.brandGreen
                                        : Color.clear
                                )
                                .clipShape(Circle())
                        }
                        Text(cat.rawValue)
                            .font(.caption2)
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var searchFilters: some View {
        HStack(spacing: 16) {
            SearchBar(text: $searchText, placeholder: "Search items")
            Button(action: { showOnlyFavorites.toggle() }) {
                Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(.red)
            }
            Button(action: { showFilterSheet = true }) {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var itemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(filteredItems) { item in
                    WardrobeItemCard(
                        item: item,
                        isFavorite: viewModel.isFavorite(item),
                        toggleFavorite: { toggleFavorite(item) }
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: — Helpers

    private var filteredItems: [WardrobeItem] {
        guard selectedTab == .items else { return [] }
        return viewModel.items
            .filter { selectedCategory == .all || $0.matches(category: selectedCategory) }
            .filter { searchText.isEmpty || $0.category.localizedCaseInsensitiveContains(searchText) }
            .filter { !showOnlyFavorites || viewModel.isFavorite($0) }
    }

    private func toggleFavorite(_ item: WardrobeItem) {
        viewModel.toggleFavorite(item)
    }
}

// MARK: — Supporting Types

extension WardrobeView {
    enum Tab: String, CaseIterable { case items = "Items", outfits = "Outfits" }

    enum Category: String, CaseIterable {
        case all = "All", top = "Top", outerwear = "Outerwear",
             dress = "Dress", bottoms = "Bottoms", footwear = "Footwear"
        var iconName: String {
            switch self {
            case .all:       return "square.grid.2x2"
            case .top:       return "tshirt"
            case .outerwear: return "jacket"
            case .dress:     return "dress"
            case .bottoms:   return "pants"
            case .footwear:  return "shoeprints.fill"
            }
        }
    }

    struct SearchBar: View {
        @Binding var text: String
        var placeholder: String
        var body: some View {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

// MARK: — Preview

struct WardrobeView_Previews: PreviewProvider {
    static var previews: some View {
        let sample1 = WardrobeItem(
            imageURL: "", category: "Dress", subcategory: "Cocktail",
            colours: [], customTags: [], length: "",
            style: "", designPattern: "", closureType: "",
            fit: "", material: "", fastening: "",
            dressCode: "", season: "", size: "",
            moodTags: [], addedAt: Date()
        )
        let sample2 = WardrobeItem(
            imageURL: "", category: "Top", subcategory: "Blouse",
            colours: [], customTags: [], length: "",
            style: "", designPattern: "", closureType: "",
            fit: "", material: "", fastening: "",
            dressCode: "", season: "", size: "",
            moodTags: [], addedAt: Date()
        )
        let vm = WardrobeViewModel()
        vm.items = [sample1, sample2]

        return WardrobeView(viewModel: vm)
    }
}
