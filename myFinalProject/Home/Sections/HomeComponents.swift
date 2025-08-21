//
//  HomeComponents.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

struct HomeSectionCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: Content

    init(title: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppFont.agdasima(size: 22))
                    .foregroundColor(.black)
                Spacer()
                accessory()
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HomeView.UX.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: HomeView.UX.cardCorner)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

struct HomeEmptyRow: View {
    let text: String
    var body: some View {
        HStack { Text(text).foregroundStyle(.secondary); Spacer() }
            .padding(.vertical, 8)
    }
}

struct ItemTile: View {
    let url: String
    var body: some View {
        ZStack {
            Color.white
            AsyncImage(url: URL(string: url)) { ph in
                switch ph {
                case .success(let img): img.resizable().scaledToFit()
                case .empty: Color.white
                default: Color.white
                }
            }
        }
        .frame(width: HomeView.UX.thumb.width, height: HomeView.UX.thumb.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

struct DiversityBadge: View {
    let level: String
    var body: some View {
        Text(level)
            .font(AppFont.spicyRice(size: 18))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (level == "High" ? Color.green.opacity(0.25) :
                 level == "Medium" ? Color.orange.opacity(0.25) :
                 Color.red.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct BadgeView: View {
    let title: String
    let system: String
    let achieved: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: system)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(achieved ? Color.brandGreen.opacity(0.35) : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title).font(.caption)
                .foregroundStyle(achieved ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(achieved ? 1 : 0.6)
    }
}
