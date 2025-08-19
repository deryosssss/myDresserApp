//  FavouritesView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct FavouritesView: View {
    @StateObject private var vm = WardrobeViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Title
                Text("My Favourites")
                    .font(AppFont.spicyRice(size: 28))
                    .foregroundColor(.black)
                    .padding(.vertical, 8)

                ScrollView {
                    if favItems.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "heart")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("No favourite items yet")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(favItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item, wardrobeVM: vm) {
                                        vm.delete(item)
                                    }
                                } label: {
                                    FavItemCard(
                                        item: item,
                                        toggleFavorite: {
                                            vm.toggleFavorite(item)
                                        }
                                    )
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
        }
    }

    private var favItems: [WardrobeItem] {
        vm.items.filter { vm.isFavorite($0) }
    }
}

private struct FavItemCard: View {
    let item: WardrobeItem
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
                Image(systemName: "heart.fill")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .offset(x: -8, y: -8)
        }
    }
}
