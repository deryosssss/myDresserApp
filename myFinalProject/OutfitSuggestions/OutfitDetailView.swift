//  OutfitDetailView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 08/06/2025.
//  Updated to match OutfitPreviewSheet UI + persist favorite & delete.
//

//
import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct OutfitDetailView: View {
    @EnvironmentObject var vm: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss

    let outfit: Outfit

    // Form state (mirrors OutfitPreviewSheet)
    @State private var name: String = ""
    @State private var occasion: String? = nil
    @State private var createdOn: Date = Date()
    @State private var descriptionText: String = ""
    @State private var isFavorite: Bool = false

    // UI
    @State private var isSaving = false
    @State private var showDeleteAlert = false
    @State private var errorMessage: String?

    private let occasionOptions: [String] = [
        "Everyday", "Work", "Smart", "Smart casual", "Casual",
        "Party", "Date", "Wedding", "Travel", "Sport", "Gym", "School", "Holiday"
    ]

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

                        // Big preview (2-up grid)
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

                        // Items strip
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

                        // Meta form (same layout as preview sheet)
                        VStack(spacing: 12) {
                            TextField("Outfit name (optional)", text: $name)
                                .textFieldStyle(.roundedBorder)

                            // Occasion chips
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

                            DatePicker("Date", selection: $createdOn, displayedComponents: .date)

                            Toggle(isOn: $isFavorite) {
                                Label("Add to favourites", systemImage: isFavorite ? "heart.fill" : "heart")
                            }

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

                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.footnote)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 8)
                }

                // CTA Row — match preview sheet, but left button is a TRASH ICON (delete)
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
            .alert("Delete this outfit?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { Task { await deleteOutfit() } }
                Button("Cancel", role: .cancel) {}
            }
            .onAppear { seedFromModel(); Task { await loadExtraFieldsIfAny() } }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Derived

    private var previewURLs: [String] {
        // If odd count, duplicate last to keep a balanced 2-up grid look
        let urls = outfit.itemImageURLs
        if urls.count % 2 == 0 { return urls }
        if let last = urls.last { return urls + [last] }
        return urls
        }

    // MARK: - Seed & Load

    private func seedFromModel() {
        name = outfit.name
        descriptionText = outfit.description ?? ""
        isFavorite = outfit.isFavorite
        createdOn = outfit.createdAt ?? Date()
        // occasion loaded from document (optional)
    }

    /// Read extra fields that aren’t in the `Outfit` struct (e.g., "occasion", "createdOn")
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
            // Non-fatal
        }
    }

    // MARK: - Persistence

    private func saveChanges() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let oid = outfit.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

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

            // Optimistic local updates (update the arrays in vm.outfitsByItem)
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

    private func deleteOutfit() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let oid = outfit.id else { return }
        do {
            try await Firestore.firestore()
                .collection("users").document(uid)
                .collection("outfits").document(oid)
                .delete()

            // Remove from in-memory caches and dismiss
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
