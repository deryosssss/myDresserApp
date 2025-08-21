//
//  HomeChallengeSection.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

/// Reusable "Spin a challenge" section used on Home.

struct HomeChallengeSection: View {
    let text: String
    let spinning: Bool
    let previewURL: String?
    let hasFocusItem: Bool

    var onSpin: () -> Void
    var onAccept: () -> Void

    var body: some View {
        HomeSectionCard(title: "Spin a challenge") {
            VStack(spacing: 12) {
                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.leading)

                if let url = previewURL {
                    HStack {
                        Spacer()
                        ItemTile(url: url)
                            .frame(width: 160, height: 200)
                        Spacer()
                    }
                }

                Button(action: onSpin) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .rotationEffect(.degrees(spinning ? 360 : 0))
                            .animation(.linear(duration: 0.6), value: spinning)
                        Text("Spin")
                            .font(AppFont.spicyRice(size: 18))
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.brandPeach)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if hasFocusItem {
                    Button(action: onAccept) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Challenge accepted · Create outfit")
                                .font(AppFont.spicyRice(size: 18))
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.brandPurple)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
}
