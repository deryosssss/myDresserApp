//
//  AppDelegate.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import UIKit
import FirebaseCore
import GoogleSignIn
import FBSDKCoreKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Called when app launches
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        logBuckets()
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions) // Facebook
        return true
    }
    
    // Called for Google/Facebook sign-in callback
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        // Google sign-in
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        // Facebook sign-in
        if ApplicationDelegate.shared.application(app, open: url, options: options) {
            return true
        }
        return false
    }
}
