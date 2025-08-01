//
//  AccountDetailsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

final class AccountDetailsViewModel: ObservableObject {
  // profile fields
  @Published var firstName = ""
  @Published var lastName = ""
  @Published var username = ""
  @Published var location = ""
  @Published var genderPresentation = ""

  // avatar
  @Published var profileImage: UIImage?

  // state
  @Published var isSaving = false
  @Published var alertMessage: String?
  var hasError: Bool { alertMessage != nil }
  var hasErrorBinding: Binding<Bool> {
    Binding<Bool>(
      get: { self.alertMessage != nil },
      set: { if !$0 { self.alertMessage = nil } }
    )
  }

  private var original: UserProfile?
  private let db = Firestore.firestore()
  private let storage = Storage.storage().reference()
  private var listener: ListenerRegistration?

  var hasChanges: Bool {
    guard let o = original else { return false }
    return firstName != o.firstName ||
           lastName  != o.lastName  ||
           username  != o.username  ||
           location  != o.location  ||
           genderPresentation != o.genderPresentation ||
           profileImage != nil // new image selected
  }

  var initials: String {
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName.first.map(String.init)  ?? ""
    return (f + l).uppercased()
  }

  func load() {
    guard let uid = Auth.auth().currentUser?.uid else {
      alertMessage = "Not logged in."
      return
    }
    listener?.remove()
    listener = db.collection("users").document(uid)
      .addSnapshotListener { [weak self] snap, error in
        guard let self = self else { return }
        if let e = error {
          self.alertMessage = e.localizedDescription
          return
        }
        guard let data = snap?.data(),
              let profile = UserProfile(dict: data)
        else { return }

        DispatchQueue.main.async {
          self.original = profile
          self.firstName = profile.firstName
          self.lastName  = profile.lastName
          self.username  = profile.username
          self.location  = profile.location
          self.genderPresentation = profile.genderPresentation
        }

        // if there's a photoURL, fetch it once
        if let urlString = profile.photoURL,
           let url = URL(string: urlString)
        {
          URLSession.shared.dataTask(with: url) { data,_,_ in
            guard let d = data, let img = UIImage(data: d) else { return }
            DispatchQueue.main.async { self.profileImage = img }
          }.resume()
        }
      }
  }

  func save() {
    guard let uid = Auth.auth().currentUser?.uid else { return }
    isSaving = true

    // 1) if new image selected: upload it first
    if let img = profileImage,
       let jpeg = img.jpegData(compressionQuality: 0.8)
    {
      let avatarRef = storage.child("avatars/\(uid).jpg")
      avatarRef.putData(jpeg, metadata: nil) { [weak self] _, err in
        if let e = err {
          DispatchQueue.main.async {
            self?.isSaving = false
            self?.alertMessage = e.localizedDescription
          }
          return
        }
        avatarRef.downloadURL { url, e in
          if let e = e {
            DispatchQueue.main.async {
              self?.isSaving = false
              self?.alertMessage = e.localizedDescription
            }
            return
          }
          self?.writeProfile(uid: uid, photoURL: url?.absoluteString)
        }
      }
    } else {
      // no new image, just update fields
      writeProfile(uid: uid, photoURL: original?.photoURL)
    }
  }

  private func writeProfile(uid: String, photoURL: String?) {
    var dict = UserProfile(
      firstName: firstName,
      lastName:  lastName,
      username:  username,
      location:  location,
      genderPresentation: genderPresentation,
      photoURL: photoURL
    ).toDict()

    db.collection("users").document(uid).setData(dict, merge: true) { [weak self] e in
      DispatchQueue.main.async {
        self?.isSaving = false
        if let e = e {
          self?.alertMessage = e.localizedDescription
        } else {
          // reset original
          self?.original = UserProfile(dict: dict)
          // clear selection so hasChanges falls back
          self?.profileImage = nil
        }
      }
    }
  }

  deinit { listener?.remove() }
}
