//
//  DressCodeOutfitsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 13/08/2025.
//
//  Screen that shows outfit suggestions for a given user + dress code.
//  Cards list suggested items; user can Skip to get another, or Save via a preview sheet.
//

import SwiftUI

private enum DCLayout {
    static let cardCorner: CGFloat = 14
    static let cardPadding: CGFloat = 12
    static let gridSpacing: CGFloat  = 12
    static let thumbSize: CGSize     = .init(width: 110, height: 130)
    static let buttonHeight: CGFloat = 28
}

struct DressCodeOutfitsView: View {
    // Immutable inputs for this screen
    let userId: String
    let dressCode: DressCodeOption

    // ViewModel owns data fetching/mutations for this screen.
    // StateObject is created *here* because it depends on (userId, dressCode)
    // and we want it to live for the life of this view (not be recreated on re-renders).
    @StateObject private var vm: DressCodeOutfitsViewModel

    // Local UI-only state for the preview/save sheet.
    @State private var previewItems: [WardrobeItem] = []
    @State private var showPreview = false

    init(userId: String, dressCode: DressCodeOption) {
        self.userId = userId
        self.dressCode = dressCode
        // Instantiate the VM with the required inputs once.
        _vm = StateObject(wrappedValue: DressCodeOutfitsViewModel(userId: userId, dressCode: dressCode))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(dressCode.title)
                    .font(AppFont.spicyRice(size: 24))
                    .padding(.top, 6)

                if vm.cards.isEmpty && !vm.isLoading {
                    emptyState
                        .padding(.horizontal)
                        .padding(.top, 24)
                } else {
                    // One card per suggestion (Identifiable list from the VM).
                    ForEach(vm.cards) { card in
                        SuggestionCard(
                            candidate: card,
                            onSkip: {
                                Task { await vm.skip(card.id) }
                            },
                            onSave: {
                                previewItems = card.orderedItems
                                showPreview = true
                            }
                        )
                    }
                }

                if vm.isLoading { ProgressView().padding(.vertical, 24) }

                Spacer(minLength: 20)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationBarTitleDisplayMode(.inline)

        // Kick off initial data load when the view becomes active.
        // `.task` is async-aware and cancels automatically if the view disappears.
        .task { await vm.loadInitial() }

        // Surface errors propagated by the VM. Button clears the VM error state.
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: { Text(vm.errorMessage ?? "") }

        // Preview/save sheet: shows the chosen items, collects metadata, then asks the VM to persist.
        // We pass `items` explicitly to keep the sheet and VM loosely coupled/testable.
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
    // Friendly explanation + retry button when there are no suggestions to show.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No \(dressCode.rawValue) items yet")
                .font(.headline)
            Text("Add more wardrobe items with this dress code or try another option.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.loadInitial() }
            } label: {
                Text("Try again")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(minWidth: 140, minHeight: DCLayout.buttonHeight)
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

// MARK: - Reusable card (same visual language as your other “card” screens)

private struct SuggestionCard: View {
    let candidate: DCOutfitCandidate
    var onSkip: () -> Void
    var onSave: () -> Void

    // Two flexible columns → adapts nicely to device widths while keeping symmetry.
    private let cols = [
        GridItem(.flexible(), spacing: DCLayout.gridSpacing),
        GridItem(.flexible(), spacing: DCLayout.gridSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: cols, spacing: DCLayout.gridSpacing) {
                ForEach(candidate.orderedItems, id: \.id) { item in
                    // AsyncImage handles load/empty/error states.
                    AsyncImage(url: URL(string: item.imageURL)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .frame(width: DCLayout.thumbSize.width, height: DCLayout.thumbSize.height)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        case .empty:
                            ProgressView()
                                .frame(width: DCLayout.thumbSize.width, height: DCLayout.thumbSize.height)
                        default:
                            Color(.tertiarySystemFill)
                                .frame(width: DCLayout.thumbSize.width, height: DCLayout.thumbSize.height)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            HStack(spacing: 10) {
                Button(role: .cancel, action: onSkip) {
                    Text("Skip")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: DCLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPink)

                Button(action: onSave) {
                    Text("Save")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, minHeight: DCLayout.buttonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandGreen)
            }
        }
        .padding(DCLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DCLayout.cardCorner)
                .fill(Color(.systemGray6))
        )
    }
}
