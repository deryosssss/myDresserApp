//
//  PromptResultsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//

import SwiftUI

// MARK: - Layout
/// Centralised layout tokens so the card/grid sizing is consistent and easy to tweak.
/// Keeping them static avoids magic numbers sprinkled through the view.
private enum PRLayout {
    static let cardCorner: CGFloat   = 14
    static let cardPadding: CGFloat  = 12
    static let gridSpacing: CGFloat  = 12
    static let thumbSize: CGSize     = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

// MARK: - View

struct PromptResultsView: View {
    /// Owns async state (cards/loading/errors). `@StateObject` ensures the VM
    /// is created once per view instance and survives SwiftUI body updates.
    @StateObject private var vm: PromptResultsViewModel

    /// Local UI state for the preview sheet. We collect the card’s items here
    /// and pass them to `OutfitPreviewSheet` when the user taps “Save”.
    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    /// We inject `userId` and the natural-language `initialPrompt` so the VM
    /// can generate prompt-constrained outfit candidates on first load.
    init(userId: String, initialPrompt: String) {
        _vm = StateObject(wrappedValue: PromptResultsViewModel(userId: userId, prompt: initialPrompt))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Screen header
                Text("Your Outfit")
                    .font(AppFont.spicyRice(size: 24))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                // Show the active prompt as context (quoted and deemphasised)
                Text("“\(vm.prompt)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                // Results list (cards) or an “empty” suggestion if none matched
                if vm.cards.isEmpty && !vm.isLoading {
                    emptyState.padding(.horizontal)
                } else {
                    ForEach(vm.cards) { card in
                        SuggestionCard(
                            candidate: card,
                            // Skip replaces this card with a new variation (keeps the deck fresh)
                            onSkip: { Task { await vm.skip(card.id) } },
                            // Save previews first; we pass items to the sheet for metadata input
                            onSave: {
                                previewItems = card.orderedItems
                                showPreview = true
                            }
                        )
                    }
                }

                // Spinner while the VM is fetching/building suggestions
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

        // Initial load when the view first appears.
        .task { await vm.loadInitial() }

        // Pull-to-refresh to re-run the generation with the existing prompt.
        .refreshable { await vm.loadInitial() }

        // Lightweight error surfacing. The Binding maps “non-nil error” → presented.
        .alert(
            "Error",
            isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { _ in vm.errorMessage = nil } // clear on dismiss
            )
        ) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }

        // Save flow: confirm metadata, then persist the currently previewed items as an outfit.
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
    /// Friendly guidance for when no card strictly matches the prompt.
    /// Offers some example prompts and a retry button that re-triggers generation.
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
/// Visual representation of a single AI-picked outfit candidate:
/// • 2-column grid of item thumbnails
/// • Optional note when it’s a soft/approximate match
/// • Primary actions: Skip (spin a variant) / Save (open preview)
private struct SuggestionCard: View {
    let candidate: PCOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    // Two flexible columns → keeps thumbs balanced on small screens.
    private let cols = [
        GridItem(.flexible(), spacing: PRLayout.gridSpacing),
        GridItem(.flexible(), spacing: PRLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Collage of the items that make up this candidate
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
                            // Placeholder while image loads
                            ProgressView()
                                .frame(width: PRLayout.thumbSize.width, height: PRLayout.thumbSize.height)
                        default:
                            // Fallback for failures/timeouts
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

            // Primary actions
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


