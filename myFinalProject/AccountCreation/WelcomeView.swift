//
//  WelcomeView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var auth: AuthViewModel   // <— add this
    @State private var showSignInUp = false
    @State private var mScale: CGFloat = 0.5
    @State private var mOpacity: Double = 0.0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandYellow.ignoresSafeArea()
                VStack(spacing: -70) {
                    Spacer()
                    ZStack {
                        Text("M")
                            .font(AppFont.spicyRice(size: 210))
                            .foregroundColor(.black)
                            .offset(x: 5, y: 5)
                            .blur(radius: 0.5)
                        Text("M")
                            .font(AppFont.spicyRice(size: 200))
                            .foregroundColor(.white)
                            .appDropShadow()
                    }
                    .scaleEffect(mScale)
                    .opacity(mOpacity)
                    .shadow(color: .black.opacity(0.15), radius: 18, x: 0, y: 12)

                    ZStack {
                        Text("MyDresser")
                            .font(AppFont.spicyRice(size: 50))
                            .foregroundColor(.white)
                            .appDropShadow()
                            .padding(.bottom, 80)
                    }
                    .opacity(mOpacity)
                    Spacer()
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { mScale = 1.15; mOpacity = 1.0 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    withAnimation(.interpolatingSpring(stiffness: 170, damping: 10)) {
                        mScale = 1.0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSignInUp = true
                }
            }
            .navigationDestination(isPresented: $showSignInUp) {
                SignInUpView()
                    .navigationBarBackButtonHidden(true)
                    .environmentObject(auth)   // <— pass it down
            }
        }
    }
}
