//
//  ContinueButton.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

struct ContinueButton: View {
    let title: String
    let enabled: Bool
    let action: () -> Void
    var backgroundColor: Color = .white

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.agdasima(size: 20))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(enabled ? backgroundColor : backgroundColor.opacity(0.8))
                .cornerRadius(6)
        }
        .disabled(!enabled)
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
}
