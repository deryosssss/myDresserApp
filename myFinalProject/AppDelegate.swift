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
import FirebaseAuth
import GoogleSignIn
import FBSDKCoreKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)

        TestHooks.handleLaunchArgs()

        return true
    }

    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) { return true }
        if ApplicationDelegate.shared.application(app, open: url, options: options) { return true }
        return false
    }
}
