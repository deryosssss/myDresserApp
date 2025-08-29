// AddItemCameraView.swift
// myFinalProject
//
//  Created by Derya Baglan on 31/07/2025
//
//  1) Lets you add wardrobe items from Camera Roll or the Web (segmented tabs).
//  2) From the library: capture via camera or pick photos; auto-remove background and auto-tag.
//  3) Shows a preview sheet per picked image to confirm/save; progress/error overlay while tagging.
//

import SwiftUI
import PhotosUI
import UIKit

/// A tiny wrapper so we can drive a SwiftUI `.sheet(item:)` with a UIImage.
private struct PreviewImage: Identifiable {
    let id = UUID()
    let ui: UIImage
}

struct AddItemCameraView: View {
    enum Tab { case library, web }

    // MARK: — State

    @State private var selectedTab: Tab = .library                  // which tab is active
    @State private var showingCamera = false                        // camera modal visibility
    @State private var pickerItems: [PhotosPickerItem] = []         // selected photo library items
    @State private var photos: [UIImage] = []                       // thumbnails currently shown

    @State private var previewImage: PreviewImage?                  // drives preview sheet

    @StateObject private var taggingVM = ImageTaggingViewModel()    // auto-tagging pipeline
    @StateObject private var removeBg = RemoveBgClient()            // background removal service

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    ) // 3-up grid for camera/library buttons + thumbnails

    // MARK: — Body

    var body: some View {
        VStack(spacing: 0) {
            Text("Add items")
              .font(AppFont.spicyRice(size: 28))
              .padding(.top)
              .padding(.bottom)
              .frame(maxWidth: .infinity)
              .aid("add.title")
            
            // 1) Tab selector
            Picker("", selection: $selectedTab) {
                Text("Camera Roll").tag(Tab.library)
                Text("Web").tag(Tab.web)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .aid("add.tabs")

            Divider()

            // 2) Content
            if selectedTab == .library {
                libraryGrid                                         // camera + picker + thumbnails
            } else {
                AddItemWebView()                                    // separate web-scrape/import flow
                    .aid("add.webTab")
            }
        }
        // 3) Overlay tagging progress/errors
        .overlay(
            VStack {
                if taggingVM.isLoading { ProgressView("Saving…").aid("tagging.loading") }  // simple progress banner
                if let err = taggingVM.errorMessage {
                    Text(err).foregroundColor(.red).aid("tagging.error")                    // show tagging error (if any)
                }
            }
            .padding(),
            alignment: .top
        )
        // 4) Preview sheet driven by previewImage
        .sheet(item: $previewImage) { item in
            TaggedItemPreviewView(
                originalImage: item.ui,
                taggingVM: taggingVM,
                onDismiss: {
                    // both save & delete now just dismiss (remove this image from thumbnails)
                    photos.removeAll { $0 === item.ui }             // UIImage is a class → identity compare
                    previewImage = nil
                }
            )
        }
    }

    // MARK: — Library Grid

    private var libraryGrid: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 8) {
                // Camera button
                Button { showingCamera = true } label: {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "camera")
                            .font(.system(size: 30))
                            .foregroundColor(.black)
                    }
                    .frame(height: 150)
                    .cornerRadius(8)
                }
                .aid("add.camera")
                .sheet(isPresented: $showingCamera) {
                    // UIKit camera wrapper; returns a UIImage or nil
                    CameraImagePicker { image in
                        showingCamera = false
                        guard let img = image else { return }
                        processPickedImage(img)                      // remove bg + auto-tag + open preview
                    }
                }

                // Photo library button
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: .max,                        // allow multi-select
                    matching: .images
                ) {
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 30))
                            .foregroundColor(.black)
                    }
                    .frame(height: 150)
                    .cornerRadius(8)
                }
                .aid("add.library")
                .onChange(of: pickerItems) { newItems in
                    // Load each selected item as Data → UIImage, then process
                    for item in newItems {
                        item.loadTransferable(type: Data.self) { result in
                            if case let .success(data?) = result,
                               let ui = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    processPickedImage(ui)
                                }
                            }
                        }
                    }
                    pickerItems = []                                 // clear selection to allow re-pick
                }

                // Thumbnails
                ForEach(photos.indices, id: \.self) { idx in
                    Image(uiImage: photos[idx])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(8)
                        .aid("add.thumb.\(idx)")
                }
            }
            .padding(8)
        }
        .aid("add.libraryGrid")
    }

    // MARK: — Helpers

    private func processPickedImage(_ img: UIImage) {
        // 1) Strip background (async); fall back to original if it fails
        removeBg.removeBackground(from: img) { result in
            DispatchQueue.main.async {
                let finalImage: UIImage
                switch result {
                case .success(let cutout):
                    finalImage = cutout
                case .failure:
                    finalImage = img
                }

                // 2) Show thumbnail + open preview + kick off auto-tagging
                photos.append(finalImage)
                previewImage = PreviewImage(ui: finalImage)
                taggingVM.autoTag(image: finalImage)
            }
        }
    }
}

// MARK: — CameraImagePicker

/// Wraps `UIImagePickerController` for camera capture.
struct CameraImagePicker: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void                           // callback with captured image (or nil)

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraImagePicker
        init(_ parent: CameraImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage          // grab original image
            parent.completion(image)                              // forward to SwiftUI
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)                                // user cancelled
            picker.dismiss(animated: true)
        }
    }
}
