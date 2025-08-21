//
//  ShoppingHabitsView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI

/// Collects basic shopping-habit info from the user:
/// - frequency of buying clothes
/// - number of items purchased in the last 3 months
/// Saves via the ViewModel and navigates to onboarding on success.
///

struct ShoppingHabitsView: View {
    @StateObject private var vm = ShoppingHabitsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 24) {
                    // Only this uses SpicyRice
                    Text("Your shopping habits")
                        .font(AppFont.spicyRice(size: 36))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 130)

                    // All other text uses Agdasima
                    Text("How often do you buy new clothes?")
                        .font(AppFont.agdasima(size: 22))
                        .foregroundColor(.black)
                        .padding(.leading, 24)
                        .padding(.top, 10)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(vm.frequencyOptions, id: \.self) { option in
                            Button(action: {
                                vm.selectedFrequency = option
                            }) {
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

                    Text("How many new clothing items did you purchase in the past 3 months?")
                        .font(AppFont.agdasima(size: 22))
                        .foregroundColor(.black)
                        .padding(.leading, 24)

                    Button(action: {
                        vm.showPurchasePicker = true
                    }) {
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
                                .default(Text(option).font(AppFont.agdasima(size: 20))) { vm.selectedPurchases = option }
                            } + [.cancel()]
                        )
                    }

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
            .navigationDestination(isPresented: $vm.goToOnboarding) {
                OnboardingContainerView()
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}
