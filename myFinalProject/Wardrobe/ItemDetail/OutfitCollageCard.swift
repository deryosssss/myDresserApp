//
//  OutfitCollageCard.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import SwiftUI

/// Reusable collage card used across the app (Item detail, Outfits list, etc.)
struct OutfitCollageCard: View {
    let outfit: Outfit

    var body: some View {
        ZStack(alignment: .topTrailing) {
            OutfitCollageView(urls: outfit.itemImageURLs)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))

            if outfit.isFavorite {
                Image(systemName: "heart.fill")
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .padding(6)
            }
        }
    }
}

/// The grid layout that arranges up to 6 images.
struct OutfitCollageView: View {
    let urls: [String]

    private func tile(_ url: String) -> some View {
        AsyncImage(url: URL(string: url)) { phase in
            switch phase {
            case .empty: Color(.secondarySystemBackground)
            case .success(let img): img.resizable().scaledToFit()
            default: Color(.tertiarySystemFill)
            }
        }
        .clipped()
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, s: CGFloat = 2
            let col2W = (w - s) / 2
            let row2H = (h - s) / 2
            let col3W = (w - 2*s) / 3
            let row3H = (h - s) / 2

            ZStack {
                switch min(urls.count, 6) {
                case 0:
                    Color(.secondarySystemBackground)

                case 1:
                    tile(urls[0]).frame(width: w, height: h)

                case 2:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col2W, height: h)
                        tile(urls[1]).frame(width: col2W, height: h)
                    }

                case 3:
                    HStack(spacing: s) {
                        tile(urls[0]).frame(width: col3W, height: h)
                        tile(urls[1]).frame(width: col3W, height: h)
                        tile(urls[2]).frame(width: col3W, height: h)
                    }

                case 4:
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col2W, height: row2H)
                            tile(urls[1]).frame(width: col2W, height: row2H)
                        }
                        HStack(spacing: s) {
                            tile(urls[2]).frame(width: col2W, height: row2H)
                            tile(urls[3]).frame(width: col2W, height: row2H)
                        }
                    }

                case 5, 6:
                    VStack(spacing: s) {
                        HStack(spacing: s) {
                            tile(urls[0]).frame(width: col3W, height: row3H)
                            tile(urls[1]).frame(width: col3W, height: row3H)
                            tile(urls[2]).frame(width: col3W, height: row3H)
                        }
                        HStack(spacing: s) {
                            tile(urls[3]).frame(width: col3W, height: row3H)
                            tile(urls[4]).frame(width: col3W, height: row3H)
                            if urls.count >= 6 {
                                tile(urls[5]).frame(width: col3W, height: row3H)
                            } else {
                                Color(.secondarySystemBackground).frame(width: col3W, height: row3H)
                            }
                        }
                    }

                default:
                    EmptyView()
                }
            }
        }
    }
}
