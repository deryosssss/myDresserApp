//
//  HomeCO2Card.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Compact, reusable CO₂ summary card for Home.
struct HomeCO2Card: View {
    let kilograms: Double
    @Binding var showInfo: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text("We estimate you saved")
            // Info button → toggles explanatory popover.
            Button { showInfo = true } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }
            .accessibilityLabel("What does CO₂ saved mean?")
            Spacer()
            Text(String(format: "%.1f kg CO₂", kilograms))
                .font(AppFont.spicyRice(size: 20))
        }
        .foregroundColor(.black)
        .padding(HomeView.UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.brandYellow)
        .clipShape(RoundedRectangle(cornerRadius: HomeView.UX.cardCorner))
        .accessibilityLabel("Estimated carbon saved this month \(kilograms, specifier: "%.1f") kilograms")
        .popover(isPresented: $showInfo) {
            DefinitionPopover(
                title: "CO₂ saved",
                definition: """
                A lightweight estimate of carbon **avoided by re-wearing items** this month.

                **How we compute it**
                • Count outfits you logged this month.
                • Multiply by **0.8 kg CO₂** per outfit (simple heuristic per re-wear).

                **Notes**
                • Directional only — actual impact varies by garment type, care (washing/drying), and what you might have bought instead.
                • We’ll refine this as we add per-item footprints.
                """
            )
            .frame(maxWidth: 360)
            .padding()
        }
    }
}
