//
//  ItemDetailImageHeader.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

struct ItemDetailImageHeader: View {
    let imageURL: String
    let isUploading: Bool
    let bubbleSize: CGFloat
    let iconSize: CGFloat
    let isFavorite: Bool
    var onOptionsTapped: () -> Void
    var onFavoriteTapped: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.white
                .overlay(
                    AsyncImage(url: URL(string: imageURL)) { ph in
                        switch ph {
                        case .empty:    ProgressView()
                        case .success(let img): img.resizable().scaledToFit()
                        default:        Color.white
                        }
                    }
                    .overlay {
                        if isUploading {
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                VStack(spacing: 10) {
                                    ProgressView()
                                    Text("Updating photo…").font(.footnote)
                                }
                            }
                        }
                    }
                )
                .frame(height: 300)
                .animation(.default, value: isUploading)

            HStack {
                Button(action: onOptionsTapped) {
                    ZStack {
                        Circle().fill(Color.brandYellow.opacity(0.25))
                        Circle().stroke(Color.black, lineWidth: 1)
                        Image(systemName: "line.horizontal.3")
                            .resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(.black)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }
                .accessibilityIdentifier("itemOptionsButton")

                Spacer()

                Button(action: onFavoriteTapped) {
                    ZStack {
                        Circle().fill(Color.blue.opacity(0.15))
                        Circle().stroke(Color.black, lineWidth: 1)
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .resizable().scaledToFit()
                            .frame(width: iconSize, height: iconSize)
                            .foregroundColor(isFavorite ? .red : .black)
                            .scaleEffect(isFavorite ? 1.12 : 1.0)
                    }
                    .frame(width: bubbleSize, height: bubbleSize)
                }
                .accessibilityIdentifier("favoriteButton")
            }
            .padding(.horizontal, 24)
            .offset(y: -24)
        }
        .background(Color.white)
    }
}
