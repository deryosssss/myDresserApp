//  WardrobeView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI

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
                tabPicker

                if selectedTab == .items {
                    categoryScroll
                    searchFilters
                }

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
            }
            .background(Color.white.ignoresSafeArea())
        }
    }

    // MARK: — Header

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

    // MARK: — Tabs

    private var tabPicker: some View {
        Picker("", selection: $selectedTab) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }

    // MARK: — Items Helpers

    private var categoryScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(Category.allCases, id: \.self) { cat in
                    Button(action: { selectedCategory = cat }) {
                        VStack {
                            Image(systemName: cat.iconName)
                                .resizable().scaledToFit()
                                .frame(width: 36, height: 36)
                                .padding(8)
                                .foregroundColor(.black)
                                .background(selectedCategory == cat ? Color.brandGreen : Color.clear)
                                .clipShape(Circle())
                            Text(cat.rawValue).font(.caption2)
                                .foregroundColor(.black)
                        }
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
            Button { showOnlyFavorites.toggle() } label: {
                Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                    .foregroundColor(.red)
            }
            Button { showFilterSheet = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
    }

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
        viewModel.items
            .filter { selectedCategory == .all || $0.matches(category: selectedCategory) }
            .filter { searchText.isEmpty || $0.category.localizedCaseInsensitiveContains(searchText) }
            .filter { !showOnlyFavorites || viewModel.isFavorite($0) }
    }

    // MARK: — Outfits Grid

    private var outfitsGrid: some View {
        let allOutfits = viewModel.outfitsByItem.values.flatMap { $0 }
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(allOutfits) { outfit in
                NavigationLink {
                    OutfitDetailView(
                        outfit: outfit
                    )
                } label: {
                    AsyncImage(url: URL(string: outfit.imageURL)) { phase in
                        switch phase {
                        case .empty: ProgressView().frame(height: 180)
                        case .success(let img):
                            img.resizable().scaledToFill().frame(height: 180).clipped()
                        default: Color(.systemGray5).frame(height: 180)
                        }
                    }
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
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
            case .all: return "square.grid.2x2"
            case .top: return "tshirt"
            case .outerwear: return "jacket"
            case .dress: return "dress"
            case .bottoms: return "pants"
            case .footwear: return "shoeprints.fill"
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
                    .disableAutocorrection(true)
                    .autocapitalization(.none)
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

private struct WardrobeItemCard: View {
    let item: WardrobeItem
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: item.imageURL)) { phase in
                switch phase {
                case .empty: ProgressView().frame(width: 160, height: 180)
                case .success(let img):
                    img.resizable().scaledToFill().frame(width: 160, height: 180).clipped()
                default: Color(.systemGray5).frame(width: 160, height: 180)
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



// MARK: — Preview
struct WardrobeView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = WardrobeItem(
            id: "item1",
            imageURL: "",
            category: "Dress",
            subcategory: "Cocktail",
            length: "Maxi",
            style: "Elegant",
            designPattern: "Plain",
            closureType: "Zipper",
            fit: "Regular",
            material: "Silk",
            fastening: "None",
            dressCode: "Black Tie",
            season: "Summer",
            size: "M",
            colours: ["ff66a3", "0099ff"],
            customTags: ["Party"],
            moodTags: ["Happy"],
            addedAt: Date(),
            lastWorn: nil
        )
        let vm = WardrobeViewModel()
        vm.items = [sampleItem]

        // Add two outfits for preview
                let outfit1 = Outfit(
                   id: "o1",
                   imageURL: "https://via.placeholder.com/100",
                    itemImageURLs: [
                        "https://via.placeholder.com/80",
                        "https://via.placeholder.com/80/ff0000"
                    ],
                    tags: ["Casual", "Summer"]
                )
               let outfit2 = Outfit(
                    id: "o2",
                   imageURL: "https://via.placeholder.com/100/0000FF",
                   itemImageURLs: [
                        "https://via.placeholder.com/80/0000FF",
                        "https://via.placeholder.com/80/00FF00"
                    ],
                   tags: ["Sporty"]
            )
                vm.setOutfits([outfit1, outfit2], for: sampleItem)

        return WardrobeView(viewModel: vm)
            .previewDevice("iPhone 14 Pro")
    }
}


