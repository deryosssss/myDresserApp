//
//  BadgeDefinitionsSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

/// Bottom sheet that explains how each badge is earned.
/// Inputs are the user’s current metrics so we can show achieved state + progress.
struct BadgeDefinitionsSheet: View {
    // Inputs passed from parent screen (HomeView)
    let outfitsThisMonth: Int
    let co2ThisMonth: Double
    let itemsCount: Int
    let streak7: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Definitions") {
                    // Each BadgeRow encapsulates one badge’s visuals + logic.
                    // `achieved` is computed here so the row stays dumb/presentational.
                    BadgeRow(symbol: "tshirt",
                             title: "Starter",
                             desc: "Add your first item to the wardrobe.",
                             achieved: itemsCount >= 1)

                    BadgeRow(symbol: "tshirt.fill",
                             title: "Builder",
                             desc: "Reach 15 items in your wardrobe.",
                             achieved: itemsCount >= 15)

                    // Show numeric progress to guide the user.
                    BadgeRow(symbol: "sparkles",
                             title: "Outfit Pro",
                             desc: "Log 12 outfits this month.",
                             achieved: outfitsThisMonth >= 12,
                             progress: "\(outfitsThisMonth)/12")

                    // Format CO₂ with 1 decimal; threshold = 10 kg.
                    BadgeRow(symbol: "leaf.fill",
                             title: "Eco Hero",
                             desc: "Save 10 kg CO₂ this month (by re-wearing).",
                             achieved: co2ThisMonth >= 10,
                             progress: String(format: "%.1f/10 kg", co2ThisMonth))

                    // Cap the displayed progress at the target so it doesn’t read 6/5, etc.
                    BadgeRow(symbol: "flame.fill",
                             title: "Streak 5",
                             desc: "Hit a 5-day wear streak.",
                             achieved: streak7 >= 5,
                             progress: "\(min(streak7, 5))/5")
                }
            }
            .navigationTitle("Badges")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
}

/// Presentational row for a single badge.
/// Keeps logic minimal: shows icon, title, description, achieved checkmark, and optional progress.
struct BadgeRow: View {
    let symbol: String          // SF Symbol name for the badge icon
    let title: String           // Badge title
    let desc: String            // What the badge means / how to earn
    let achieved: Bool          // Whether the user has met the threshold
    var progress: String? = nil // Optional progress string (e.g. "7/12")

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon with subtle “earned” background tint
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
                .background(achieved ? Color.brandGreen.opacity(0.35) : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.headline)
                    // Visual confirmation when achieved
                    if achieved { Image(systemName: "checkmark.seal.fill") }
                    Spacer()
                }
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Progress is optional—only shown for badges with partial progress.
                if let p = progress {
                    Text(p)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .opacity(achieved ? 1 : 0.85)
    }
}
