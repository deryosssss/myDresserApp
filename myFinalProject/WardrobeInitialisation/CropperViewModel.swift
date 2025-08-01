//
//  CropperViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI
import WebKit

// MARK: — VIEW MODEL

class WebViewCropperViewModel: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var showingCrop: Bool = false

    let webView: WKWebView = WKWebView()

    func captureSnapshot() {
        let config = WKSnapshotConfiguration()
        // if you need the full page, uncomment and set desired width:
        // config.snapshotWidth = NSNumber(value: Float(UIScreen.main.bounds.width * UIScreen.main.scale))

        webView.takeSnapshot(with: config) { [weak self] image, error in
            guard let self = self else { return }
            if let error = error {
                print("Snapshot error: \(error.localizedDescription)")
                return
            }
            guard let uiImage = image?.normalizedImage() else { return }

            DispatchQueue.main.async {
                self.capturedImage = uiImage
                self.showingCrop = true
            }
        }
    }
}

// MARK: — MAIN VIEW



// MARK: — WEB VIEW WRAPPER

struct WebViewRepresentable: UIViewRepresentable {
    let webView: WKWebView
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {}
}


// MARK: — UIImage ORIENTATION NORMALIZATION

extension UIImage {
    /// Returns an image that's .up orientation by redrawing into graphics context.
    func normalizedImage() -> UIImage {
        guard imageOrientation != .up else { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
