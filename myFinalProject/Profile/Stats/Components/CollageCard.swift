//
//  CollageCard.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
import SwiftUI

struct CollageCard: View {
    let urls: [String]
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height, s: CGFloat = 2
            let col3W = (w - 2*s) / 3
            let row2H = (h - s) / 2

            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white)
                VStack(spacing: s) {
                    HStack(spacing: s) {
                        tile(0).frame(width: col3W, height: row2H)
                        tile(1).frame(width: col3W, height: row2H)
                        tile(2).frame(width: col3W, height: row2H)
                    }
                    HStack(spacing: s) {
                        tile(3).frame(width: col3W, height: row2H)
                        tile(4).frame(width: col3W, height: row2H)
                        tile(5).frame(width: col3W, height: row2H)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5))
        }
    }
    @ViewBuilder private func tile(_ i: Int) -> some View {
        if i < urls.count {
            ZStack {
                Color.white
                AsyncImage(url: URL(string: urls[i])) { ph in
                    switch ph {
                    case .success(let img): img.resizable().scaledToFit()
                    case .empty: Color.white
                    default: Color.white
                    }
                }
            }
        } else { Color.white }
    }
}

