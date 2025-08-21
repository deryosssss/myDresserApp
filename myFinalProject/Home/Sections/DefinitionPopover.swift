//
//  DefinitionPopover.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

/// Lightweight, reusable info panel used as a sheet/popover body.
/// Shows a title + explanatory text. Kept dumb/presentational so
/// it can be dropped into any screen that needs a quick definition.
struct DefinitionPopover: View {
    // Immutable inputs drive the view; no internal state needed.
    let title: String
    let definition: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            Text(definition)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .presentationDetents([.medium, .large])
    }
}


