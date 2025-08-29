//
//  HomeGreetingHeader.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//  Updated: 22/08/2025 – avatar on the left, added “Welcome”, polish.
//

import SwiftUI

/// Lightweight greeting header:
/// - Avatar on the left (or initials fallback)
/// - “Welcome” label + “Hi, <name>”
/// - Soft gradient card
///

struct HomeGreetingHeader: View {
    let displayName: String
    let profileImage: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
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
            .frame(width: 52, height: 52)
            .clipShape(Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 1, y: 1)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text("Welcome")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Hi, \(displayName)")
                    .font(AppFont.spicyRice(size: 26))
                    .foregroundColor(.black)
            }

            Spacer()
        }
        .padding(HomeView.UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.pink.opacity(0.35),
                         Color.yellow.opacity(0.35),
                         Color.purple.opacity(0.35)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
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
