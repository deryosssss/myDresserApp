//
//  CropperViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025
//
//  1) Hosts a simple ObservableObject (WebViewCropperViewModel) that snapshots a WKWebView and triggers a crop UI.
//  2) Wraps WKWebView for SwiftUI (WebViewRepresentable) to load a given URL inside SwiftUI views.
//  3) Normalizes UIImage orientation after snapshot so subsequent editing/cropping is consistent.
//

import SwiftUI
import WebKit

// MARK: — VIEW MODEL

class WebViewCropperViewModel: ObservableObject {
    @Published var capturedImage: UIImage?          // last snapshot of the web view
    @Published var showingCrop: Bool = false        // toggles the full-screen cropper

    let webView: WKWebView = WKWebView()            // owned WKWebView instance

    /// Captures a bitmap snapshot of the current webView contents and shows the cropper.
    func captureSnapshot() {
        let config = WKSnapshotConfiguration()
        // If you want a full-page snapshot, set snapshotWidth (in pixels) accordingly:
        // config.snapshotWidth = NSNumber(value: Float(UIScreen.main.bounds.width * UIScreen.main.scale))

        webView.takeSnapshot(with: config) { [weak self] image, error in
            guard let self = self else { return }
            if let error = error {
                print("Snapshot error: \(error.localizedDescription)")
                return
            }
            guard let uiImage = image?.normalizedImage() else { return } // ensure .up orientation

            DispatchQueue.main.async {
                self.capturedImage = uiImage
                self.showingCrop = true
            }
        }
    }
}

// MARK: — WEB VIEW WRAPPER (SwiftUI ↔︎ WKWebView)

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView                               // injected web view (owned by VM)
    let url: URL                                         // initial URL to load

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator // optional delegate (hooks/logging)
        webView.load(URLRequest(url: url))               // kick off initial load
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {} // no-op (state driven externally)

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {}        // placeholder for future needs
}

// MARK: — UIImage ORIENTATION NORMALIZATION

extension UIImage {
    /// Returns an image with .up orientation by redrawing into a graphics context (avoids rotated crops).
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
