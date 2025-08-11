//
//  myFinalProjectApp.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//


import SwiftUI
import FirebaseCore
import Firebase

@main
struct myFinalProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var authVM = AuthViewModel()
    @StateObject private var taggingVM = ImageTaggingViewModel() // your existing VM

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authVM)
                // If any screens need taggingVM, add .environmentObject(taggingVM) too
        }
    }
}
