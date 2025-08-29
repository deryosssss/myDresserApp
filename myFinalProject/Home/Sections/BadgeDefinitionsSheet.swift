//
//  BadgeDefinitionsSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

/// Bottom sheet that explains how each badge is earned.
/// Inputs are the user’s current metrics so we can show achieved state + progress.
///
struct BadgeDefinitionsSheet: View {
    let outfitsThisMonth: Int
    let co2ThisMonth: Double
    let itemsCount: Int
    let streak7: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Definitions") {
                    // Each BadgeRow encapsulates one badge’s visuals + logic.
                    // `achieved` is computed here
                    BadgeRow(symbol: "tshirt",
                             title: "Starter",
                             desc: "Add your first 10 items to the wardrobe.",
                             achieved: itemsCount >= 10)

                    BadgeRow(symbol: "tshirt.fill",
                             title: "Builder",
                             desc: "Reach 25 items in your wardrobe.",
                             achieved: itemsCount >= 25)

                    BadgeRow(symbol: "sparkles",
                             title: "Outfit Pro",
                             desc: "Log 30 outfits this month.",
                             achieved: outfitsThisMonth >= 30,
                             progress: "\(outfitsThisMonth)/30")

                    BadgeRow(symbol: "leaf.fill",
                             title: "Eco Hero",
                             desc: "Save 10 kg CO₂ this month (by re-wearing).",
                             achieved: co2ThisMonth >= 10,
                             progress: String(format: "%.1f/10 kg", co2ThisMonth))

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
                .background(achieved ? Color.brandGreen : Color(.systemGray5))
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
