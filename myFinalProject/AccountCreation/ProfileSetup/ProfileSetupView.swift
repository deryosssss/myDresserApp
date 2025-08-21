import SwiftUI

/// First-time profile setup screen.
/// Purpose:
/// - Let the user add a profile photo (optional).
/// - Collect basic identity fields (first, last, username), DOB, and gender presentation.
/// - Validate locally, save via ViewModel, then navigate to ShoppingHabitsView on success.
struct ProfileSetupView: View {
    // View-owning stateful VM (lifecycle tied to this view instance).
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

                    // MARK: Profile picture picker
                    // Rationale:
                    // - Shows either the chosen image or a placeholder avatar.
                    // - Small "+" button opens a UIKit picker sheet (see ImagePicker wrapper).
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let image = vm.profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .clipShape(Circle()) // Round avatar
                            } else {
                                Image(systemName: "person.crop.circle")
                                    .resizable()
                                    .foregroundColor(.black.opacity(0.3))
                            }
                        }
                        .frame(width: 100, height: 100)
                        .background(Color.white)
                        .clipShape(Circle())

                        // Launch picker
                        Button(action: { vm.showImagePicker = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.pink)
                                .background(Circle().fill(Color.white).frame(width: 28, height: 28))
                                .font(.system(size: 28))
                                .offset(x: 2, y: 2)
                        }
                    }
                    .padding(.bottom, 10)
                    // Sheet uses our UIKit bridge to get a UIImage back into SwiftUI.
                    .sheet(isPresented: $vm.showImagePicker) {
                        ImagePicker(image: $vm.profileImage)
                    }

                    // MARK: Text inputs & pickers
                    // Design:
                    // - Use a shared text-field style for visual consistency.
                    // - DOB & Gender use pickers to keep values normalized.
                    VStack(spacing: 14) {
                        TextField("First name *", text: $vm.firstName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        TextField("Last name", text: $vm.lastName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        TextField("User name *", text: $vm.userName)
                            .textFieldStyle(ProfileTextFieldStyle())

                        // DOB: button opens a wheel-style date picker in a sheet.
                        Button(action: { vm.showDatePicker = true }) {
                            HStack {
                                Text("Date of Birth *")
                                    .foregroundColor(.gray)
                                Spacer()
                                // Shows formatted date or a gray placeholder when unchanged.
                                Text(vm.dobString)
                                    .foregroundColor(vm.dob == Date() ? .gray : .black)
                                Image(systemName: "calendar")
                                    .foregroundColor(.gray)
                                    .padding(.leading, 2)
                            }
                            .padding(13)
                            .background(Color.white)
                            .cornerRadius(4)
                            .font(AppFont.agdasima(size: 22))
                        }
                        .disabled(vm.isSaving)
                        .sheet(isPresented: $vm.showDatePicker) {
                            VStack {
                                // Restrict to past dates (no future DOBs).
                                DatePicker(
                                    "Select your date of birth",
                                    selection: $vm.dob,
                                    in: ...Date(),
                                    displayedComponents: .date
                                )
                                .datePickerStyle(.wheel)   // Mobile-friendly scroller
                                .labelsHidden()
                                Button("Done") { vm.showDatePicker = false }
                                    .padding(.top, 8)
                                    .font(AppFont.agdasima(size: 22))
                            }
                            .padding()
                            .background(Color.brandYellow)
                        }

                        // Gender presentation: action sheet of curated options.
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
                            .font(AppFont.agdasima(size: 22))
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

                    // MARK: Validation & save feedback
                    // Shows inline errors (client-side validation or save failures) and success hint.
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 18))
                            .padding([.horizontal, .top], 12)
                    }
                    if vm.showSuccess {
                        Text("Profile saved! 🎉")
                            .foregroundColor(.green)
                            .font(AppFont.agdasima(size: 22))
                            .padding(.top, 10)
                    }

                    // Primary CTA. Disabled until required fields are valid and not currently saving.
                    // padding, corner radius, and tap behavior across the app.
                    ContinueButton(
                        title: vm.isSaving ? "Saving..." : "Continue",
                        enabled: vm.canContinue && !vm.isSaving,
                        action: vm.continueTapped, // VM performs validation + persistence + navigation flag
                        backgroundColor: .white
                    )

                    Spacer()
                }
            }
            // Navigation is driven by a VM flag to keep logic out of the View.
            .navigationDestination(isPresented: $vm.goToShoppingHabits) {
                ShoppingHabitsView()
                    .navigationBarBackButtonHidden(true) // Enforce forward flow in onboarding
            }
        }
    }
}

// MARK: - Shared TextField visuals
/// Centralizes padding, colors, and font so all fields look consistent and are easy to tweak.
struct ProfileTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(13)
            .background(Color.white)
            .cornerRadius(4)
            .font(AppFont.agdasima(size: 22))
    }
}
