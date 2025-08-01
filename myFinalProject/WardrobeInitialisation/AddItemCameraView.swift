
//
//  AddItemCameraView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//
//
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

    @State private var selectedTab: Tab = .library
    @State private var showingCamera = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photos: [UIImage] = []

    @State private var previewImage: PreviewImage?

    @StateObject private var taggingVM = ImageTaggingViewModel()

    private let gridColumns = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 3
    )

    // MARK: — Body

    var body: some View {
        VStack(spacing: 0) {
            // 1) Tab selector
            Picker("", selection: $selectedTab) {
                Text("Camera Roll").tag(Tab.library)
                Text("Web").tag(Tab.web)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()

            // 2) Content
            if selectedTab == .library {
                libraryGrid
            } else {
                AddItemWebView()
            }
        }
        // 3) Overlay tagging progress/errors
        .overlay(
            VStack {
                if taggingVM.isLoading { ProgressView("Tagging…") }
                if let err = taggingVM.errorMessage {
                    Text(err).foregroundColor(.red)
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
                onSave: {
                    // dismiss
                    previewImage = nil
                },
                onDelete: {
                    // remove exactly that image
                    if let idx = photos.firstIndex(where: { $0 === item.ui }) {
                        photos.remove(at: idx)
                    }
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
                .sheet(isPresented: $showingCamera) {
                    CameraImagePicker { image in
                        showingCamera = false
                        guard let img = image else { return }
                        photos.append(img)
                        previewImage = PreviewImage(ui: img)
                        taggingVM.autoTag(image: img)
                    }
                }

                // Photo library button
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: .max,
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
                .onChange(of: pickerItems) { newItems in
                    for item in newItems {
                        item.loadTransferable(type: Data.self) { result in
                            if case let .success(data?) = result,
                               let ui = UIImage(data: data) {
                                DispatchQueue.main.async {
                                    photos.append(ui)
                                    previewImage = PreviewImage(ui: ui)
                                    taggingVM.autoTag(image: ui)
                                }
                            }
                        }
                    }
                    pickerItems = []
                }

                // Thumbnails
                ForEach(photos.indices, id: \.self) { idx in
                    Image(uiImage: photos[idx])
                        .resizable()
                        .scaledToFill()
                        .frame(height: 100)
                        .clipped()
                        .cornerRadius(8)
                }
            }
            .padding(8)
        }
    }
}

// MARK: — CameraImagePicker

/// Wraps `UIImagePickerController` for camera capture.
struct CameraImagePicker: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate   = context.coordinator
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
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}




