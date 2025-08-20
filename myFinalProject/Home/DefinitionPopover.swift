//
//  DefinitionPopover.swift
//  myFinalProject
//
//  Created by Derya Baglan on 20/08/2025.
//

import SwiftUI

struct DefinitionPopover: View {
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
