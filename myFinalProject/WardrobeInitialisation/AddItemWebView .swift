//
//  AddItemWebView.swift
//  myFinalProject
//
//  Created by You on 31/07/2025.
//

import SwiftUI
import WebKit
import UIKit

struct AddItemWebView: View {
    @StateObject private var webVM = WebViewCropperViewModel()
    @StateObject private var taggingVM = ImageTaggingViewModel()
    @StateObject private var removeBg = RemoveBgClient()

    /// The image that has been cropped from the web snapshot
    @State private var previewImage: UIImage?
    /// Controls presentation of the preview sheet
    @State private var showingPreview = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // 1) Show a full-screen WebView for image search
            WebViewRepresentable(
                webView: webVM.webView,
                url: URL(string: "https://images.google.com")!
            )
            .edgesIgnoringSafeArea(.all)

            // 2) Snapshot button: grab a screenshot of the WebView
            Button(action: webVM.captureSnapshot) {
                Image(systemName: "camera.circle.fill")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .padding()
            }
        }
        // 3) When the snapshot is ready, show the cropper
        .fullScreenCover(isPresented: $webVM.showingCrop) {
            if let img = webVM.capturedImage {
                CropImageView(image: img) { cropped in
                    // a) dismiss cropper
                    webVM.showingCrop = false

                    // b) remove background
                    removeBg.removeBackground(from: cropped) { result in
                        DispatchQueue.main.async {
                            let finalImg: UIImage
                            switch result {
                            case .success(let cutout):
                                finalImg = cutout
                            case .failure:
                                // fallback to the cropped image
                                finalImg = cropped
                            }
                            // c) store for preview & auto-tag
                            previewImage = finalImg
                            taggingVM.autoTag(image: finalImg)
                            // d) show the tagging preview
                            showingPreview = true
                        }
                    }
                }
            }
        }
        // 4) After tagging completes, present the preview sheet
        .sheet(isPresented: $showingPreview) {
            if let img = previewImage {
                TaggedItemPreviewView(
                    originalImage: img,
                    taggingVM: taggingVM,
                    onSave: {
                        // handle save (e.g. upload, Firestore, etc.)
                        showingPreview = false
                    },
                    onDelete: {
                        // dismiss without saving
                        showingPreview = false
                    }
                )
            }
        }
        // 5) Overlay loading indicator or errors on top of the WebView
        .overlay(
            VStack {
                if taggingVM.isLoading {
                    ProgressView("Tagging…")
                }
                if let error = taggingVM.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
            , alignment: .top
        )
    }
}
