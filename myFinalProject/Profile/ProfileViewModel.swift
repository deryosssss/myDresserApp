//
//  ProfileViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var joinDate: String = ""
    @Published var profileImage: UIImage? = nil
    @Published var isLoading: Bool = true

    private var listener: ListenerRegistration?

    init() {
        fetchUserData()
    }

    deinit {
        listener?.remove()
    }

    func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            isLoading = false
            return
        }
        self.email = user.email ?? ""

        let db = Firestore.firestore()
        let ref = db.collection("users").document(user.uid)
        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data() {
                self.username = data["userName"] as? String ?? ""
                // You may want to use "firstName" + "lastName"
                if let ts = data["createdAt"] as? Timestamp {
                    let date = ts.dateValue()
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    self.joinDate = formatter.string(from: date)
                }
                if let imageURL = data["profileImageURL"] as? String, !imageURL.isEmpty {
                    self.fetchProfileImage(from: imageURL)
                } else {
                    self.profileImage = nil
                }
            }
            self.isLoading = false
        }
    }

    private func fetchProfileImage(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let storageRef = Storage.storage().reference(forURL: urlString)
        storageRef.getData(maxSize: 3 * 1024 * 1024) { data, error in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = img
                }
            }
        }
    }
}

