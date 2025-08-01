
//
//  HomeView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//
import SwiftUI

struct HomeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                
                // 1. Top gradient banner
                VStack(spacing: 8) {
                    Text("Hi, Username")
                        .font(AppFont.spicyRice(size: 28))
                        .foregroundColor(.black)
                    Text("Well done – you wore 18 outfits this month!")
                        .font(AppFont.agdasima(size: 24))
                        .foregroundColor(.black.opacity(0.8))
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.pink.opacity(0.5),
                            Color.yellow.opacity(0.5),
                            Color.purple.opacity(0.5)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                .padding(.horizontal, 20)
                .padding(.top, 30)

                // 2. CO₂ saved banner
                Text("We have saved 15 kg CO₂ this month!")
                    .font(AppFont.agdasima(size: 20))
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.brandYellow)
                    .padding(.horizontal, 20)
                
                // 3. “New Items!” horizontal scroller
                VStack(alignment: .leading, spacing: 8) {
                    Text("New Items!")
                        .font(AppFont.agdasima(size: 20))
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // placeholder cards
                            ForEach(0..<5) { _ in
                                RoundedRectangle(cornerRadius: 0)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Image(systemName: "tshirt.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // 4. Style diversity box
                HStack {
                    Text("Style diversity:")
                        .font(AppFont.agdasima(size: 20))
                    Spacer()
                    Text("High")
                        .font(AppFont.spicyRice(size: 24))
                        
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.3))
                .padding(.horizontal, 20)
                
                // 5. Usage stats box
                HStack {
                    // Left column: labels
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Wardrobe Usage rate:")
                            .font(AppFont.agdasima(size: 20))
                        Text("Unused for 90 days:")
                            .font(AppFont.agdasima(size: 20))
                    }

                    Spacer()

                    // Right column: values
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("78%")
                            .font(AppFont.spicyRice(size: 24))
                        Text("7 items")
                            .font(AppFont.spicyRice(size: 24))
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue.opacity(0.3))
                .padding(.horizontal, 20)

                
                
                // 6. Create Outfit button
                Button(action: {
                    // Navigate to outfit builder
                }) {
                    Text("let’s create an outfit!")
                        .font(AppFont.spicyRice(size: 20))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.pink.opacity(0.4))
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
            }
        }
    }
}

