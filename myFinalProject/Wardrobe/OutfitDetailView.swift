//  OutfitDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 08/06/2025.
//

import SwiftUI

struct OutfitDetailView: View {
    @EnvironmentObject var vm: WardrobeViewModel
    let outfit: Outfit

    @State private var showEditTags = false
    @State private var draftTags: [String] = []
    @State private var showDeleteAlert = false

    // Adaptive columns for tags
    private let tagColumns = [
        GridItem(.adaptive(minimum: 80), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            // Canvas of outfit items
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(outfit.itemImageURLs, id: \.self) { url in
                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(height: 180)
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()
                                .frame(height: 180)
                        default:
                            Color(.systemGray4).frame(height: 180)
                        }
                    }
                    .padding(.horizontal, 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical)
            .padding(.top, 20)

            // Favorite & Delete controls
            HStack {
                Spacer()
                Button {
                    vm.toggleFavorite(outfit)
                } label: {
                    Image(systemName: outfit.isFavorite ? "heart.fill" : "heart")
                        .font(.title)
                        .foregroundColor(.red)
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .font(.title)
                        .foregroundColor(.primary)
                }
            }
            .padding(.vertical)
            .padding(.horizontal)

            // Items row
            VStack(alignment: .leading, spacing: 8) {
                Text("Items")
                    .font(.headline)
                    .padding(.horizontal)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(outfit.itemImageURLs, id: \.self) { url in
                            AsyncImage(url: URL(string: url)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 100, height: 120)
                                case .success(let img):
                                    img
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 120)
                                        .clipped()
                                default:
                                    Color(.systemGray4)
                                        .frame(width: 100, height: 120)
                                }
                            }
                            .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top)

            // Tags row (brandGrey, adaptive grid, removable)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tags")
                        .font(.headline)
                    Spacer()
                    Button {
                        draftTags = outfit.tags
                        showEditTags = true
                    } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: tagColumns, spacing: 8) {
                    ForEach(outfit.tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text(tag.capitalized)
                                .font(.caption2)
                                .lineLimit(1)
                            Button {
                                vm.removeTag(outfit, tag: tag)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.brandGrey)
                        .cornerRadius(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 4)

            Spacer(minLength: 40)
        }
        .alert("Delete this outfit?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                vm.delete(outfit)
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showEditTags) {
            NavigationStack {
                Form {
                    Section("Tags") {
                        ForEach(Array(draftTags.enumerated()), id: \.offset) { idx, _ in
                            HStack {
                                TextField(
                                    "Tag",
                                    text: Binding(
                                        get: { draftTags[idx] },
                                        set: { draftTags[idx] = $0 }
                                    )
                                )
                                Button(role: .destructive) {
                                    draftTags.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        Button {
                            draftTags.append("")
                        } label: {
                            Label("Add Tag", systemImage: "plus.circle")
                        }
                    }
                }
                .navigationTitle("Edit Tags")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            vm.updateTags(outfit, newTags: draftTags.filter { !$0.isEmpty })
                            showEditTags = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showEditTags = false
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct OutfitDetailView_Previews: PreviewProvider {
    static let sample = Outfit(
        id: "o1",
        name: "Summer Brunch",
        description: "Light and airy for sunny days",
        imageURL: "https://via.placeholder.com/300/FFA500",
        itemImageURLs: [
            "https://via.placeholder.com/120",
            "https://via.placeholder.com/120/ff0000",
            "https://via.placeholder.com/120/00ff00"
        ],
        itemIDs: ["item1", "item2", "item3"],
        tags: ["Summer", "Crazy", "Beautiful", "Casual", "Brunch", "Interesting"],
        createdAt: Date(),
        lastWorn: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
        wearCount: 4,
        isFavorite: true,
        source: "manual"
    )

    static var previews: some View {
        NavigationStack {
            OutfitDetailView(outfit: sample)
                .environmentObject(WardrobeViewModel())
        }
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
