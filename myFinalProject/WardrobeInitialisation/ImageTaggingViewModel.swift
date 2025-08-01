//
//  ImageTaggingViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import SwiftUI
import UIKit
import FirebaseFirestore

/// View-model that sends images to Lykdat for both item detection and deep tagging,
/// and exposes the results via @Published properties.
class ImageTaggingViewModel: ObservableObject {
    /// Raw item detections from Lykdat (nouns like “dress”, “shirt”, etc.)
    @Published var detectedItems: [ItemDetectionResponse.DetectedItem] = []
    /// Deep-tag results: colors, extra labels, etc.
    @Published var deepTags: DeepTaggingResponse.DataWrapper? = nil
    /// Whether a request is in flight
    @Published var isLoading: Bool = false
    /// Any error message to show the user
    @Published var errorMessage: String? = nil

    private let client = LykdatClient()
    private let firestore = WardrobeFirestoreService()

    /// Sends the image off for both detection and deep tags.
    func autoTag(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            self.errorMessage = "❌ Could not encode image"
            return
        }
        isLoading = true
        errorMessage = nil

        // First: detect items
        client.detectItems(imageData: data) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.detectedItems = items
                case .failure(let err):
                    self?.errorMessage = "Detection failed: \(err.localizedDescription)"
                }

                // Then: deep tagging
                self?.client.deepTags(imageData: data) { deepResult in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        switch deepResult {
                        case .success(let tagData):
                            self?.deepTags = tagData
                        case .failure(let err):
                            self?.errorMessage = "Tagging failed: \(err.localizedDescription)"
                        }
                    }
                }
            }
        }
    }

    /// Persists the last tagged results to Firestore under a wardrobe item.
    /// Expects you to have already uploaded the image and received its URL.
    func saveToFirestore(imageURL: String) {
        guard let deep = deepTags else { return }

        let itemNames  = detectedItems.map { $0.name }
        let colorNames = deep.colors.map   { $0.name }
        let labels     = deep.labels.map   { $0.name }

        firestore.saveWardrobeItem(
            imageURL: imageURL,
            detectedItems: itemNames,
            colors: colorNames,
            labels: labels
        ) { error in
            if let err = error {
                print("❌ Firestore save error:", err.localizedDescription)
            } else {
                print("✅ Wardrobe item saved successfully")
            }
        }
    }
}
