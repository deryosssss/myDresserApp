//
//  ImagePicker.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI
import Photos

// MARK: - ImagePicker (camera / photo library bridge)
/// A SwiftUI wrapper around `UIImagePickerController`.
/// Use it to let users pick an image from the camera or photo library and bind the result to SwiftUI state.
///
struct ImagePicker: UIViewControllerRepresentable {
    /// Where to source the image from: `.camera` or `.photoLibrary`.
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var image: UIImage?
    @Environment(\.presentationMode) private var presentation

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator
    /// Handles UINavigationController & UIImagePickerController delegate callbacks.
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentation.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentation.wrappedValue.dismiss()
        }
    }
}

