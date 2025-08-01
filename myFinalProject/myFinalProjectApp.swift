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
    var body: some Scene {
        WindowGroup {
            MainTabView()

//            WelcomeView()
        }
    }
}
