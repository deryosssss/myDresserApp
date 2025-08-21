//
//  WardrobeSearchBar.swift
//  myFinalProject
//
//  Created by Derya Baglan on 21/08/2025.
//


import SwiftUI

struct WardrobeSearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}
