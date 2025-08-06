//
//  ImageTaggingViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//


import SwiftUI
import UIKit
import FirebaseStorage
import FirebaseFirestore

class ImageTaggingViewModel: ObservableObject {
    // MARK: — Auto-tag results
    @Published var detectedItems: [ItemDetectionResponse.DetectedItem] = []
    @Published var deepTags: DeepTaggingResponse.DataWrapper? = nil
    
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // MARK: — Editable metadata fields
    @Published var category = ""
    @Published var subcategory = ""
    @Published var colours: [String] = []
    @Published var tags: [String] = []
    @Published var length = ""
    @Published var style = ""
    @Published var designPattern = ""
    @Published var closureType = ""
    @Published var fit = ""
    @Published var material = ""
    @Published var fastening = ""
    @Published var dressCode = ""
    @Published var season = ""
    @Published var size = ""
    @Published var moodTags: [String] = []
    
    private let client = LykdatClient()
    private let storage = Storage.storage().reference()
    private let firestoreService = WardrobeFirestoreService()
    
    // MARK: — Helpers
    
    /// Clears every field (called on delete)
    func clearAll() {
        detectedItems.removeAll()
        deepTags = nil
        category = ""
        subcategory = ""
        colours.removeAll()
        tags.removeAll()
        length = ""
        style = ""
        designPattern = ""
        closureType = ""
        fit = ""
        material = ""
        fastening = ""
        dressCode = ""
        season = ""
        size = ""
        moodTags.removeAll()
    }
    
    // MARK: — Auto-tagging
    
    /// Sends the image off for both detection and deep tags,
    /// then seeds your editable fields.
    func autoTag(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isLoading = true
        errorMessage = nil
        
        client.detectItems(imageData: data) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let items):
                    self?.detectedItems = items
                    if let first = items.first {
                        self?.category    = first.name.capitalized
                        self?.subcategory = first.category.capitalized
                    }
                case .failure:
                    break
                }
                
                self?.client.deepTags(imageData: data) { deepResult in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        switch deepResult {
                        case .success(let tagData):
                            self?.deepTags = tagData
                            self?.colours = tagData.colors.map { $0.name.capitalized }
                            self?.tags    = tagData.labels.map { $0.name.capitalized }
                            
                            if let fashionItem = tagData.items.first {
                                self?.category    = fashionItem.name.capitalized
                                self?.subcategory = fashionItem.category.capitalized
                            }
                            if let lengthLab = tagData.labels.first(where: { $0.classification == "length" }) {
                                self?.length = lengthLab.name.capitalized
                            }
                            if let pattern = tagData.labels.first(where: { $0.classification == "textile pattern" }) {
                                self?.designPattern = pattern.name.capitalized
                            }
                            if let fitLab = tagData.labels.first(where: { $0.classification == "silhouette" && $0.name.contains("fit") }) {
                                self?.fit = fitLab.name.capitalized
                            }
                            if let closureLab = tagData.labels.first(where: { $0.classification == "opening type" }) {
                                self?.closureType = closureLab.name.capitalized
                            }
                        case .failure(let err):
                            self?.errorMessage = err.localizedDescription
                        }
                    }
                }
            }
        }
    }
    
    // MARK: — Firebase Persistence
    
    /// Uploads the image to Storage, then saves all fields + URL to Firestore via your service
    func uploadAndSave(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        let path = "wardrobe/\(UUID().uuidString).jpg"
        let ref  = storage.child(path)
        
        isLoading = true
        ref.putData(data, metadata: nil) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                self.isLoading = false
                self.errorMessage = "Upload failed: \(error.localizedDescription)"
                return
            }
            ref.downloadURL { url, error in
                self.isLoading = false
                if let url = url {
                    self.saveToFirestore(imageURL: url.absoluteString)
                } else if let err = error {
                    self.errorMessage = "URL retrieval failed: \(err.localizedDescription)"
                }
            }
        }
    }
    
    /// Constructs a `WardrobeItem` and calls the service to save it.
    private func saveToFirestore(imageURL: String) {
        // include `id: nil` (first parameter) and put your tag arrays
        // in the same order as your struct declaration
        let item = WardrobeItem(
            id:           nil,
            imageURL:     imageURL,
            category:     category,
            subcategory:  subcategory,
            length:       length,
            style:        style,
            designPattern: designPattern,
            closureType:  closureType,
            fit:          fit,
            material:     material,
            fastening:    fastening.isEmpty ? nil : fastening,
            dressCode:    dressCode,
            season:       season,
            size:         size,
            colours:      colours,
            customTags:   tags,
            moodTags:     moodTags,
            addedAt:      nil
        )
        
        isLoading = true
        // annotate the closure parameter so Swift knows its type
        firestoreService.save(item) { [weak self] (result: Result<Void, Error>) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success:
                    print("✅ Wardrobe item saved")
                case .failure(let err):
                    self.errorMessage = "Save failed: \(err.localizedDescription)"
                }
            }
        }
    }
}




