//
//  DeepLink.swift
//  myFinalProject
//
//  Created by Derya Baglan on 24/08/2025.
//

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
