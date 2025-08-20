//
//  AccountDetailsView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI

struct AccountDetailsView: View {
  @StateObject private var vm = AccountDetailsViewModel()
  @Environment(\.dismiss) var dismiss
  @State private var showingImagePicker = false

  var body: some View {
    VStack(spacing: 32) {
      // Avatar (tap to pick)
      avatarSection
        .onTapGesture { showingImagePicker = true }
        .padding(.top, 20)

      Text("My account details")
        .font(AppFont.spicyRice(size: 30))

      formFields

      Button(action: { vm.save() }) {
        Text(vm.isSaving ? "Saving…" : "Save")
          .font(.system(size: 18, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding()
          .background(vm.hasChanges ? Color.blue : Color.gray)
      }
      .disabled(vm.isSaving || !vm.hasChanges)
      .padding(.horizontal, 20)

      Spacer()
    }
    .padding(.top, 16)
    .background(Color.white.ignoresSafeArea())
    .onAppear { vm.load() }

    // Pick new avatar → bind to newAvatar (not profileImage) so hasChanges is correct
    .sheet(isPresented: $showingImagePicker) {
      ImagePicker(image: $vm.newAvatar)
    }

    // Error alert
    .alert("Error",
           isPresented: vm.hasErrorBinding,
           actions: { Button("OK", role: .cancel) { } },
           message: { Text(vm.alertMessage ?? "") })

    // Success popup
    .alert("Saved", isPresented: $vm.showSavedAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text("Your information has been updated.")
    }
    .navigationBarTitleDisplayMode(.inline)
  }

  private var avatarSection: some View {
    ZStack {
      Circle()
        .fill(Color.brandPeach)
        .frame(width: 120, height: 120)
      Circle()
        .stroke(Color.white, lineWidth: 4)
        .frame(width: 110, height: 110)

      // Show newly picked avatar if present; else show current profile image; else initials
      if let img = vm.newAvatar ?? vm.profileImage {
        Image(uiImage: img)
          .resizable()
          .scaledToFill()
          .frame(width: 110, height: 110)
          .clipShape(Circle())
      } else {
        Text(vm.initials)
          .font(.system(size: 36, weight: .bold))
          .foregroundColor(.black)
      }

      Circle()
        .fill(Color.white)
        .frame(width: 32, height: 32)
        .overlay(Image(systemName: "camera.fill").foregroundColor(.black))
        .offset(x: 40, y: 40)
    }
  }

  private var formFields: some View {
    VStack(spacing: 16) {
      LabeledTextField(label: "First Name", text: $vm.firstName)
      LabeledTextField(label: "Last Name",  text: $vm.lastName)
      LabeledTextField(label: "Username",   text: $vm.username)
      LabeledTextField(label: "Location",   text: $vm.location)
      LabeledTextField(label: "Gender Presentation", text: $vm.genderPresentation)
    }
    .padding(.horizontal, 20)
  }
}
