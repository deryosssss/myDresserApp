//
//  WardrobeStore.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025
//
//  1) Provides a small service to create a wardrobe item by uploading an image to Storage,
//     then writing the item document under users/{uid}/items/{itemId} in Firestore.
//  2) Supports full deletion: removes the Firestore doc and (best-effort) deletes the image blob.
//  3) Internally uploads with a 10MB cap by downscaling/compressing to JPEG (~1600px max side) if needed.
//

import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

struct UploadedImage {
    let itemId: String
    let path: String
    let url:  String
}

enum WardrobeStoreError: Error { case notSignedIn }

final class WardrobeStore {
    private let db = Firestore.firestore()

    /// Upload image to Storage and create item doc under users/{uid}/items/{itemId}
    func createItemWithImage(
        base: WardrobeItem,
        imageData: Data,
        fileExtension: String = "jpg",
        contentType: String = "image/jpeg"
    ) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else { throw WardrobeStoreError.notSignedIn } // must be signed in
        let itemId = UUID().uuidString                                                                // client id for doc + blob

        // 1) Upload the image and get public URL + storage path
        let uploaded = try await uploadImageForItem(
            uid: uid, itemId: itemId, data: imageData,
            fileExtension: fileExtension, contentType: contentType
        )

        // 2) Create Firestore document with imageURL/path wired in
        let col = db.collection("users").document(uid).collection("items")
        var data = base.toFirestoreData()
        data["id"] = itemId
        data["userId"] = uid
        data["imageURL"] = uploaded.url
        data["imagePath"] = uploaded.path

        try await col.document(itemId).setData(data)                                                 // write document
        return itemId
    }

    /// Best-effort delete of Firestore doc + its Storage blob.
    func deleteItemCompletely(itemId: String, imagePath: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw WardrobeStoreError.notSignedIn }   // require auth
        let doc = db.collection("users").document(uid).collection("items").document(itemId)
        try await doc.delete()                                                                        // delete doc first
        if let p = imagePath {
            try? await StorageBucket.instance.reference(withPath: p).delete()                         // ignore blob failure
        }
    }

    // MARK: - internals

    private func uploadImageForItem(
        uid: String,
        itemId: String,
        data: Data,
        fileExtension: String,
        contentType: String
    ) async throws -> UploadedImage {
        // Ensure we never exceed the 10MB rule; downscale/compress if needed.
        var contentType = contentType                                                                 // may be changed to image/jpeg
        let maxBytes = 10 * 1024 * 1024
        let preparedData = ensureUnderLimit(data, preferredContentType: &contentType, maxBytes: maxBytes)

        let path = "wardrobe_images/\(uid)/\(itemId).\(fileExtension)"                                // deterministic path
        let ref = StorageBucket.instance.reference(withPath: path)

        #if DEBUG
        print("[WardrobeStore] Uploading to:", ref.bucket, path)
        print("[WardrobeStore] Bytes:", preparedData.count, "Content-Type:", contentType)
        #endif

        // Set content type metadata for proper serving
        let meta = StorageMetadata()
        meta.contentType = contentType

        // Upload bytes (async bridge over callback API)
        _ = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<StorageMetadata, Error>) in
            ref.putData(preparedData, metadata: meta) { metadata, err in
                if let err = err { cont.resume(throwing: err) }
                else { cont.resume(returning: metadata ?? StorageMetadata()) }
            }
        }

        // Retrieve a public download URL
        let url = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            ref.downloadURL { url, err in
                if let err = err { cont.resume(throwing: err) }
                else { cont.resume(returning: url!) }
            }
        }

        return UploadedImage(itemId: itemId, path: path, url: url.absoluteString)
    }

    /// Try to keep image under size limit while staying an image/*.
    private func ensureUnderLimit(_ data: Data, preferredContentType: inout String, maxBytes: Int) -> Data {
        // If already small enough, keep as-is.
        if data.count <= maxBytes { return data }

        // Decode to UIImage; if that fails, return original (Storage will reject oversize).
        guard let img = UIImage(data: data) else { return data }

        // Downscale to ~1600px max side and compress to JPEG; reduce quality until under limit.
        let targetMax: CGFloat = 1600
        let resized = resize(img, maxSide: targetMax)

        var q: CGFloat = 0.8
        var out = resized.jpegData(compressionQuality: q) ?? data
        preferredContentType = "image/jpeg"
        while out.count > maxBytes, q > 0.35 {
            q -= 0.1
            if let d = resized.jpegData(compressionQuality: q) { out = d } else { break }
        }
        return out
    }

    private func resize(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let m = max(size.width, size.height)
        guard m > maxSide else { return image }                                                      // no-op if already small
        let scale = maxSide / m
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let new = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return new
    }
}
