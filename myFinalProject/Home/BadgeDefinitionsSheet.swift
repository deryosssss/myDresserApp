//
//  BadgeDefinitionsSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

struct BadgeDefinitionsSheet: View {
    let outfitsThisMonth: Int
    let co2ThisMonth: Double
    let itemsCount: Int
    let streak7: Int

    var body: some View {
        NavigationStack {
            List {
                Section("Definitions") {
                    BadgeRow(symbol: "tshirt", title: "Starter",
                             desc: "Add your first item to the wardrobe.",
                             achieved: itemsCount >= 1)
                    BadgeRow(symbol: "tshirt.fill", title: "Builder",
                             desc: "Reach 15 items in your wardrobe.",
                             achieved: itemsCount >= 15)
                    BadgeRow(symbol: "sparkles", title: "Outfit Pro",
                             desc: "Log 12 outfits this month.",
                             achieved: outfitsThisMonth >= 12,
                             progress: "\(outfitsThisMonth)/12")
                    BadgeRow(symbol: "leaf.fill", title: "Eco Hero",
                             desc: "Save 10 kg CO₂ this month (by re-wearing).",
                             achieved: co2ThisMonth >= 10,
                             progress: String(format: "%.1f/10 kg", co2ThisMonth))
                    BadgeRow(symbol: "flame.fill", title: "Streak 5",
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

struct BadgeRow: View {
    let symbol: String
    let title: String
    let desc: String
    let achieved: Bool
    var progress: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 30, height: 30)
                .background(achieved ? Color.brandGreen.opacity(0.35) : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title).font(.headline)
                    if achieved { Image(systemName: "checkmark.seal.fill") }
                    Spacer()
                }
                Text(desc).font(.subheadline).foregroundStyle(.secondary)
                if let p = progress { Text(p).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .opacity(achieved ? 1 : 0.85)
    }
}
