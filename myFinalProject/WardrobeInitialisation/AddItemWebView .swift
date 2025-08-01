//
//  AddItemWebView.swift
//  myFinalProject
//
//  Created by You on 31/07/2025.
//
//

import SwiftUI
import WebKit

struct AddItemWebView: View {
  @StateObject private var webVM = WebViewCropperViewModel()
  @StateObject private var taggingVM = ImageTaggingViewModel()

  @State private var previewImage: UIImage?
  @State private var showingPreview = false

  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      WebViewRepresentable(
        webView: webVM.webView,
        url: URL(string:"https://images.google.com")!
      )
      .edgesIgnoringSafeArea(.all)

      Button(action: webVM.captureSnapshot) {
        Image(systemName:"camera.circle.fill")
          .resizable().frame(width:60,height:60).padding()
      }
    }
    .fullScreenCover(isPresented: $webVM.showingCrop) {
      if let img = webVM.capturedImage {
        CropImageView(image: img) { cropped in
          webVM.showingCrop = false
          previewImage = cropped
          taggingVM.autoTag(image: cropped)
          showingPreview = true
        }
      }
    }
    .sheet(isPresented: $showingPreview) {
      if let img = previewImage {
        TaggedItemPreviewView(
          originalImage: img,
          taggingVM: taggingVM,
          onSave:   { showingPreview = false },
          onDelete: { showingPreview = false }
        )
      }
    }
    .overlay(
      VStack {
        if taggingVM.isLoading { ProgressView("Tagging…") }
        if let e = taggingVM.errorMessage {
          Text(e).foregroundColor(.red)
        }
      }
      .padding(), alignment: .top
    )
  }
}
