//
//  StorageBucket.swift
//  myFinalProject
//
//  Created by Derya Baglan on 11/08/2025.
//

// StorageBucket.swift
import FirebaseStorage

enum StorageBucket {
    static var instance: Storage {
        // Use the default bucket configured from GoogleService-Info.plist
        Storage.storage()
    }
}

