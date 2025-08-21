//
//  WardrobeItemCard.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import SwiftUI

struct WardrobeItemCard: View {
    let item: WardrobeItem
    let isFavorite: Bool
    let toggleFavorite: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: URL(string: item.imageURL)) { phase in
                switch phase {
                case .empty:
                    ProgressView().frame(width: 160, height: 180)
                case .success(let img):
                    img.resizable()
                        .scaledToFit()
                        .frame(width: 160, height: 180)
                        .background(Color(.white))
                default:
                    Color(.white).frame(width: 160, height: 180)
                }
            }
            Button(action: toggleFavorite) {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .offset(x: -8, y: -8)
        }
    }
}
