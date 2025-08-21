//
//  ItemDetailOutfitsGrid.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import SwiftUI

struct ItemDetailOutfitsGrid: View {
    let outfits: [Outfit]
    let wardrobeVM: WardrobeViewModel

    private struct Row: Identifiable { let id: String; let outfit: Outfit }

    private var rows: [Row] {
        outfits.enumerated().map { idx, o in
            Row(id: o.id ?? "local-\(idx)-\(o.imageURL)", outfit: o)
        }
    }

    var body: some View {
        if rows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("No outfits yet")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)],
                      spacing: 12) {
                ForEach(rows) { row in
                    NavigationLink {
                        OutfitDetailView(outfit: row.outfit)
                            .environmentObject(wardrobeVM)
                    } label: {
                        OutfitCollageCard(outfit: row.outfit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
