//
//  HomeDiversitySection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Compact section showing a “style diversity” score for a chosen window.
/// - `windowLabel` is a human string for the selected window (e.g. “30d”).
/// - `score` is a normalized value 0…1 driving the progress bar.
/// - `level` is the qualitative label shown in the chip (e.g. High/Medium/Low).
/// - `showInfo` is a binding so the parent decides when to present the info popover.
///
struct HomeDiversitySection: View {
    let windowLabel: String
    let score: Double
    let level: String
    @Binding var showInfo: Bool

    var body: some View {
        HomeSectionCard(title: "Style diversity", accessory: {
            Button { showInfo = true } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }
            .accessibilityLabel("What is style diversity?")
        }) {
            HStack(alignment: .center) {
                DiversityBadge(level: level)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Last \(windowLabel) variety: \(level)")
                        .font(AppFont.agdasima(size: 18))
                    ProgressView(value: score)
                        .tint(diversityColor(score))
                        .animation(.easeInOut(duration: 0.3), value: score) // smooth updates on window change
                }

                Spacer() // pushes content to the left within the card
            }
        }
        // Lightweight explainer shown from the info button; uses shared DefinitionPopover.
        .popover(isPresented: $showInfo) {
            DefinitionPopover(
                title: "Style diversity",
                definition: """
                Measures the variety of **categories you actually wore** in the selected window.

                We compute a diversity index across items in your outfits (e.g. Tops, Bottoms, Outerwear, Shoes, Accessories). Higher = more variety.
                """
            )
            .frame(maxWidth: 360)
            .padding()
        }
    }

    // Maps a normalized score to a semantic color:
    // <0.35 poor (red), 0.35–0.65 ok (orange), >0.65 strong (green).
    // Using opacity keeps colors subtle against the neutral card background.
    private func diversityColor(_ s: Double) -> Color {
        switch s {
        case ..<0.35: return .red.opacity(0.6)
        case ..<0.65: return .orange.opacity(0.7)
        default:      return .green.opacity(0.7)
        }
    }
}

