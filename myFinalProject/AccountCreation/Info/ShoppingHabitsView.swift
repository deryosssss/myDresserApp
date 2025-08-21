//
//  ShoppingHabitsView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

/// MVVM View:
/// Collects two self-reported signals:
/// (1) shopping frequency,
/// (2) items bought in last 3 months.
///
/// The View stays dumb: renders UI, binds to @Published state on the ViewModel, and calls a single intent (`saveHabits`).
/// On success, it navigates to onboarding via a boolean the VM toggles.
///
struct ShoppingHabitsView: View {
    // View owns the VM's lifecycle for this screen
    @StateObject private var vm = ShoppingHabitsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                // Brand backdrop sets the page tone
                Color.brandYellow.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 24) {

                    Text("Your shopping habits")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 130)

                    // Q1 — frequency
                    Text("How often do you buy new clothes?")
                        .font(AppFont.agdasima(size: 22))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 10)


                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.frequencyOptions, id: \.self) { option in
                            Button {
                                vm.selectedFrequency = option
                            } label: {
                                HStack {
                                    Image(systemName: vm.selectedFrequency == option ? "checkmark.square" : "square")
                                        .foregroundColor(.black)
                                    Text(option)
                                        .foregroundColor(.black)
                                        .font(AppFont.agdasima(size: 20))
                                }
                            }
                        }
                    }
                    .padding(.leading, 38)
                    .padding(.bottom, 10)

                    // Q2 — count of items 
                    Text("How many new clothing items did you purchase in the past 3 months?")
                        .font(AppFont.agdasima(size: 22))
                        .foregroundColor(.black)
                        .padding(.leading, 24)


                    Button {
                        vm.showPurchasePicker = true
                    } label: {
                        HStack {
                            Text(vm.selectedPurchases ?? "Select")
                                .foregroundColor(vm.selectedPurchases == nil ? .gray : .black)
                                .font(AppFont.agdasima(size: 20))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, 6)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                        }
                        .frame(height: 40)
                        .background(Color.white)
                        .cornerRadius(4)
                        .padding(.horizontal, 24)
                    }

                    .actionSheet(isPresented: $vm.showPurchasePicker) {
                        ActionSheet(
                            title: Text("How many items?")
                                .font(AppFont.agdasima(size: 20)),
                            buttons: vm.purchaseOptions.map { option in
                                .default(Text(option).font(AppFont.agdasima(size: 20))) {
                                    vm.selectedPurchases = option
                                }
                            } + [.cancel()]
                        )
                    }

                    // Inline feedback: show either validation errors or a success ping after saving.
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .font(AppFont.agdasima(size: 18))
                            .padding([.horizontal, .top], 12)
                    }
                    if vm.showSuccess {
                        Text("Saved! 🎉")
                            .foregroundColor(.green)
                            .font(AppFont.agdasima(size: 20))
                            .padding(.top, 10)
                    }

                    // Primary action. Enabled only when inputs are valid (`vm.canContinue`).
                    // While saving, we flip the label to "Saving…" for immediate feedback.
                    Button(action: vm.saveHabits) {
                        Text(vm.isSaving ? "Saving..." : "Continue")
                            .font(AppFont.agdasima(size: 22))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(vm.canContinue ? 1 : 0.7))
                            .cornerRadius(6)
                            .padding(.horizontal, 24)
                    }
                    .disabled(!vm.canContinue)

                    Spacer()
                }
            }
            // Navigation is driven by the VM (decouples flow from the View).
            .navigationDestination(isPresented: $vm.goToOnboarding) {
                OnboardingContainerView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
