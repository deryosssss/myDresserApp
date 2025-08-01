//
//  ShoppingHabitsViewModel.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import Foundation
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

class ShoppingHabitsViewModel: ObservableObject {
    // Shopping frequency options
    let frequencyOptions = [
        "Weekly", "Monthly", "Every few months", "Only when needed"
    ]
    let purchaseOptions = [
        "0", "1-3 items", "3-10 items", "10-20 items", "Too many!"
    ]
    
    @Published var selectedFrequency: String? = nil
    @Published var selectedPurchases: String? = nil
    @Published var showPurchasePicker = false

    @Published var errorMessage = ""
    @Published var isSaving = false
    @Published var goToOnboarding = false
    @Published var showSuccess = false

    var canContinue: Bool {
        selectedFrequency != nil && selectedPurchases != nil && !isSaving
    }

    func saveHabits() {
        errorMessage = ""
        showSuccess = false

        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not authenticated. Please sign in again."
            return
        }
        guard let freq = selectedFrequency, let purchases = selectedPurchases else {
            errorMessage = "Please answer all questions."
            return
        }

        isSaving = true
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "shoppingFrequency": freq,
            "purchasesLast3Months": purchases,
            "shoppingHabitsSavedAt": FieldValue.serverTimestamp()
        ]
        db.collection("users").document(user.uid).setData(data, merge: true) { [weak self] err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if let err = err {
                    self.errorMessage = "Could not save: \(err.localizedDescription)"
                } else {
                    self.showSuccess = true
                    self.goToOnboarding = true
                }
            }
        }
    }
}
