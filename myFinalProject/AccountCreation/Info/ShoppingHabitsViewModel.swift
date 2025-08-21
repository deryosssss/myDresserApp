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

/// MVVM ViewModel for the ShoppingHabits screen.
/// - Holds user selections and UI flags as @Published state.
/// - Validates input and persists to Firestore under the current user.
/// - Exposes simple booleans to drive the View (e.g., canContinue, isSaving, goToOnboarding).
class ShoppingHabitsViewModel: ObservableObject {

    // MARK: - Static options shown by the View
    /// Radio-like choices for "how often do you buy".
    let frequencyOptions = [
        "Weekly", "Monthly", "Every few months", "Only when needed"
    ]
    /// Discrete ranges for "items purchased in last 3 months".
    let purchaseOptions = [
        "0", "1-3 items", "3-10 items", "10-20 items", "Too many!"
    ]

    // MARK: - User selections & view state
    /// User’s selected frequency option (nil until chosen).
    @Published var selectedFrequency: String? = nil
    /// User’s selected purchase-range option (nil until chosen).
    @Published var selectedPurchases: String? = nil
    /// Controls the iOS action sheet (picker) visibility.
    @Published var showPurchasePicker = false

    /// Transient UI feedback.
    @Published var errorMessage = ""
    /// Flip while a network write is in progress (disables buttons).
    @Published var isSaving = false
    /// When true, the View navigates to onboarding (navigation driven by VM).
    @Published var goToOnboarding = false
    /// Brief success notice the View can show after a write.
    @Published var showSuccess = false

    // MARK: - Derived UI gating
    /// Enables the primary button only when both answers are set and we’re not mid-save.
    var canContinue: Bool {
        selectedFrequency != nil && selectedPurchases != nil && !isSaving
    }

    // MARK: - Intent: persist answers to Firestore
    /// Validates input, writes to `/users/{uid}` with `merge: true`, and toggles navigation on success.
    /// Notes:
    /// - `merge: true` ensures we **don’t overwrite** other user fields.
    /// - Uses `FieldValue.serverTimestamp()` so the write is timestamped on the server (authoritative).
    /// - Always hops back to the main thread to mutate @Published properties.
    func saveHabits() {
        // Reset transient UI
        errorMessage = ""
        showSuccess = false

        // Require an authenticated user; if token expired, prompt re-login.
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not authenticated. Please sign in again."
            return
        }
        // Validate both answers are present.
        guard let freq = selectedFrequency, let purchases = selectedPurchases else {
            errorMessage = "Please answer all questions."
            return
        }

        isSaving = true

        // Build payload (flat map for simplicity; easy to evolve later).
        let db = Firestore.firestore()
        let data: [String: Any] = [
            "shoppingFrequency": freq,
            "purchasesLast3Months": purchases,
            "shoppingHabitsSavedAt": FieldValue.serverTimestamp()
        ]

        // Write with merge to preserve other user fields, capture self weakly to avoid retain cycles.
        db.collection("users").document(user.uid).setData(data, merge: true) { [weak self] err in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSaving = false
                if let err = err {
                    // Surface a readable error; keep the user on the screen.
                    self.errorMessage = "Could not save: \(err.localizedDescription)"
                } else {
                    // Success: show a quick confirmation and advance the flow.
                    self.showSuccess = true
                    self.goToOnboarding = true
                }
            }
        }
    }
}
