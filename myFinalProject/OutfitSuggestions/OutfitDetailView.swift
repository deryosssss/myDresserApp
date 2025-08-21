//  OutfitDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 08/06/2025.
//  Updated to match OutfitPreviewSheet UI + persist favorite & delete.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

/// Detail/editor for a saved Outfit:
/// - mirrors the UI of `OutfitPreviewSheet` so the experience is consistent
/// - allows editing meta (name/occasion/date/description/favorite)
/// - supports deleting the outfit document
struct OutfitDetailView: View {
    // Upstream data/cache owner (used for optimistic updates after save/delete)
    @EnvironmentObject var vm: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss

    let outfit: Outfit

    // MARK: - Form state (binds to controls)
    @State private var name: String = ""
    @State private var occasion: String? = nil
    @State private var createdOn: Date = Date()
    @State private var descriptionText: String = ""
    @State private var isFavorite: Bool = false

    // MARK: - UI state
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    /// Pills shown for the occasion selector (simple, local list)
    private let occasionOptions: [String] = [
        "Everyday", "Work", "Smart", "Smart casual", "Casual",
        "Party", "Date", "Wedding", "Travel", "Sport", "Gym", "School", "Holiday"
    ]

    /// Two-column grid for the large preview images
    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Outfit preview")
                            .font(.custom("SpicyRice-Regular", size: 26, relativeTo: .headline))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)

    
                        LazyVGrid(columns: grid, spacing: 12) {
                            ForEach(previewURLs, id: \.self) { url in
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        AsyncImage(url: URL(string: url)) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().scaledToFit()
                                            case .empty: ProgressView()
                                            default: Image(systemName: "photo")
                                            }
                                        }
                                        .padding(10)
                                    )
                                    .frame(height: 200)
                            }
                        }
                        .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Items")
                                .font(AppFont.spicyRice(size: 18))
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(outfit.itemImageURLs, id: \.self) { url in
                                        AsyncImage(url: URL(string: url)) { phase in
                                            switch phase {
                                            case .success(let img): img.resizable().scaledToFit()
                                            case .empty: Color(.tertiarySystemFill)
                                            default: Color(.tertiarySystemFill)
                                            }
                                        }
                                        .frame(width: 90, height: 110)
                                        .clipped()
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)

                        VStack(spacing: 12) {
                            TextField("Outfit name (optional)", text: $name)
                                .textFieldStyle(.roundedBorder)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(occasionOptions, id: \.self) { opt in
                                        let selected = occasion == opt
                                        Button {
                                            occasion = selected ? nil : opt
                                        } label: {
                                            Text(opt)
                                                .font(.caption)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 10)
                                                .background(selected ? Color.brandBlue : Color.brandGrey)
                                                .foregroundColor(.black)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }

                            // Date the outfit is associated with (stored as Timestamp)
                            DatePicker("Date", selection: $createdOn, displayedComponents: .date)

                            // Favorite toggle (saves to `isFavorite`)
                            Toggle(isOn: $isFavorite) {
                                Label("Add to favourites", systemImage: isFavorite ? "heart.fill" : "heart")
                            }

                            // Free-text notes/description
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description").font(.subheadline)
                                TextEditor(text: $descriptionText)
                                    .frame(minHeight: 80)
                                    .padding(8)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal)

                        // Inline error feedback
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // --- CTA row
                // Left: Delete (shows confirm alert). Right: Save changes.
                HStack(spacing: 12) {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandPink)
                    .disabled(isSaving || outfit.id == nil)

                    Button {
                        Task { await saveChanges() }
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 28)
                        } else {
                            Text("Save changes")
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, minHeight: 28)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                    .disabled(isSaving || outfit.id == nil)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            // Destructive confirmation for delete to avoid accidental loss
            .alert("Delete this outfit?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { Task { await deleteOutfit() } }
                Button("Cancel", role: .cancel) {}
            }
            // Seed UI from the model and fetch any extra fields that aren’t in `Outfit`
            .onAppear { seedFromModel(); Task { await loadExtraFieldsIfAny() } }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Derived

    /// Ensures a balanced 2-up grid by duplicating the last image when count is odd.
    private var previewURLs: [String] {
        let urls = outfit.itemImageURLs
        if urls.count % 2 == 0 { return urls }
        if let last = urls.last { return urls + [last] }
        return urls
    }

    // MARK: - Seed & Load

    /// Initialize form state from the passed `Outfit` model.
    private func seedFromModel() {
        name = outfit.name
        descriptionText = outfit.description ?? ""
        isFavorite = outfit.isFavorite
        createdOn = outfit.createdAt ?? Date() // fallback if createdOn not present
        // `occasion` is loaded lazily from Firestore below (if present)
    }

    /// Reads extra fields that aren’t on `Outfit` (e.g. "occasion", "createdOn").
    private func loadExtraFieldsIfAny() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let oid = outfit.id else { return }
        do {
            let snap = try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document(oid)
                .getDocument()

            if let occ = snap.data()?["occasion"] as? String { occasion = occ }
            if let ts = snap.data()?["createdOn"] as? Timestamp {
                createdOn = ts.dateValue()
            } else if let ts = snap.data()?["createdAt"] as? Timestamp {
                createdOn = ts.dateValue()
            }
        } catch {
        }
    }

    // MARK: - Persistence

    /// Writes edited fields back to Firestore and updates local caches optimistically.
    private func saveChanges() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let oid = outfit.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // Patch-style update: only send changed fields; delete `occasion` if user cleared it.
        var patch: [String: Any] = [
            "name": name,
            "description": descriptionText,
            "isFavorite": isFavorite,
            "createdOn": createdOn
        ]
        if let occasion {
            patch["occasion"] = occasion
        } else {
            patch["occasion"] = FieldValue.delete()
        }

        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document(oid)
                .updateData(patch)

            for (key, var arr) in vm.outfitsByItem {
                if let idx = arr.firstIndex(where: { $0.id == oid }) {
                    arr[idx].name = name
                    arr[idx].description = descriptionText.isEmpty ? nil : descriptionText
                    arr[idx].isFavorite = isFavorite
                    vm.outfitsByItem[key] = arr
                }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    /// Deletes the outfit document and removes it from local caches.
    private func deleteOutfit() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let oid = outfit.id else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document(oid)
                .delete()

            // Clear from caches so lists update without a reload.
            for key in vm.outfitsByItem.keys {
                vm.outfitsByItem[key]?.removeAll { $0.id == oid }
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
