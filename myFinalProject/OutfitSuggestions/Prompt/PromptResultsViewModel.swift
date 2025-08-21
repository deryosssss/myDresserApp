//
//  PromptResultsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 14/08/2025.
//
//  Drive “prompt-based” outfit results. This VM parses the user’s prompt into a
//  query (via `parsePrompt`), delegates outfit assembly to `OutfitEngine`, and
//  exposes a small deck of suggestion cards. Users can skip to replace a card,
//  or save a chosen outfit to Firestore.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class PromptResultsViewModel: ObservableObject {
    @Published var cards: [PCOutfitCandidate] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    let userId: String
    let prompt: String

    private let query: PromptQuery
    private let store = ManualSuggestionStore()
    private lazy var engine = OutfitEngine(userId: userId, query: query, store: store)

    init(userId: String, prompt: String) {
        self.userId = userId
        self.prompt = prompt
        self.query  = parsePrompt(prompt)
    }

    func loadInitial(count: Int = 2) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        cards.removeAll()
        for _ in 0..<count {
            if let c = await engine.generateCandidate() { cards.append(c) }
        }
        if cards.isEmpty {
            errorMessage = "Couldn't match your prompt yet. Try rephrasing or add more items."
        }
    }

    func skip(_ id: PCOutfitCandidate.ID) async {
        cards.removeAll { $0.id == id }
        if let c = await engine.generateCandidate() { cards.append(c) }
    }

    func saveOutfit(name: String,
                    occasion: String?,
                    description: String?,
                    date: Date?,
                    isFavorite: Bool,
                    items: [WardrobeItem]) async {

        let uid = Auth.auth().currentUser?.uid ?? userId
        guard !uid.isEmpty else {
            errorMessage = "Please sign in."
            return
        }

        do {
            let itemIDs = items.compactMap { $0.id }
            let urls = items.map { $0.imageURL }
            let payload: [String: Any] = [
                "name": name.isEmpty ? prompt : name,
                "description": description ?? "",
                "imageURL": urls.first ?? "",
                "itemImageURLs": urls,
                "itemIDs": itemIDs,
                "tags": [],
                "occasion": occasion ?? (query.occasion ?? ""),
                "wearCount": 0,
                "isFavorite": isFavorite,
                "source": "prompt",
                "createdAt": FieldValue.serverTimestamp(),
                "date": date != nil ? Timestamp(date: date!) : FieldValue.serverTimestamp()
            ]
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document()
                .setData(payload)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
