//
//  ImagePicker.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI
import Photos   // (Imported for photo permissions context; not directly used here)

// MARK: - ImagePicker (camera / photo library bridge)

/// A minimal SwiftUI wrapper around `UIImagePickerController`.
/// Why this exists:
/// - SwiftUI doesn’t provide a native camera/library picker prior to PhotosUI.
/// - `UIViewControllerRepresentable` lets us host UIKit pickers and bind results into SwiftUI state.
///
struct ImagePicker: UIViewControllerRepresentable {

    /// Source for the media picker: `.camera` or `.photoLibrary`.
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    /// The selected image is written here and can be consumed by the SwiftUI view tree.
    @Binding var image: UIImage?

    /// Used to dismiss the presented picker from within the coordinator callbacks.
    @Environment(\.presentationMode) private var presentation

    // MARK: UIViewControllerRepresentable

    /// Create and configure the UIKit picker.
    /// We set `delegate` to the coordinator so we can forward selection/cancel events into SwiftUI.
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }

    /// No incremental SwiftUI-to-UIKit updates required for this simple wrapper.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Bridge object that conforms to the UIKit delegate protocols and talks back to SwiftUI.
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator
    /// Handles `UINavigationControllerDelegate` & `UIImagePickerControllerDelegate` callbacks.
    /// Why we need it:
    /// - UIKit delegates are NSObject-based; SwiftUI provides the Coordinator pattern to translate those
    ///   callbacks into state changes (e.g., assign to `@Binding image`, dismiss the sheet).
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        /// Called when the user picks a media item.
        /// We read `.originalImage` (full-resolution) and write it into the bound `image`.
        /// Then we dismiss the picker.
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentation.wrappedValue.dismiss()
        }

        /// Called when the user cancels; just dismiss the sheet.
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentation.wrappedValue.dismiss()
        }
    }
}
