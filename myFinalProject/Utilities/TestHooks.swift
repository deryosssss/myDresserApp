// TestHooks.swift (app target)
import UIKit
import FirebaseAuth
import FirebaseCore

enum TestHooks {
    static func handleLaunchArgs() {
        let args = ProcessInfo.processInfo.arguments

        // Use the local Auth emulator when running UI tests
        if args.contains("UI_TEST_MODE=1") {
            // Safe if called multiple times
            if FirebaseApp.app() == nil { FirebaseApp.configure() }
            Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
            try? Auth.auth().signOut()
        }

        // Allow tests to open app via deep link
        for arg in args where arg.hasPrefix("--deeplink=") {
            let raw = String(arg.dropFirst("--deeplink=".count))
            if let url = URL(string: raw) {
                DispatchQueue.main.async { UIApplication.shared.open(url) }
            }
        }
    }
}
