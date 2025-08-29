//
//  NotificationsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

// NotificationsView is a placeholder screen for the app’s notifications feature that will be later implemented 

struct NotificationsView: View {
    @State private var showComingSoon = false

    var body: some View {
        VStack {
            Text("My Notifications")
                .font(AppFont.spicyRice(size: 22))
                .foregroundColor(.black)
                .padding(.vertical, 8)
            
        }
        Spacer()
        .onAppear {
            // Small delay so it doesn't clash with navigation animations
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showComingSoon = true
            }
        }
        .alert("Coming soon", isPresented: $showComingSoon) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Notifications are coming soon.")
        }
    }
}
