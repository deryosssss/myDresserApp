//
//  OutfitPreviewCanvasSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//
//

import SwiftUI

struct OutfitPreviewSheet: View {
    let items: [WardrobeItem]               // images to show
    var onClose: () -> Void                 // “Keep editing”
    var onSave: (String, String?, Date?, String, Bool) -> Void

    // Form state
    @State private var name: String = ""
    @State private var occasion: String? = nil
    @State private var createdOn: Date = Date()
    @State private var descriptionText: String = ""
    @State private var isFavorite: Bool = false

    private let occasionOptions: [String] = [
        "Everyday", "Work", "Smart", "Smart casual", "Casual",
        "Party", "Date", "Wedding", "Travel", "Sport", "Gym", "School", "Holiday"
    ]

    // 2-up grid for the big preview
    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Outfit preview")
                            .font(.custom("SpicyRice-Regular", size: 26, relativeTo: .headline))                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

                        // Big preview
                        LazyVGrid(columns: grid, spacing: 12) {
                            ForEach(items, id: \.id) { item in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        AsyncImage(url: URL(string: item.imageURL)) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().scaledToFit()
                                            case .empty: ProgressView()
                                            default: Image(systemName: "photo")
                                            }
                                        }
                                        .padding(10)
                                    )
                                    .frame(height: 200)
                            }
                        }
                        .padding(.horizontal)

                        // Items strip
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items")
                                 .font(AppFont.spicyRice(size: 18))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(items, id: \.id) { item in
                                        AsyncImage(url: URL(string: item.imageURL)) { phase in
                                            switch phase {
                                            case .success(let img):
                                                img.resizable().scaledToFit()
                                            case .empty:
                                                Color(.tertiarySystemFill)
                                            default:
                                                Color(.tertiarySystemFill)
                                            }
                                        }
                                        .frame(width: 90, height: 110)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Meta form
                        VStack(spacing: 12) {
                            TextField("Outfit name (optional)", text: $name)
                                .textFieldStyle(.roundedBorder)
                            HStack {
                                // occasion chips (single select; tap to toggle)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(occasionOptions, id: \.self) { opt in
                                            let selected = occasion == opt
                                            Button {
                                                occasion = selected ? nil : opt
                                            } label: {
                                                Text(opt)
                                                    .font(.caption)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 10)
                                                    .background(selected ? Color.brandBlue : Color.brandGrey)
                                                    .foregroundColor(.black)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }

                            DatePicker("Date", selection: $createdOn, displayedComponents: .date)

                            Toggle(isOn: $isFavorite) {
                                Label("Add to favourites", systemImage: isFavorite ? "heart.fill" : "heart")
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.subheadline)
                                TextEditor(text: $descriptionText)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 8)
                }

                // CTA Row
                HStack(spacing: 12) {
                    Button {
                        onClose()
                    } label: {
                        Text("Keep editing")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandPink)

                    Button {
                        onSave(name, occasion, createdOn, descriptionText, isFavorite)
                    } label: {
                        Text("Save to wardrobe")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onClose() }
                }
            }
        }
    }
}
