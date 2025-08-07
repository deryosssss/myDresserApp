// SharedComponents.swift
// myFinalProject
//
// Created by Derya Baglan on 06/08/2025.
//

import SwiftUI

/// Small edit button used throughout the app
struct TinyEditButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("✎")
                .font(.caption2)
                .foregroundColor(.blue)
                .padding(6)
        }
        .background(Color.white)
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 1))
    }
}

/// Horizontal chip with edit action
struct ChipRowView: View {
    let title: String
    let text: String
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).bold().padding(.horizontal)
            HStack {
                let display = text.trimmingCharacters(in: .whitespaces)
                Text(display.isEmpty ? "None" : display.capitalized)
                    .font(.caption)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                Spacer()
                TinyEditButton(action: onEdit)
            }
            .padding(.horizontal)
        }
    }
}

/// Horizontal scrollable chip section with add action
struct ChipSectionView: View {
    let title: String
    let chips: [String]
    let onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).bold().padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if chips.isEmpty {
                        Text("None")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                            .frame(height: 28)
                    } else {
                        ForEach(chips, id: \.self) { c in
                            Text(c.capitalized)
                                .font(.caption)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        }
                    }
                    TinyEditButton(action: onAdd)
                }
                .padding(.horizontal)
            }
        }
    }
}
