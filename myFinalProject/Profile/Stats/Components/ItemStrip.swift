//
//  ItemStrip.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI
// displays a horizontal scrolling row of wardrobe items. Each item is shown as a thumbnail (ItemThumb) and acts as a NavigationLink to its detailed view, while handling empty states by showing a simple "No data" message
struct ItemStrip: View {
    let items: [WardrobeItem]
    let vm: WardrobeViewModel
    var thumbSize: CGSize = .init(width: 86, height: 96)

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
                            ItemThumb(url: item.imageURL, size: thumbSize)
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
