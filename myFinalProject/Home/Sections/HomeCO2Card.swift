//
//  HomeCO2Card.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//  Updated: 22/08/2025 – interactive assumptions + clearer copy.
//  The card now shows the **current estimate** and lets users tweak the math.
//

import SwiftUI

/// Compact CO₂ summary card for Home.
/// - Shows the **current month** total based on the user's assumptions.
/// - Tapping the card opens the detailed insights view.
/// - Tapping the (i) opens a settings sheet where users can adjust the model.
struct HomeCO2Card: View {
    let outfitsThisMonth: Int
    @ObservedObject var settings: CO2SettingsStore
    /// The parent owns presentation state. When `true`, we present the assumptions sheet.
    @Binding var showSettings: Bool
    
    /// Open the detailed CO₂ trends view.
    var onOpenDetails: () -> Void
    
    private var kilograms: Double {
        Double(outfitsThisMonth) * settings.estimatedKgPerOutfit
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("We estimate you saved")
                Text(settings.mode == .simple
                     ? "Based on \(settings.simplePerOutfit, specifier: "%.1f") kg per outfit"
                     : "Advanced model (purchase displacement + care)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button { showSettings = true } label: {
                Image(systemName: "info.circle").foregroundStyle(.secondary)
            }
            .accessibilityLabel("CO₂ assumptions")

            Spacer()

            HStack(spacing: 6) {
                Text(String(format: "%.1f kg CO₂", kilograms))
                    .font(AppFont.spicyRice(size: 20))
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundColor(.black)
        .padding(HomeView.UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.brandYellow)
        .clipShape(RoundedRectangle(cornerRadius: HomeView.UX.cardCorner))
        .accessibilityLabel("Estimated carbon saved this month \(kilograms, specifier: "%.1f") kilograms. Double tap for details.")
        .onTapGesture { onOpenDetails() }
    }
}
