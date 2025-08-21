//
//  StatsComponents.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//

import SwiftUI

struct StatsSectionCard<Content: View, Accessory: View>: View {
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
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(StatsView.UX.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: StatsView.UX.cardCorner)
                    .fill(Color(.systemGray6))
            )
            .clipShape(RoundedRectangle(cornerRadius: StatsView.UX.cardCorner))
        }
    }
}

struct StatsSectionDisclosure: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .foregroundColor(.black)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(StatsView.UX.cardPadding)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: StatsView.UX.cardCorner))
        }
        .buttonStyle(.plain)
    }
}

struct StatsEmptyRow: View {
    let text: String
    var body: some View {
        HStack { Text(text).foregroundColor(.secondary); Spacer() }
            .padding(.vertical, 8)
    }
}
