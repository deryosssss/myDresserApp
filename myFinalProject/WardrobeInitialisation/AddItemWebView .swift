// AddItemWebView.swift
// myFinalProject
//
//  Created by Derya on 31/07/2025
//
//  1) Embeds a web browser (images.google.com) and lets you snapshot the page.
//  2) Opens a full-screen cropper → optional background removal → auto-tag the result.
//  3) Shows a preview sheet to confirm/save the cropped image as a wardrobe item.
//

import SwiftUI
import WebKit
import UIKit

/// A tiny wrapper so we can drive `.sheet(item:)` with a UIImage.
private struct PreviewImage: Identifiable {
    let id = UUID()
    let ui: UIImage
}

struct AddItemWebView: View {
    @StateObject private var webVM = WebViewCropperViewModel()   // manages WKWebView + snapshot + crop state
    @StateObject private var taggingVM = ImageTaggingViewModel() // runs auto-tagging + save flow
    @StateObject private var removeBg = RemoveBgClient()         // background removal service

    /// The image that has been cropped from the web snapshot
    @State private var previewImage: PreviewImage?               // drives preview sheet
    /// Controls presentation of the preview sheet
    @State private var showingPreview = false                    // (kept for flow clarity; sheet uses previewImage)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 1) Full-screen WebView for image search
            WebViewRepresentable(
                webView: webVM.webView,
                url: URL(string: "https://images.google.com")!
            )
            .edgesIgnoringSafeArea(.all)
            .aid("web.view")

            // 2) Snapshot button (captures current web view to an image)
            Button(action: webVM.captureSnapshot) {
                Image(systemName: "camera.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding()
            }
            .aid("web.capture")
        }
        // 3) Fullscreen cropper appears after snapshot
        .fullScreenCover(isPresented: $webVM.showingCrop) {
            if let img = webVM.capturedImage {
                CropImageView(image: img) { cropped in
                    webVM.showingCrop = false
                    // Remove background, then prepare preview + auto-tag
                    removeBg.removeBackground(from: cropped) { result in
                        DispatchQueue.main.async {
                            let finalImg: UIImage
                            switch result {
                            case .success(let cutout): finalImg = cutout
                            case .failure: finalImg = cropped
                            }
                            // set previewImage and auto-tag
                            previewImage = PreviewImage(ui: finalImg)
                            taggingVM.autoTag(image: finalImg)
                            showingPreview = true
                        }
                    }
                }
            }
        }
        // 4) Preview sheet driven by PreviewImage (Identifiable)
        .sheet(item: $previewImage) { item in
            TaggedItemPreviewView(
                originalImage: item.ui,
                taggingVM: taggingVM,
                onDismiss: {
                    previewImage = nil
                }
            )
        }

        // 5) Overlay loading/errors for tagging flow
        .overlay(
            VStack {
                if taggingVM.isLoading {
                    ProgressView("Saving…").aid("tagging.loading")
                }
                if let error = taggingVM.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .aid("tagging.error")
                }
            }
            .padding(),
            alignment: .top
        )
    }
}
