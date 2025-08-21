//
//  ItemDetailStatsSection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import SwiftUI

struct ItemDetailStatsSection: View {
    let lastWornText: String
    let outfitCount: Int
    let addedAtDate: Date?
    let isUnderused: Bool
    var onEditLastWorn: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                statCard(icon: "calendar", title: "Last worn", value: lastWornText)
                TinyEditButton { onEditLastWorn() }
            }
            statCard(icon: "tshirt", title: "Outfits made", value: "\(outfitCount)")
            statCard(icon: "clock", title: "Added", value: addedText)
            if isUnderused {
                statCard(icon: "exclamationmark.triangle", title: "Underused", value: "Not worn >90d")
                    .background(Color.brandYellow)
                    .cornerRadius(8)
            }
        }
    }

    private var addedText: String {
        let f = DateFormatter()
        f.dateStyle = .short
        return addedAtDate.map { f.string(from: $0) } ?? "__/__/__"
    }

    private func statCard(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon).frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption).foregroundColor(.secondary)
                Text(value).font(.headline)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
