//
//  ImageTaggingViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class ImageTaggingViewModel: ObservableObject {
    // MARK: - Auto-tag results
    @Published var detectedItems: [ItemDetectionResponse.DetectedItem] = []
    @Published var deepTags: DeepTaggingResponse.DataWrapper? = nil

    // MARK: - UI state
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // MARK: - Editable metadata fields
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

    // NEW fields to persist
    @Published var isFavorite: Bool = false
    @Published var sourceType: WardrobeItem.SourceType = .gallery
    @Published var gender: String = ""

    private let client = LykdatClient()
    /// IMPORTANT: use normalized bucket everywhere
    private let storageRoot = StorageBucket.instance.reference()
    private let firestoreService = WardrobeFirestoreService()

    // MARK: - Helpers

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
        isFavorite = false
        sourceType = .gallery
        gender = ""
    }

    // MARK: - Auto-tagging (unchanged logic)

    func autoTag(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isLoading = true
        errorMessage = nil

        client.detectItems(imageData: data) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                switch result {
                case .success(let items):
                    self.detectedItems = items
                    if let first = items.first {
                        self.category    = first.name.capitalized
                        self.subcategory = first.category.capitalized
                    }
                case .failure:
                    break
                }

                self.client.deepTags(imageData: data) { deepResult in
                    Task { @MainActor in
                        self.isLoading = false
                        switch deepResult {
                        case .success(let tagData):
                            self.deepTags = tagData
                            self.colours = tagData.colors.map { $0.name.capitalized }
                            self.tags    = tagData.labels.map { $0.name.capitalized }

                            if let fashionItem = tagData.items.first {
                                self.category    = fashionItem.name.capitalized
                                self.subcategory = fashionItem.category.capitalized
                            }
                            if let lengthLab = tagData.labels.first(where: { $0.classification == "length" }) {
                                self.length = lengthLab.name.capitalized
                            }
                            if let pattern = tagData.labels.first(where: { $0.classification == "textile pattern" }) {
                                self.designPattern = pattern.name.capitalized
                            }
                            if let fitLab = tagData.labels.first(where: { $0.classification == "silhouette" && $0.name.contains("fit") }) {
                                self.fit = fitLab.name.capitalized
                            }
                            if let closureLab = tagData.labels.first(where: { $0.classification == "opening type" }) {
                                self.closureType = closureLab.name.capitalized
                            }
                        case .failure(let err):
                            self.errorMessage = err.localizedDescription
                        }
                    }
                }
            }
        }
    }

    // MARK: - Firebase Persistence

    /// Upload image to Storage, then save metadata to Firestore.
    func uploadAndSave(image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "Please sign in before uploading."
            return
        }

        // keep under 10 MB rule + use JPEG for smaller size
        let prepared = prepareImageData(image, maxBytes: 10 * 1024 * 1024)
        guard let imageData = prepared.data else {
            self.errorMessage = "Could not encode image."
            return
        }
        let contentType = prepared.contentType // "image/jpeg"

        // path MUST match storage.rules: /wardrobe_images/{uid}/{fileName}
        let fileName = UUID().uuidString + ".jpg"
        let path = "wardrobe_images/\(uid)/\(fileName)"
        let ref  = storageRoot.child(path)

        let meta = StorageMetadata()
        meta.contentType = contentType

        isLoading = true
        errorMessage = nil

        #if DEBUG
        print("[Upload] bucket=\(ref.bucket) path=\(path) bytes=\(imageData.count) ct=\(contentType)")
        #endif

        let task = ref.putData(imageData, metadata: meta)

        task.observe(.failure) { [weak self] snap in
            guard let self = self else { return }
            let nsErr = snap.error as NSError?
            let code  = StorageErrorCode(rawValue: nsErr?.code ?? -1)
            Task { @MainActor in
                self.isLoading = false
                self.errorMessage = "Upload failed (\(code?.rawValue ?? -1)): \(nsErr?.localizedDescription ?? "Unknown")"
            }
            #if DEBUG
            print("[Upload ❌] bucket=\(ref.bucket) path=\(path) code=\(String(describing: code)) err=\(String(describing: nsErr))")
            #endif
        }

        task.observe(.success) { [weak self] _ in
            guard let self = self else { return }
            #if DEBUG
            print("[Upload ✅] bucket=\(ref.bucket) path=\(path)")
            #endif

            func fetchURL(retry: Bool) {
                ref.downloadURL { url, err in
                    if let err = err as NSError? {
                        let code = StorageErrorCode(rawValue: err.code)
                        #if DEBUG
                        print("[URL ❌] code=\(String(describing: code)) err=\(err)")
                        #endif
                        if retry, code == .objectNotFound {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                fetchURL(retry: false)
                            }
                            return
                        }
                        Task { @MainActor in
                            self.isLoading = false
                            self.errorMessage = "URL retrieval failed: \(err.localizedDescription)"
                        }
                        return
                    }

                    guard let url = url else {
                        Task { @MainActor in
                            self.isLoading = false
                            self.errorMessage = "URL retrieval failed: empty URL."
                        }
                        return
                    }

                    Task { @MainActor in
                        self.saveToFirestore(imageURL: url.absoluteString, imagePath: path, userId: uid)
                    }
                }
            }
            fetchURL(retry: true)
        }
    }

    func debugUploadToProfile(image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid,
              let data = image.jpegData(compressionQuality: 0.8) else { return }

        let fileName = UUID().uuidString + ".jpg"
        let path = "profile_images/\(uid)/\(fileName)"
        let ref  = StorageBucket.instance.reference(withPath: path)
        let meta = StorageMetadata(); meta.contentType = "image/jpeg"

        print("[DBG profile upload] bucket=\(ref.bucket) path=\(path)")
        ref.putData(data, metadata: meta) { _, err in
            if let err = err { print("[DBG profile upload ❌]", err) }
            else { print("[DBG profile upload ✅]") }
        }
    }

    private func saveToFirestore(imageURL: String, imagePath: String, userId: String) {
        let item = WardrobeItem(
            id:            nil,
            userId:        userId,
            imageURL:      imageURL,
            imagePath:     imagePath,
            category:      category,
            subcategory:   subcategory,
            length:        length,
            style:         style,
            designPattern: designPattern,
            closureType:   closureType,
            fit:           fit,
            material:      material,
            fastening:     fastening.isEmpty ? nil : fastening,
            dressCode:     dressCode,
            season:        season,
            size:          size,
            colours:       colours,
            customTags:    tags,
            moodTags:      moodTags,
            isFavorite:    isFavorite,                 // NEW
            sourceType:    sourceType,                 // NEW
            gender:        gender,                     // NEW
            addedAt:       nil,
            lastWorn:      nil
        )

        isLoading = true
        firestoreService.save(item) { [weak self] (result: Result<Void, Error>) in
            guard let self = self else { return }
            Task { @MainActor in
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

// MARK: - Image sizing helpers
private func prepareImageData(_ image: UIImage, maxBytes: Int) -> (data: Data?, contentType: String) {
    // downscale to ~1600px max side and compress jpeg
    let targetMax: CGFloat = 1600
    let resized = resize(image, maxSide: targetMax)
    var q: CGFloat = 0.85
    var data = resized.jpegData(compressionQuality: q)

    while let d = data, d.count > maxBytes, q > 0.35 {
        q -= 0.1
        data = resized.jpegData(compressionQuality: q)
    }
    return (data, "image/jpeg")
}

private func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
    let size = image.size
    let m = max(size.width, size.height)
    guard m > maxSide else { return image }
    let scale = maxSide / m
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)
    UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
    image.draw(in: CGRect(origin: .zero, size: newSize))
    let new = UIGraphicsGetImageFromCurrentImageContext() ?? image
    UIGraphicsEndImageContext()
    return new
}
