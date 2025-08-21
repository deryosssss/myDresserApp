//
//  ProfileListButton.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
import SwiftUI

struct ProfileListButton: View {
    let icon: String
    let label: String
    var showDot: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(.black)
                .frame(width: 34)
            Text(label)
                .font(AppFont.agdasima(size: 24))
                .foregroundColor(.black)
            Spacer()
            if showDot {
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 15)
        .background(Color.gray.opacity(0.11))
    }
}

