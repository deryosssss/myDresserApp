//
//  UserProfile.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
//

import Foundation
import FirebaseFirestore

struct UserProfile: Equatable {
    var firstName: String
    var lastName: String
    var username: String
    var location: String
    var genderPresentation: String
    var photoURL: String?
    var createdAt: Date?
    var updatedAt: Date?

    init(firstName: String = "",
         lastName: String = "",
         username: String = "",
         location: String = "",
         genderPresentation: String = "",
         photoURL: String? = nil,
         createdAt: Date? = nil,
         updatedAt: Date? = nil) {
        self.firstName = firstName
        self.lastName = lastName
        self.username = username
        self.location = location
        self.genderPresentation = genderPresentation
        self.photoURL = photoURL
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init?(dict: [String: Any]) {
        self.firstName = dict["firstName"] as? String ?? ""
        self.lastName  = dict["lastName"]  as? String ?? ""
        self.username  = dict["username"]  as? String ?? ""
        self.location  = dict["location"]  as? String ?? ""
        self.genderPresentation = dict["genderPresentation"] as? String ?? ""
        self.photoURL  = dict["photoURL"] as? String

        if let ts = dict["createdAt"] as? Timestamp { self.createdAt = ts.dateValue() }
        if let ts = dict["updatedAt"] as? Timestamp { self.updatedAt = ts.dateValue() }
    }

    func toDict(includeCreatedIfMissing: Bool = true) -> [String: Any] {
        var d: [String: Any] = [
            "firstName": firstName,
            "lastName": lastName,
            "username": username,
            "location": location,
            "genderPresentation": genderPresentation,
            "photoURL": photoURL as Any,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if includeCreatedIfMissing && createdAt == nil {
            d["createdAt"] = FieldValue.serverTimestamp()
        }
        return d
    }
}
