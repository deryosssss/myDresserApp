//
//  WardrobeFirestoreService.swift
//  myFinalProject
//
//  Created by Derya Baglan on 01/08/2025.
//

import FirebaseFirestore
import FirebaseCore

class WardrobeFirestoreService {
    private let collectionName = "wardrobeItems"

    private var db: Firestore {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return Firestore.firestore()
    }

    // MARK: — Save

    /// Saves a full `WardrobeItem` into Firestore.
    /// The `addedAt` field will be populated server-side.
    func save(
        _ item: WardrobeItem,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            _ = try db
                .collection(collectionName)
                .addDocument(from: item) { error in
                    if let err = error {
                        completion(.failure(err))
                    } else {
                        completion(.success(()))
                    }
                }
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: — Listen

    /// Starts a real-time listener on the `wardrobeItems` collection,
    /// ordered by `addedAt` descending. Returns a `ListenerRegistration`
    /// so you can stop it when needed.
    func listen(
        onUpdate: @escaping (Result<[WardrobeItem], Error>) -> Void
    ) -> ListenerRegistration {
        return db
            .collection(collectionName)
            .order(by: "addedAt", descending: true)
            .addSnapshotListener { snapshot, error in
                if let err = error {
                    onUpdate(.failure(err))
                    return
                }
                guard let docs = snapshot?.documents else {
                    onUpdate(.success([]))
                    return
                }
                do {
                    let items = try docs.compactMap { doc in
                        try doc.data(as: WardrobeItem.self)
                    }
                    onUpdate(.success(items))
                } catch {
                    onUpdate(.failure(error))
                }
            }
    }
}
