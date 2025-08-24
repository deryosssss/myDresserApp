//
//  HomeBadgesSection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Compact, reusable “Badges” block for the Home screen.
/// - Inputs are pure values (counts) so this view stays stateless/testable.

struct HomeBadgesSection: View {
    // Data used to determine which badges are achieved
    let totalItems: Int
    let outfitsThisMonth: Int
    let co2ThisMonth: Double
    let streak7: Int

    @Binding var showInfo: Bool

    var body: some View {
        HomeSectionCard(title: "Badges", accessory: {
            Button { showInfo = true } label: {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("What do badges mean?")
        }) {
            HStack(spacing: 12) {
                BadgeView(title: "Starter",    system: "tshirt",
                          achieved: totalItems >= 10)

                BadgeView(title: "Builder",    system: "tshirt.fill",
                          achieved: totalItems >= 25)

                BadgeView(title: "Outfit Pro", system: "sparkles",
                          achieved: outfitsThisMonth >= 12)

                BadgeView(title: "Eco Hero",   system: "leaf.fill",
                          achieved: co2ThisMonth >= 10)

                BadgeView(title: "Streak 5",   system: "flame.fill",
                          achieved: streak7 >= 5)
            }
        }
        // Sheet shows friendly definitions + progress. We pass the raw inputs so
        // the sheet can render progress text (e.g., “8/12”) without re-deriving.
        .sheet(isPresented: $showInfo) {
            BadgeDefinitionsSheet(
                outfitsThisMonth: outfitsThisMonth,
                co2ThisMonth: co2ThisMonth,
                itemsCount: totalItems,
                streak7: streak7
            )
        }
    }
}

