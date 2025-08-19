//
//  AddItemWebView.swift
//  myFinalProject
//
//  Created by You on 31/07/2025.
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
    @StateObject private var webVM = WebViewCropperViewModel()
    @StateObject private var taggingVM = ImageTaggingViewModel()
    @StateObject private var removeBg = RemoveBgClient()

    /// The image that has been cropped from the web snapshot
    @State private var previewImage: PreviewImage?
    /// Controls presentation of the preview sheet
    @State private var showingPreview = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 1) Full-screen WebView for image search
            WebViewRepresentable(
                webView: webVM.webView,
                url: URL(string: "https://images.google.com")!
            )
            .edgesIgnoringSafeArea(.all)

            // 2) Snapshot button
            Button(action: webVM.captureSnapshot) {
                Image(systemName: "camera.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding()
            }
        }
        // 3) Fullscreen cropper
        .fullScreenCover(isPresented: $webVM.showingCrop) {
            if let img = webVM.capturedImage {
                CropImageView(image: img) { cropped in
                    webVM.showingCrop = false
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
        // 4) Preview sheet now uses PreviewImage (Identifiable)
        .sheet(item: $previewImage) { item in
            TaggedItemPreviewView(
                originalImage: item.ui,
                taggingVM: taggingVM,
                onDismiss: {
                    previewImage = nil
                }
            )
        }

        // 5) Overlay loading/errors
        .overlay(
            VStack {
                if taggingVM.isLoading {
                    ProgressView("Saving…")
                }
                if let error = taggingVM.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(),
            alignment: .top
        )
    }
}
