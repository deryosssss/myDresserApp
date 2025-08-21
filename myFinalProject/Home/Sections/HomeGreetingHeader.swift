//
//  HomeGreetingHeader.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Header used on Home to greet the user and surface quick context:
/// - shows profile image or fallback initials
/// - "Hi, <name>" + monthly headline
/// - small streak counter with an explainer popover
/// - subtle gradient card background to make it feel “hero-like” without stealing focus

struct HomeGreetingHeader: View {
    let displayName: String
    let monthlyHeadline: String
    let streak: Int
    let profileImage: UIImage?
    @Binding var showStreakInfo: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Group {
                    if let img = profileImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(Color.brandPeach)
                            Text(initials(displayName))
                                .font(.title2.bold())
                                .foregroundColor(.black)
                        }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, \(displayName)")
                        .font(AppFont.spicyRice(size: 26))
                        .foregroundColor(.black)
                    Text(monthlyHeadline)
                        .font(AppFont.agdasima(size: 18))
                        .foregroundColor(.black.opacity(0.8))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("Streak").font(.caption).foregroundStyle(.secondary)
                    Text("\(streak)🔥").font(.headline)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture { showStreakInfo = true }
                .popover(isPresented: $showStreakInfo) {
                    DefinitionPopover(
                        title: "Your streak",
                        definition: """
                        Counts consecutive days (up to 7) you **logged at least one outfit**. If yesterday had an outfit but today not yet, we still show your streak continuing.
                        """
                    )
                    .frame(maxWidth: 360)
                    .padding()
                }
                .accessibilityLabel("Streak \(streak) days. Double tap for info.")
            }
        }
        .padding(HomeView.UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [
                Color.pink.opacity(0.35),
                Color.yellow.opacity(0.35),
                Color.purple.opacity(0.35)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: HomeView.UX.cardCorner))
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
