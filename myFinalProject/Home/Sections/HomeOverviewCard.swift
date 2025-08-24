//
//  HomeOverviewCard.swift
//  myFinalProject
//
//  Created by Derya Baglan on 22/08/2025.
//  Updated: 22/08/2025 – compact tiles, tighter padding, consistent with app UI.
//

import SwiftUI

/// Overview banner showing totals for items and outfits.
/// Tapping tiles triggers the provided closures (navigate to Wardrobe tabs).
struct HomeOverviewCard: View {
    let totalItems: Int
    let totalOutfits: Int
    var onTapItems: () -> Void
    var onTapOutfits: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PressableTile { onTapItems() } content: {
                statTile(title: "Items", value: "\(totalItems)", system: "tshirt.fill")
            }

            PressableTile { onTapOutfits() } content: {
                statTile(title: "Outfits", value: "\(totalOutfits)", system: "hanger")
            }
        }
        .padding(.horizontal, HomeView.UX.cardPadding)
        .padding(.vertical, 8) // slimmer than default card padding
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: HomeView.UX.cardCorner)
                .fill(Color(.systemGray6))
        )
    }

    /// Compact stat tile with icon, label, value and chevron.
    /// Heights + sizes tuned to feel consistent with your other cards.
    private func statTile(title: String, value: String, system: String) -> some View {
        HStack(spacing: 10) {
            // smaller icon chip
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                Image(systemName: system)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.black)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(AppFont.spicyRice(size: 18))
                    .foregroundColor(.black)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)       // tighter
        .padding(.horizontal, 10)    // tighter
        .frame(height: 52)           // fixed compact height
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(value)")
    }
}

/// Simple press effect wrapper used by both tiles.
private struct PressableTile<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: () -> Content
    @State private var pressed = false

    var body: some View {
        content()
            .scaleEffect(pressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: pressed)
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.01, pressing: { isPressing in
                pressed = isPressing
            }, perform: { })
            .hoverEffect(.highlight)
    }
}
