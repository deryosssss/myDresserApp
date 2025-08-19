//  OutfitsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct OutfitsView: View {
    // Local VM just for this screen (listens to outfits)
    @StateObject private var vm = WardrobeViewModel()

    // UI state
    @State private var searchText: String = ""
    @State private var showOnlyFavorites: Bool = false
    @State private var sort: SortOption? = .newest

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("My Outfits")
                .font(AppFont.spicyRice(size: 28))
                .foregroundColor(.black)
                .padding(.top, 4)
                .padding(.bottom, 10)

            // Search + fav + sort
            HStack(spacing: 16) {
                SearchBar(text: $searchText, placeholder: "Search outfits")

                Button { showOnlyFavorites.toggle() } label: {
                    Image(systemName: showOnlyFavorites ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                }

                Menu {
                    sortButton(.newest, "Newest")
                    sortButton(.oldest, "Oldest")
                    sortButton(.az,     "A–Z")
                    sortButton(.za,     "Z–A")
                    if sort != nil {
                        Divider()
                        Button("Clear sort", role: .destructive) { sort = nil }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(sort == nil ? .black : .brandBlue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            // Grid
            ScrollView {
                if filteredRows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("No outfits found")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredRows) { row in
                            NavigationLink {
                                // Preview-sheet styled detail
                                OutfitDetailView(outfit: row.outfit)
                                    .environmentObject(vm)
                            } label: {
                                OutfitCollageCard(outfit: row.outfit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.startAllOutfitsListener() }
    }

    // MARK: - Filtering & sorting

    private struct Row: Identifiable {
        let id: String
        let outfit: Outfit
    }

    private var filteredOutfits: [Outfit] {
        var list = vm.allOutfits

        if showOnlyFavorites { list = list.filter { $0.isFavorite } }

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                (!$0.name.isEmpty && $0.name.lowercased().contains(q)) ||
                ($0.description?.lowercased().contains(q) ?? false) ||
                $0.tags.joined(separator: " ").lowercased().contains(q)
            }
        }

        // Optional: respect tag filters from WardrobeFilters (if used elsewhere)
        let tagFilters = Set(vm.filters.tags.map { $0.lowercased() })
        if !tagFilters.isEmpty {
            list = list.filter { !Set($0.tags.map { $0.lowercased() }).isDisjoint(with: tagFilters) }
        }

        // Sort (default to newest if nil)
        guard let sort else {
            return list.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        }
        switch sort {
        case .newest:
            return list.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .oldest:
            return list.sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
        case .az:
            return list.sorted { keyAZ($0).localizedCompare(keyAZ($1)) == .orderedAscending }
        case .za:
            return list.sorted { keyAZ($0).localizedCompare(keyAZ($1)) == .orderedDescending }
        }
    }

    private var filteredRows: [Row] {
        filteredOutfits.enumerated().map { idx, o in
            Row(id: o.id ?? "local-\(idx)-\(o.imageURL)", outfit: o)
        }
    }

    private func keyAZ(_ o: Outfit) -> String {
        let name = o.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name.lowercased() }
        if !o.tags.isEmpty { return o.tags.joined(separator: " ").lowercased() }
        return o.imageURL.lowercased()
    }

    private enum SortOption: Hashable { case newest, oldest, az, za }
    @ViewBuilder private func sortButton(_ opt: SortOption, _ title: String) -> some View {
        Button { sort = opt } label: {
            HStack { Text(title); Spacer(); if sort == opt { Image(systemName: "checkmark") } }
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

// MARK: - Tiny Search bar

private struct SearchBar: View {
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
