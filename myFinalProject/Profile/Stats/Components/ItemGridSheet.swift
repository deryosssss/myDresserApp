//
//  ItemGridSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
// Shows a filtered set of wardrobe items in an adaptive grid; each cell loads the item image and links to ItemDetailView

import SwiftUI

struct ItemGridSheet: View {
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
