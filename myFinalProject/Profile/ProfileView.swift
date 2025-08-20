//
//  ProfileView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct ProfileView: View {
    // Default placeholders (shown until VM loads)
    var username: String = "Username"
    var email: String = "Email"
    var joinDate: String = "Join Date"
    var profileImage: UIImage? = nil

    @StateObject private var vm = ProfileViewModel()
    @State private var showHelpSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Card
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.white))
                            .frame(height: 130)
                            .padding(.top, 140)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)

                        // Profile image (prefer VM image; fallback to prop)
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .background(
                                Group {
                                    if let img = vm.profileImage ?? profileImage {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(Color(.systemGray4))
                                    }
                                }
                            )
                            .frame(width: 80, height: 80)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: -18, y: -16)
                            .padding(.leading, 190)
                            .padding(.top, 120)
                            .shadow(radius: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.username.isEmpty ? username : vm.username)
                                .font(AppFont.spicyRice(size: 28))
                                .foregroundColor(.black)
                            Text(vm.email.isEmpty ? email : vm.email)
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.black)
                            Text(vm.joinDate.isEmpty ? joinDate : vm.joinDate)
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.black)
                        }
                        .padding(.top, 170)
                        .padding(.leading, 40)
                    }
                    .frame(height: 120)
                    .padding(.bottom, 50)

                    // List buttons
                    VStack(spacing: 20) {
                        NavigationLink(destination: AccountDetailsView()) {
                            ProfileListButton(icon: "person.fill", label: "My account details")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        NavigationLink(destination: StatsView()) {
                            ProfileListButton(icon: "chart.bar.fill", label: "My Stats")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        NavigationLink(destination: OutfitsView()) {
                            ProfileListButton(icon: "hanger", label: "My Outfits")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        NavigationLink(destination: FavouritesView()) {
                            ProfileListButton(icon: "heart.fill", label: "My Favourites")
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        NavigationLink(destination: NotificationsView()) {
                            ProfileListButton(icon: "bell.fill", label: "My notifications", showDot: true)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Log out
                    Button(action: { vm.signOut() }) {
                        Text(vm.isWorking ? "Working..." : "Log Out")
                            .font(AppFont.agdasima(size: 20))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))     // ⬅️ rounded
                    }
                    .disabled(vm.isWorking)
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                    Spacer()

                    // Bottom row
                    HStack(spacing: 18) {
                        Button(action: { showHelpSheet = true }) {
                            HStack(spacing: 5) {
                                Image(systemName: "questionmark.circle")
                                Text("Help")
                            }
                            .font(AppFont.agdasima(size: 20))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10)) // ⬅️ rounded
                        }

                        NavigationLink {
                            DeleteAccountView()
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            Text("Delete Account")
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.red.opacity(0.18))
                                .clipShape(RoundedRectangle(cornerRadius: 10)) // ⬅️ rounded
                        }
                        .disabled(vm.isWorking)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationBarHidden(true)
        }
        // Error alert
        .alert("Error", isPresented: $vm.showError) {
            Button("OK", role: .cancel) {}
        } message: { Text(vm.errorMessage) }

        // Confirm delete
        .alert("Delete Account?", isPresented: $vm.showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { vm.confirmDeleteAccount() }
        } message: {
            Text("This will permanently remove your account, wardrobe items, and images.")
        }

        // Re-auth sheet
        .sheet(isPresented: $vm.showReauthSheet) {
            ReauthView(
                email: $vm.reauthEmail,
                password: $vm.reauthPassword,
                isWorking: vm.isWorking,
                onCancel: { vm.showReauthSheet = false },
                onConfirm: { vm.performReauthAndDelete() }
            )
            .presentationDetents([.height(260)])
        }

        // Help sheet
        .sheet(isPresented: $showHelpSheet) {
            HelpSheetView(username: vm.username.isEmpty ? username : vm.username)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Local ReauthView so it's always in scope
private struct ReauthView: View {
    @Binding var email: String
    @Binding var password: String
    var isWorking: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Re-authenticate") {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    SecureField("Password", text: $password)
                }
            }
            .navigationTitle("Confirm Identity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isWorking ? "Working…" : "Confirm", action: onConfirm)
                        .disabled(isWorking || email.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
