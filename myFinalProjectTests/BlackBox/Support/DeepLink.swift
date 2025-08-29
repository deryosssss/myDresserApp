//
//  DeepLink.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//
// DeepLink is a small test utility that lets XCUITests relaunch the app with a custom deep link. It terminates the current app instance, appends a --deeplink=... launch argument, and re-launches, so tests can jump straight into a specific screen or state via URL

import XCTest

enum DeepLink {
    static func relaunch(_ app: XCUIApplication, url: URL) {
        app.terminate()
        var args = app.launchArguments
        args.append("--deeplink=\(url.absoluteString)")
        app.launchArguments = args
        app.launch()
    }
}
