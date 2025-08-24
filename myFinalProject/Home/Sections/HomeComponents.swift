//
//  HomeComponents.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

// MARK: - Section Card (container with title, optional accessory, and slotted content)

/// Reusable card used across Home.
struct HomeSectionCard<Content: View, Accessory: View>: View {
    /// Leading title label.
    let title: String
    /// Optional trailing control (e.g. info button). Defaults to `EmptyView()`.
    @ViewBuilder var accessory: () -> Accessory
    /// Main body content (caller supplies any view tree).
    @ViewBuilder var content: Content

    /// Custom init so callers can omit the accessory closure cleanly.
    init(title: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row: title on the left, accessory on the right
            HStack {
                Text(title)
                    .font(AppFont.agdasima(size: 22))
                    .foregroundColor(.black)
                Spacer()
                accessory()
            }

            // Content area placed inside a soft, rounded container
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HomeView.UX.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: HomeView.UX.cardCorner)
                    .fill(Color(.systemGray6)) // subtle neutral background for contrast
            )
        }
    }
}

// MARK: - Empty Row (uniform empty-state line)

/// Single-line, subdued empty state used inside lists/sections.
struct HomeEmptyRow: View {
    let text: String
    var body: some View {
        HStack {
            Text(text).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Item Tile (image in a bordered, elevated tile)

/// Small product/wardrobe thumbnail:
struct ItemTile: View {
    let url: String
    var body: some View {
        ZStack {
            Color.white // base so empty/loading states don't show system bg through
            AsyncImage(url: URL(string: url)) { ph in
                switch ph {
                case .success(let img):
                    img.resizable().scaledToFit() // preserve aspect ratio without cropping
                case .empty:
                    Color.white // keep surface consistent while loading
                default:
                    Color.white // failed → same neutral surface
                }
            }
        }
        .frame(width: HomeView.UX.thumb.width, height: HomeView.UX.thumb.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator), lineWidth: 0.5) // crisp edge, light contrast
        )
        .contentShape(RoundedRectangle(cornerRadius: 10)) // taps respect rounded edge
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1) // subtle lift
    }
}

// MARK: - Diversity Badge (colored chip reflecting level)

/// Compact “badge chip” showing diversity level:
struct DiversityBadge: View {
    let level: String
    var body: some View {
        Text(level)
            .font(AppFont.spicyRice(size: 18))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (level == "High" ? Color.green.opacity(0.25) :
                 level == "Medium" ? Color.orange.opacity(0.25) :
                 Color.red.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Badge Icon Tile (used in the Badges row)

/// Icon + title tile representing an achievement badge:
struct BadgeView: View {
    let title: String
    let system: String
    let achieved: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: system)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(achieved ? Color.brandGreen : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title)
                .font(.caption)
                .foregroundStyle(achieved ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)  // spreads evenly in HStacks
        .opacity(achieved ? 1 : 0.6) // subtle “locked” effect
    }
}
