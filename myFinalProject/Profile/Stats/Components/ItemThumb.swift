//
//  ItemThumb.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

// ItemThumb is a SwiftUI view that displays a single wardrobe item thumbnail:

struct ItemThumb: View {
    let url: String
    var size: CGSize = .init(width: 86, height: 96)

    var body: some View {
        ZStack {
            Color.white
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img): img.resizable().scaledToFit()
                case .empty: Color.white
                default: Color.white
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}
