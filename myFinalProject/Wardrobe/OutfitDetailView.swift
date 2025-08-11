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
            // ====== IMAGE CANVAS ======
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(outfit.itemImageURLs, id: \.self) { url in
                    let single = outfit.itemImageURLs.count == 1

                    AsyncImage(url: URL(string: url)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().frame(height: 180)
                        case .success(let img):
                            img
                                .resizable()
                                .scaledToFit()     // see the whole item
                                .frame(height: 180)
                        default:
                            Color.white.frame(height: 180)
                        }
                    }
                    .padding(.horizontal, 5)
                    // If there's only one image, span both columns to remove “empty” side
                    .if(single) { view in
                        view.gridCellColumns(2)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical)
            .padding(.top, 20)
            // Force a clean white backdrop so no grey shows through
            .background(Color.white)

            // ====== FAVORITE & DELETE ======
            HStack {
                Spacer()
                Button {
                    vm.toggleFavorite(outfit)
                } label: {
                    Image(systemName: outfit.isFavorite ? "heart.fill" : "heart")
                        .font(.title)
                        .foregroundColor(.pink)
                        .padding()
                        .background(Color.blue.opacity(0.15))   // light blue bubble
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1)) // thin outline
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

            // ====== ITEMS ROW ======
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
                                    Color.white
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

            // ====== TAGS ======
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
        // “Sandwich” button in the image area; brandYellow + thin black outline
        .overlay(alignment: .bottomLeading) {
            HStack {
                Button {
                    // hook up if you later add actions
                } label: {
                    Image(systemName: "line.horizontal.3")
                        .font(.title2)
                        .padding()
                        .background(Color.brandYellow.opacity(0.25))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 0)
        }
        .background(Color.white) // whole screen white, no grey bleed
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

// MARK: - Tiny conditional modifier helper
private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool,
                             transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }
}
