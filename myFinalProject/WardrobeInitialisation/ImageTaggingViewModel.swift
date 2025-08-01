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
/// and exposes both the auto-tags **and** all editable fields via @Published.
class ImageTaggingViewModel: ObservableObject {
    // MARK: — Auto-tag results
    @Published var detectedItems: [ItemDetectionResponse.DetectedItem] = []
    @Published var deepTags: DeepTaggingResponse.DataWrapper? = nil

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: — Editable metadata fields
    @Published var category: String = ""
    @Published var subcategory: String = ""
    @Published var colours: [String] = []
    @Published var tags: [String] = []
    @Published var length: String = ""
    @Published var style: String = ""
    @Published var designPattern: String = ""
    @Published var closureType: String = ""
    @Published var fit: String = ""
    @Published var material: String = ""
    @Published var fastening: String = ""
    @Published var dressCode: String = ""
    @Published var season: String = ""
    @Published var size: String = ""
    @Published var moodTags: [String] = []

    private let client = LykdatClient()
    private let firestore = WardrobeFirestoreService()

    /// Sends the image off for both detection and deep tags.
    func autoTag(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            // never show a user‐visible error here
            return
        }
        isLoading = true
        errorMessage = nil

        client.detectItems(imageData: data) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.detectedItems = items
                    if let first = items.first {
                        self?.category = first.name.capitalized
                    }

                case .failure(let err):
                    let msg = err.localizedDescription
                    // swallow the “data couldn’t be read” picker error
                    if !msg.contains("couldn’t be read") {
                        self?.errorMessage = "Detection failed: \(msg)"
                    }
                }

                self?.client.deepTags(imageData: data) { deepResult in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        switch deepResult {
                        case .success(let tagData):
                            self?.deepTags = tagData
                            self?.colours = tagData.colors.map { $0.name.capitalized }
                            self?.tags    = tagData.labels.map { $0.name.capitalized }

                        case .failure(let err):
                            let msg = err.localizedDescription
                            // again, only show “real” errors
                            if !msg.contains("couldn’t be read") {
                                self?.errorMessage = "Tagging failed: \(msg)"
                            }
                        }
                    }
                }
            }
        }
    }

    /// Persists the last tagged results (including your edited fields) to Firestore.
    /// Expects you to have already uploaded the image and received its URL.
    func saveToFirestore(imageURL: String) {
        // Collect everything
        let itemNames  = detectedItems.map { $0.name }
        let colorNames = colours
        let labelNames = tags

        firestore.saveWardrobeItem(
            imageURL: imageURL,
            detectedItems: itemNames,
            colors: colorNames,
            labels: labelNames,
            // plus all your other fields if your service supports them…
        ) { error in
            if let err = error {
                print("❌ Firestore save error:", err.localizedDescription)
            } else {
                print("✅ Wardrobe item saved successfully")
            }
        }
    }
}

