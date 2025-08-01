//
//  ProfileView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 30/07/2025.
//
import SwiftUI


struct ProfileView: View {
    var username: String = "Username"
    var email: String = "Email"
    var joinDate: String = "Join Date"
    var profileImage: UIImage? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack(spacing: 0) {
                    // Header Card
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.pink.opacity(0.5),
                                    Color.yellow.opacity(0.5),
                                    Color.purple.opacity(0.5)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                            .frame(height: 130)
                            .padding(.top, 140)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 60)

                        // Profile image
                        Circle()
                            .stroke(Color.white, lineWidth: 3)
                            .background(
                                Group {
                                    if let img = profileImage {
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
                            .shadow(radius: 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(username)
                                .font(AppFont.spicyRice(size: 28))
                                .foregroundColor(.black)
                            Text(email)
                                .font(AppFont.agdasima(size: 15))
                                .foregroundColor(.black)
                            Text(joinDate)
                                .font(AppFont.agdasima(size: 15))
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
                        NavigationLink(destination: StatsView()) {
                            ProfileListButton(icon: "chart.bar.fill", label: "My Stats")
                        }
                        NavigationLink(destination: OutfitsView()) {
                            ProfileListButton(icon: "hanger", label: "My Outfits")
                        }
                        NavigationLink(destination: FavouritesView()) {
                            ProfileListButton(icon: "heart.fill", label: "My Favourites")
                        }
                        NavigationLink(destination: NotificationsView()) {
                            ProfileListButton(icon: "bell.fill", label: "My notifications", showDot: true)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Log out
                    Button(action: { }) {
                        Text("Log Out")
                            .font(AppFont.agdasima(size: 20))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            
                    }
                    .padding(.top, 20)
                    .padding(.horizontal, 16)

                    Spacer()

                    // Bottom row
                    HStack(spacing: 18) {
                        Button(action: { }) {
                            HStack(spacing: 5) {
                                Image(systemName: "questionmark.circle")
                                Text("Help")
                            }
                            .font(AppFont.agdasima(size: 20))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color(.systemGray6))
                            
                        }
                        Button(action: { }) {
                            Text("Delete Account")
                                .font(AppFont.agdasima(size: 20))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.red.opacity(0.18))
                                
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .padding(.top, 20)
            }
            .navigationBarHidden(true)
        }
    }
}
