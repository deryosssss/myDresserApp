//
//  AccountDetailsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025
//
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class AccountDetailsViewModel: ObservableObject {
  // profile fields bound to text inputs
  @Published var firstName = ""
  @Published var lastName = ""
  @Published var username = ""
  @Published var location = ""
  @Published var genderPresentation = ""

  // avatar state
  @Published var profileImage: UIImage?    // currently shown avatar (downloaded or last saved)
  @Published var newAvatar: UIImage?       // newly picked image to upload on Save

  // UI/state flags
  @Published var isSaving = false
  @Published var alertMessage: String?
  @Published var showSavedAlert: Bool = false

  var hasError: Bool { alertMessage != nil } // convenience for alerts
  var hasErrorBinding: Binding<Bool> {       // binding to present/dismiss an Alert
    Binding<Bool>(
      get: { self.alertMessage != nil },
      set: { if !$0 { self.alertMessage = nil } }
    )
  }

  private var original: UserProfile?                              // last loaded/saved snapshot
  private let db = Firestore.firestore()                          // Firestore handle
  private let storage = StorageBucket.instance.reference()        // root Storage ref (project helper)
  private var listener: ListenerRegistration?                     // Firestore listener token

  var hasChanges: Bool {                                          // enable/disable Save button
    guard let o = original else { return true }                   // if nothing loaded yet → allow first save
    return firstName != o.firstName ||
           lastName  != o.lastName  ||
           username  != o.username  ||
           location  != o.location  ||
           genderPresentation != o.genderPresentation ||
           newAvatar != nil                                       // only a newly picked image counts
  }

  var initials: String {                                          // used for placeholder avatar
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName.first.map(String.init)  ?? ""
    return (f + l).uppercased()
  }

  func load() {
    guard let uid = Auth.auth().currentUser?.uid else {           // must be logged in
      alertMessage = "Not logged in."
      return
    }
    listener?.remove()                                            // avoid duplicate listeners
    listener = db.collection("users").document(uid)               // listen to our user doc
      .addSnapshotListener { [weak self] snap, error in
        guard let self = self else { return }
        if let e = error {                                        // network/permission errors
          self.alertMessage = e.localizedDescription
          return
        }
        guard let data = snap?.data(),
              let profile = UserProfile(dict: data)               // decode to our model
        else { return }

        DispatchQueue.main.async {                                // update form fields on main thread
          self.original = profile
          self.firstName = profile.firstName
          self.lastName  = profile.lastName
          self.username  = profile.username
          self.location  = profile.location
          self.genderPresentation = profile.genderPresentation
        }

        // try to fetch avatar once if any URL-like key exists (support legacy keys)
        let urlString = profile.photoURL
            ?? data["profileImageURL"] as? String
            ?? data["photoURL"] as? String
        if let urlString, let url = URL(string: urlString) {
          URLSession.shared.dataTask(with: url) { data,_,_ in
            guard let d = data, let img = UIImage(data: d) else { return }
            DispatchQueue.main.async { self.profileImage = img }   // set downloaded avatar
          }.resume()
        }
      }
  }

  func save() {
    guard let uid = Auth.auth().currentUser?.uid else { return }  // must be logged in
    isSaving = true

    // If user picked a new image: upload to Storage first, then write profile with its URL.
    if let img = newAvatar,
       let jpeg = img.jpegData(compressionQuality: 0.8)
    {
      let avatarRef = storage.child("avatars/\(uid).jpg")         // deterministic path per user
      avatarRef.putData(jpeg, metadata: nil) { [weak self] _, err in
        if let e = err {                                           // handle upload errors
          DispatchQueue.main.async {
            self?.isSaving = false
            self?.alertMessage = e.localizedDescription
          }
          return
        }
        avatarRef.downloadURL { url, e in                          // fetch public download URL
          if let e = e {
            DispatchQueue.main.async {
              self?.isSaving = false
              self?.alertMessage = e.localizedDescription
            }
            return
          }
          self?.writeProfile(uid: uid, photoURL: url?.absoluteString) // proceed to Firestore write
        }
      }
    } else {
      // No new image: just write fields, preserving existing photoURL from original.
      writeProfile(uid: uid, photoURL: original?.photoURL)
    }
  }

  private func writeProfile(uid: String, photoURL: String?) {
    // Build the payload from current form values (+ latest photoURL).
    var dict = UserProfile(
      firstName: firstName,
      lastName:  lastName,
      username:  username,
      location:  location,
      genderPresentation: genderPresentation,
      photoURL: photoURL
    ).toDict()

    // Keep legacy and new keys in sync for backward/forward compatibility.
    dict["username"] = username
    dict["userName"] = username
    dict["photoURL"] = photoURL ?? ""
    dict["profileImageURL"] = photoURL ?? ""

    db.collection("users").document(uid).setData(dict, merge: true) { [weak self] e in
      DispatchQueue.main.async {
        self?.isSaving = false                                      // stop spinner
        if let e = e {
          self?.alertMessage = e.localizedDescription               // surface Firestore error
        } else {
          // Update local snapshot and UI to reflect saved state.
          self?.original = UserProfile(dict: dict)                  // refresh baseline
          if let new = self?.newAvatar { self?.profileImage = new } // show the freshly uploaded avatar
          self?.newAvatar = nil                                     // clear staged image
          self?.showSavedAlert = true                               // trigger "Saved" toast/alert
        }
      }
    }
  }

  deinit { listener?.remove() }                                     // clean up Firestore listener
}
