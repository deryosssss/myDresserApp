import SwiftUI

/// First-time profile setup screen:
/// - lets the user add a photo
/// - collects first/last/user names, DOB, and gender presentation
/// - saves via the VM and navigates to ShoppingHabitsView on success
///
struct ProfileSetupView: View {
    @StateObject private var vm = ProfileSetupViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer().frame(height: 80)

                    Text("Tell us who you are")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .center)

// --- Profile picture picker ----------------------------------------------------
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = vm.profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .foregroundColor(.black.opacity(0.3))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())

                        Button(action: { vm.showImagePicker = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.pink)
                                .background(Circle().fill(Color.white).frame(width: 28, height: 28))
                                .font(.system(size: 28))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .padding(.bottom, 10)
                    .sheet(isPresented: $vm.showImagePicker) {
                        ImagePicker(image: $vm.profileImage)
                    }
// --- Text fields & pickers ----------------------------------------------------
                    VStack(spacing: 14) {
                        TextField("First name *", text: $vm.firstName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        TextField("Last name", text: $vm.lastName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        TextField("User name *", text: $vm.userName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        // Date of Birth
                        Button(action: { vm.showDatePicker = true }) {
                            HStack {
                                Text("Date of Birth *")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(vm.dobString)
                                    .foregroundColor(vm.dob == Date() ? .gray : .black)
                                Image(systemName: "calendar")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 2)
                            }
                            .padding(13)
                            .background(Color.white)
                            .cornerRadius(4)
                            .font(AppFont.agdasima(size: 18))
                        }
                        .disabled(vm.isSaving)
                        .sheet(isPresented: $vm.showDatePicker) {
                            VStack {
                                DatePicker(
                                    "Select your date of birth",
                                    selection: $vm.dob,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                Button("Done") { vm.showDatePicker = false }
                                    .padding(.top, 8)
                                    .font(AppFont.agdasima(size: 18))
                            }
                            .padding()
                            .background(Color.brandYellow)
                        }

                        // Gender Presentation
                        Button(action: { vm.showGenderPicker = true }) {
                            HStack {
                                Text(vm.genderPresentation.isEmpty ? "Gender Presentation" : vm.genderPresentation)
                                    .foregroundColor(vm.genderPresentation.isEmpty ? .gray : .black)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding(13)
                            .background(Color.white)
                            .cornerRadius(4)
                            .font(AppFont.agdasima(size: 18))
                        }
                        .actionSheet(isPresented: $vm.showGenderPicker) {
                            ActionSheet(
                                title: Text("Gender Presentation"),
                                buttons: vm.genderOptions.map { option in
                                    .default(Text(option)) { vm.genderPresentation = option }
                                } + [.cancel()]
                            )
                        }
                    }
                    .padding(.horizontal, 24)

// --- Validation feedback ------------------------------------------------------
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 15))
                            .padding([.horizontal, .top], 12)
                    }
                    if vm.showSuccess {
                        Text("Profile saved! 🎉")
                            .foregroundColor(.green)
                            .font(AppFont.agdasima(size: 17))
                            .padding(.top, 10)
                    }

                    ContinueButton(
                        title: vm.isSaving ? "Saving..." : "Continue",
                        enabled: vm.canContinue && !vm.isSaving,
                        action: vm.continueTapped,
                        backgroundColor: .white
                    )

                    Spacer()
                }
            }
            .navigationDestination(isPresented: $vm.goToShoppingHabits) {
                ShoppingHabitsView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

// MARK: - Custom TextField Style
struct ProfileTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(13)
            .background(Color.white)
            .cornerRadius(4)
            .font(AppFont.agdasima(size: 18))
    }
}
