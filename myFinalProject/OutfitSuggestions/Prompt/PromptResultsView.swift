//
//  PromptResultsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//


import SwiftUI

// MARK: - Layout

private enum PRLayout {
    static let cardCorner: CGFloat   = 14
    static let cardPadding: CGFloat  = 12
    static let gridSpacing: CGFloat  = 12
    static let thumbSize: CGSize     = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

// MARK: - View

struct PromptResultsView: View {
    @StateObject private var vm: PromptResultsViewModel

    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    init(userId: String, initialPrompt: String) {
        _vm = StateObject(wrappedValue: PromptResultsViewModel(userId: userId, prompt: initialPrompt))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Outfit")
                    .font(AppFont.spicyRice(size: 24))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                Text("“\(vm.prompt)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if vm.cards.isEmpty && !vm.isLoading {
                    emptyState.padding(.horizontal)
                } else {
                    ForEach(vm.cards) { card in
                        SuggestionCard(
                            candidate: card,
                            onSkip: { Task { await vm.skip(card.id) } },
                            onSave: {
                                previewItems = card.orderedItems
                                showPreview = true
                            }
                        )
                    }
                }

                if vm.isLoading {
                    ProgressView().padding(.vertical, 24)
                }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await vm.loadInitial() }
        .refreshable { await vm.loadInitial() }
        .alert("Error",
               isPresented: Binding(get: { vm.errorMessage != nil },
                                   set: { _ in vm.errorMessage = nil })) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }
        .sheet(isPresented: $showPreview) {
            OutfitPreviewSheet(
                items: previewItems,
                onClose: { showPreview = false },
                onSave: { name, occasion, date, description, isFav in
                    Task {
                        await vm.saveOutfit(
                            name: name,
                            occasion: occasion,
                            description: description,
                            date: date,
                            isFavorite: isFav,
                            items: previewItems
                        )
                        showPreview = false
                    }
                }
            )
        }
    }

    // MARK: Empty state
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No suggestions matched exactly")
                .font(.headline)
            Text("Try “red dress and black heels”, “all black smart casual”, “neutral minimal office with loafers”, or add more wardrobe items.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.loadInitial() }
            } label: {
                Text("Try again")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(minWidth: 140, minHeight: PRLayout.buttonHeight)
            }
            .buttonStyle(.borderedProminent)
            .tint(.brandGreen)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
        )
    }
}

// MARK: - Card

private struct SuggestionCard: View {
    let candidate: PCOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    private let cols = [
        GridItem(.flexible(), spacing: PRLayout.gridSpacing),
        GridItem(.flexible(), spacing: PRLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: cols, spacing: PRLayout.gridSpacing) {
                ForEach(candidate.orderedItems, id: \.id) { item in
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                        default:
                            Color(.tertiarySystemFill)
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            if let note = candidate.softMatchNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(role: .cancel, action: onSkip) {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: PRLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: PRLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            }
        }
        .padding(PRLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: PRLayout.cardCorner)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    NavigationStack {
        PromptResultsView(userId: "demo-user", initialPrompt: "Pink shoes black dress, elegant minimal smart casual")
    }
}
