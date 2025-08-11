//
//  WardrobeFirestoreService.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//


import Foundation
import FirebaseAuth
import FirebaseFirestore

private enum WardrobeServiceError: Error { case notSignedIn }

/// No-op listener so we can return something when not signed in.
/// Must inherit from NSObject because ListenerRegistration is @objc.
private final class NoopListener: NSObject, ListenerRegistration {
    func remove() {}
}

final class WardrobeFirestoreService: WardrobeDataService {
    private let db = Firestore.firestore()

    // users/{uid}/items
    private func userItemsCollection() throws -> CollectionReference {
        guard let uid = Auth.auth().currentUser?.uid else { throw WardrobeServiceError.notSignedIn }
        return db.collection("users").document(uid).collection("items")
    }

    private func map(_ data: [String: Any], docId: String) -> WardrobeItem {
        let sourceStr = (data["sourceType"] as? String)?.lowercased() ?? WardrobeItem.SourceType.gallery.rawValue
        let src = WardrobeItem.SourceType(rawValue: sourceStr) ?? .gallery

        return WardrobeItem(
            id: data["id"] as? String ?? docId,
            userId: data["userId"] as? String ?? "",
            imageURL: data["imageURL"] as? String ?? "",
            imagePath: data["imagePath"] as? String,
            category: data["category"] as? String ?? "",
            subcategory: data["subcategory"] as? String ?? "",
            length: data["length"] as? String ?? "",
            style: data["style"] as? String ?? "",
            designPattern: data["designPattern"] as? String ?? "",
            closureType: data["closureType"] as? String ?? "",
            fit: data["fit"] as? String ?? "",
            material: data["material"] as? String ?? "",
            fastening: data["fastening"] as? String,
            dressCode: data["dressCode"] as? String ?? "",
            season: data["season"] as? String ?? "",
            size: data["size"] as? String ?? "",
            colours: data["colours"] as? [String] ?? [],
            customTags: data["customTags"] as? [String] ?? [],
            moodTags: data["moodTags"] as? [String] ?? [],
            isFavorite: data["isFavorite"] as? Bool ?? false,     // NEW
            sourceType: src,                                       // NEW
            gender: data["gender"] as? String ?? "",               // NEW
            addedAt: (data["addedAt"] as? Timestamp)?.dateValue(),
            lastWorn: (data["lastWorn"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - WardrobeDataService

    func listen(_ callback: @escaping (Result<[WardrobeItem], Error>) -> Void) -> ListenerRegistration {
        guard let uid = Auth.auth().currentUser?.uid else {
            callback(.success([]))
            return NoopListener()
        }
        let q = db.collection("users")
            .document(uid)
            .collection("items")
            .order(by: "addedAt", descending: true)

        return q.addSnapshotListener { snapshot, error in
            if let error = error {
                callback(.failure(error)); return
            }
            let items = snapshot?.documents.map { self.map($0.data(), docId: $0.documentID) } ?? []
            callback(.success(items))
        }
    }

    func save(_ item: WardrobeItem, completion: @escaping (Result<Void, Error>) -> Void) {
        do {
            let col = try userItemsCollection()
            let ref = col.document()
            var data = item.toFirestoreData()
            data["id"] = ref.documentID
            data["userId"] = Auth.auth().currentUser?.uid ?? ""
            ref.setData(data) { error in
                error == nil ? completion(.success(())) : completion(.failure(error!))
            }
        } catch {
            completion(.failure(error))
        }
    }

    func deleteItem(_ id: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("items").document(id).delete()
    }

    func updateItem(_ id: String, data: [String: Any]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).collection("items").document(id).updateData(data)
    }

    func fetchMine(completion: @escaping (Result<[WardrobeItem], Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.success([])); return
        }
        db.collection("users")
            .document(uid)
            .collection("items")
            .order(by: "addedAt", descending: true)
            .getDocuments { snap, err in
                if let err = err { completion(.failure(err)); return }
                let items = snap?.documents.map { self.map($0.data(), docId: $0.documentID) } ?? []
                completion(.success(items))
            }
    }
}

