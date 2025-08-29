//
//  HomeUsageSection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Small, focused card that visualizes wardrobe usage:
/// - exposes a window selector (All / 90d / 30d)
/// - shows used vs not-used counts + a progress bar
/// - calls out items unused for 90 days

struct HomeUsageSection: View {
    @Binding var window: HomeViewModel.Window
    let usedCount: Int
    let total: Int
    let usagePercent: Int
    let unused90Count: Int

    var body: some View {
        HomeSectionCard(title: "Your Wardrobe Usage") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("", selection: $window) {
                    ForEach(HomeViewModel.Window.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("\(usedCount) used")
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(max(total - usedCount, 0)) not used")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(usagePercent)%")
                        .font(.headline)
                }
                // Progress bar:
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 22)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandGreen.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(usagePercent) / 100, height: 22)
                            .animation(.easeInOut(duration: 0.4), value: usagePercent)
                    }
                }
                .frame(height: 22)

                HStack {
                    Text("Unused for 90 days:")
                    Spacer()
                    Text("\(unused90Count) items")
                        .font(AppFont.spicyRice(size: 18))
                }
            }
        }
    }
}
