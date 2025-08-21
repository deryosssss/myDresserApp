//
//  AppDelegate.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025
//
//  1) Boots Firebase and Facebook SDK when the app launches.
//  2) Handles URL callbacks for Google & Facebook sign-in flows.
//

import UIKit
import FirebaseCore
import GoogleSignIn
import FBSDKCoreKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // Called when app launches (initialize SDKs, do one-time setup)
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure() // Firebase (Auth/Firestore/Storage) setup
        logBuckets()           
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions) // Facebook SDK init
        return true
    }
    
    // Handle auth redirect URLs (Google / Facebook sign-in callbacks)
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) {            // Google Sign-In deep link
            return true
        }
        if ApplicationDelegate.shared.application(app, open: url, options: options) { // Facebook deep link
            return true
        }
        return false
    }
}
