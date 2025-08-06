//
//  WardrobeFirestoreService.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import FirebaseFirestore
import FirebaseCore

class WardrobeFirestoreService: WardrobeDataService {
    private let collectionName = "wardrobeItems"

    private var db: Firestore {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Firestore.firestore()
    }

    // MARK: — Listen
    func listen(
        _ callback: @escaping (Result<[WardrobeItem], Error>) -> Void
    ) -> ListenerRegistration {
        return db
            .collection(collectionName)
            .order(by: "addedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let err = error {
                    callback(.failure(err))
                    return
                }
                guard let docs = snapshot?.documents else {
                    callback(.success([]))
                    return
                }
                do {
                    let items = try docs.compactMap { doc in
                        try doc.data(as: WardrobeItem.self)
                    }
                    callback(.success(items))
                } catch {
                    callback(.failure(error))
                }
            }
    }

    // MARK: — Save (New)
    func save(_ item: WardrobeItem, completion: @escaping (Result<Void, Error>) -> Void) {
        var data = item.dictionary
        // clear out server timestamps so Firestore can populate them
        data["addedAt"] = FieldValue.serverTimestamp()
        data["lastWorn"] = item.lastWorn != nil
            ? Timestamp(date: item.lastWorn!)
            : FieldValue.delete()
        db.collection(collectionName)
          .addDocument(data: data) { error in
            if let err = error {
                completion(.failure(err))
            } else {
                completion(.success(()))
            }
        }
    }

    // MARK: — Delete
    func deleteItem(_ id: String) {
        db.collection(collectionName).document(id).delete { error in
            if let err = error {
                print("❌ Error deleting item:", err)
            }
        }
    }

    // MARK: — Update
    func updateItem(_ id: String, data: [String: Any]) {
        db.collection(collectionName).document(id).updateData(data) { error in
            if let err = error {
                print("❌ Error updating item:", err)
            }
        }
    }
}

extension Encodable {
    var dictionary: [String:Any] {
        (try? JSONSerialization.jsonObject(
            with: JSONEncoder().encode(self),
            options: .allowFragments
        )) as? [String:Any] ?? [:]
    }
}
