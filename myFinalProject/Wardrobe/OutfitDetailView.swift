//  OutfitDetailView.swift
//  myFinalProject
//
//  Created by ChatGPT on 08/06/2025.
//

import SwiftUI

struct OutfitDetailView: View {
    let outfit: Outfit

    var body: some View {
        ScrollView {
            // Canvas
            ZStack {
                Color(.systemGray5)
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    ForEach(outfit.itemImageURLs, id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { ph in
                            switch ph {
                            case .empty: ProgressView().frame(height:120)
                            case .success(let img): img.resizable().scaledToFit().frame(height:120)
                            default: Color(.systemGray4).frame(height:120)
                            }
                        }
                        .cornerRadius(8)
                    }
                }
                .padding(16)
            }
            .frame(height: 300)
            .cornerRadius(12)
            .padding(.horizontal)

            // Items
            VStack(alignment: .leading) {
                Text("Items").font(.headline).padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing:12) {
                        ForEach(outfit.itemImageURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { ph in
                                switch ph {
                                case .empty: ProgressView().frame(width:80,height:80)
                                case .success(let img):
                                    img.resizable().scaledToFill().frame(width:80,height:80).clipped()
                                default: Color(.systemGray4).frame(width:80,height:80)
                                }
                            }
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)

            // Tags
            VStack(alignment: .leading) {
                Text("Tags").font(.headline).padding(.horizontal)
                FlowLayout(data: outfit.tags, spacing: 8) { tag in
                    Text(tag.capitalized)
                        .font(.caption2)
                        .padding(.vertical,6)
                        .padding(.horizontal,12)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.top)

            Spacer(minLength:40)
        }
        .navigationTitle("Outfit Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// A simple flow layout for tags
struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = 0

    var body: some View {
        VStack { GeometryReader { geo in generate(in: geo) } }
        .frame(height: totalHeight)
    }

    private func generate(in g: GeometryProxy) -> some View {
        var x: CGFloat = 0, y: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .padding(4)
                    .alignmentGuide(.leading) { d in
                        if x + d.width > g.size.width {
                            x = 0
                            y -= d.height + spacing
                        }
                        let result = x
                        x += d.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = y
                        return result
                    }
            }
        }
        .background(GeometryReader { proxy in
            Color.clear.preference(key: HeightKey.self, value: proxy.size.height)
        })
        .onPreferenceChange(HeightKey.self) { totalHeight = $0 }
    }
}

private struct HeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// FlowLayout & HeightReader etc remain the same...

#if DEBUG
struct OutfitDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            OutfitDetailView(outfit:
                Outfit(
                    id: "out1", imageURL: "https://via.placeholder.com/150",
                    itemImageURLs: [
                        "https://via.placeholder.com/150",
                        "https://via.placeholder.com/150/0000FF",
                        "https://via.placeholder.com/150/FF0000",
                        "https://via.placeholder.com/150/00FF00"
                    ],
                    tags: ["Summer", "Casual", "Blue"]
                )
            )
        }
    }
}
#endif
