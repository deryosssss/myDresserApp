//
//  ImageTaggingViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025
//
//  1) Auto-tags an image (detect items + deep tags) and populates editable fields (category, colours, etc.).
//  2) Builds a stable colour name → hex map for consistent UI chips.
//  3) Uploads the image to Firebase Storage (≤10MB, downscaled JPEG) and saves a WardrobeItem to Firestore.
//
//

import SwiftUI
import UIKit
import FirebaseAuth
import FirebaseStorage
import FirebaseFirestore

@MainActor
final class ImageTaggingViewModel: ObservableObject {
    // MARK: - Auto-tag results
    @Published var detectedItems: [ItemDetectionResponse.DetectedItem] = []   // quick item detections
    @Published var deepTags: DeepTaggingResponse.DataWrapper? = nil           // rich labels/colors/items

    // MARK: - UI state
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    // MARK: - Editable metadata fields (bound to preview sheet)
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

    // color name → hex map (keys normalized for stable lookup)
    @Published var colorHexByName: [String: String] = [:]

    // Persisted extras
    @Published var isFavorite: Bool = false
    @Published var sourceType: WardrobeItem.SourceType = .gallery
    @Published var gender: String = ""

    private let client = LykdatClient()
    private let storageRoot = StorageBucket.instance.reference()
    private let firestoreService = WardrobeFirestoreService()

    private let isUITest = ProcessInfo.processInfo.arguments.contains("UI_TEST_MODE=1")

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
        colorHexByName.removeAll()
    }

    private func norm(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func buildColorMap(from colors: [DeepTaggingResponse.Color]) -> [String: String] {
        var out = colorHexByName
        for c in colors {
            let key = norm(c.name)
            let hex = c.hex_code.trimmingCharacters(in: .whitespacesAndNewlines)
                                  .replacingOccurrences(of: "#", with: "")
            if !key.isEmpty, hex.count == 6, Int(hex, radix: 16) != nil {
                out[key] = hex
            }
        }
        return out
    }

    // MARK: - Auto-tagging

    func autoTag(image: UIImage) {
        // 💡 Test mode: avoid all network, fill deterministic values for assertions.
        if isUITest {
            isLoading = true
            errorMessage = nil

            // stable, human-looking defaults
            self.category = "Top"
            self.subcategory = "T-Shirt"
            self.colours = ["Blue", "White"]
            self.tags = ["Casual", "Minimal"]
            self.length = "Regular"
            self.style = "Casual"
            self.designPattern = "Solid"
            self.closureType = ""
            self.fit = "Relaxed"
            self.material = "Cotton"
            self.dressCode = "Casual"
            self.season = "Summer"
            self.size = "M"
            self.moodTags = ["Happy"]

            // name→hex map used by colour chips
            self.colorHexByName = ["blue": "3B82F6", "white": "FFFFFF"]

            self.isLoading = false
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isLoading = true
        errorMessage = nil

        // 1) quick detection
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

                // 2) deep tags
                self.client.deepTags(imageData: data) { deepResult in
                    Task { @MainActor in
                        self.isLoading = false
                        switch deepResult {
                        case .success(let tagData):
                            self.deepTags = tagData

                            self.colours = tagData.colors.map { $0.name.capitalized }
                            self.tags    = tagData.labels.map { $0.name.capitalized }
                            self.colorHexByName = self.buildColorMap(from: tagData.colors)

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

    func uploadAndSave(image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "Please sign in before uploading."
            return
        }

        let prepared = prepareImageData(image, maxBytes: 10 * 1024 * 1024)
        guard let imageData = prepared.data else {
            self.errorMessage = "Could not encode image."
            return
        }
        let contentType = prepared.contentType

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
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { fetchURL(retry: false) }
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
            colorHexByName: colorHexByName,
            customTags:    tags,
            moodTags:      moodTags,
            isFavorite:    isFavorite,
            sourceType:    sourceType,
            gender:        gender,
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
                    print(" Wardrobe item saved")
                case .failure(let err):
                    self.errorMessage = "Save failed: \(err.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Image sizing helpers

private func prepareImageData(_ image: UIImage, maxBytes: Int) -> (data: Data?, contentType: String) {
    let targetMax: CGFloat = 1600
    let resized = resize(_image: image, maxSide: targetMax)
    var q: CGFloat = 0.85
    var data = resized.jpegData(compressionQuality: q)

    while let d = data, d.count > maxBytes, q > 0.35 {
        q -= 0.1
        data = resized.jpegData(compressionQuality: q)
    }
    return (data, "image/jpeg")
}

private func resize(_image image: UIImage, maxSide: CGFloat) -> UIImage {
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
