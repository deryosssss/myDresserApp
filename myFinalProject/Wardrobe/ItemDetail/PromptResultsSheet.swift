//
//  PromptResultsSheet.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//
//


import SwiftUI

struct PromptResultsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let userId: String
    let initialPrompt: String

    var body: some View {
        NavigationStack {
            PromptResultsView(userId: userId, initialPrompt: initialPrompt)
                .navigationTitle("Your Outfit")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}

