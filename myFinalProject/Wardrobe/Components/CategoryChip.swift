//
//  CategoryChip.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
import SwiftUI

// Shared chip sizing for CategoryChip
enum CatChipLayout {
    static let boxSize: CGFloat = 56
    static let corner: CGFloat = 10
}

struct CategoryChip: View {
    let title: String
    let imageURL: String?
    let isSelected: Bool
    let isAll: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: CatChipLayout.corner)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: CatChipLayout.corner)
                            .stroke(isSelected ? Color.brandBlue : Color.brandGrey, lineWidth: isSelected ? 2 : 1)
                    )
                    .frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)

                if isAll {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                } else if let urlStr = imageURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .padding(6)
                                .frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)
                        case .empty:
                            ProgressView().frame(width: CatChipLayout.boxSize, height: CatChipLayout.boxSize)
                        default:
                            Image(systemName: "photo").foregroundColor(.secondary)
                        }
                    }
                } else {
                    Image(systemName: "photo").foregroundColor(.secondary)
                }
            }
            Text(title)
                .font(.caption2)
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
