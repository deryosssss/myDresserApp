//
//  ManualCreateSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

struct ManualCreateSheet: View {
    let userId: String
    let startPinned: WardrobeItem?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            #if canImport(SwiftUI)
            // Replace with your ManualSuggestionView if present in your module:
            ManualSuggestionView(userId: userId, startPinned: startPinned)
                .navigationTitle("Create outfit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
            #else
            Text("Manual creator")
            #endif
        }
    }
}

struct AIStylistSheet: View {
    let userId: String
    let initialPrompt: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PromptResultsView(userId: userId, initialPrompt: initialPrompt ?? "Create an outfit for today using my wardrobe.")
                .navigationTitle("AI Stylist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Back") { dismiss() }
                    }
                }
        }
    }
}
