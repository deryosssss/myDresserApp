//
//  MagicView.swift
//  myFinalProject
//
//  Created by Derya Baglan on 31/07/2025.
//

import SwiftUI
import CoreLocation
import UIKit
import FirebaseAuth

struct MagicView: View {
    @StateObject private var vm = MagicViewModel()
    @State private var selectedDate: Date? = nil
    @State private var hasAutoScrolled = false
    
    var body: some View {
        GeometryReader { geo in
            // compute a responsive card height based on available height
            // (works in preview and with a TabView in the simulator)
            let h = geo.size.height
            let cardHeight = max(200, min(280, h * 0.27 )) // clamp to 180…280
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    dayScroller
                    actionBoard(cardHeight: cardHeight)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20) // breathing room above the tab bar
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
    
    // MARK: Header (weather + selected date)
    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = vm.icon {
                    icon.resizable().frame(width: 50, height: 50)
                } else {
                    Image(systemName: "cloud.sun")
                        .symbolRenderingMode(.multicolor)
                    
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.temperature)
                    .font(AppFont.spicyRice(size: 36))
                Text((selectedDate ?? vm.currentDate), formatter: fullDateFormatter)
                    .font(AppFont.spicyRice(size: 20))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    
    // MARK: Week scroller (Mon–Sun chips)
    private var dayScroller: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(vm.weekDates, id: \.self) { date in
                        let isSelected = Calendar.current.isDate(
                            date,
                            inSameDayAs: selectedDate ?? vm.currentDate
                        )
                        DayChip(date: date, isSelected: isSelected)
                            .id(date)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    selectedDate = date
                                    proxy.scrollTo(date, anchor: .center)
                                }
                                haptic()
                            }
                            .onAppear {
                                if !hasAutoScrolled && Calendar.current.isDateInToday(date) {
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.35)) {
                                            proxy.scrollTo(date, anchor: .center)
                                        }
                                        hasAutoScrolled = true
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
    
    // MARK: Big grey panel with 4 colorful cards (as NavigationLinks)
    private func actionBoard(cardHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 0),
                          GridItem(.flexible(), spacing: 0)],
                spacing: 15
            ) {
                NavigationLink {
                    WeatherSuggestionView(
                        userId: Auth.auth().currentUser?.uid ?? "preview-user",
                        lat: vm.latitude ?? 0,
                        lon: vm.longitude ?? 0,
                        isRaining: vm.isRaining,
                        temperature: vm.temperature,
                        icon: vm.icon,
                        date: selectedDate ?? vm.currentDate
                    )
                } label: {
                    ActionCardView(
                        title: "Outfit ideas\nfor the Weather",
                        symbol: "cloud.sun",
                        gradient: [.brandBlue, .brandGreen],
                        textColor: .black,
                        height: cardHeight
                    )
                }

                NavigationLink {
                    let uid = Auth.auth().currentUser?.uid ?? "demo-user"
                    DressCodeSuggestionView(userId: uid)   // <-- correct initializer
                } label: {
                    ActionCardView(
                        title: "Outfit ideas\nfor the dress code",
                        symbol: "tshirt",
                        gradient: [.brandGreen, .brandYellow],
                        textColor: .black,
                        height: cardHeight
                    )
                }
                
                NavigationLink {
                    PromptSuggestionView(userId: Auth.auth().currentUser?.uid ?? "demo-user")
                } label: {
                    ActionCardView(
                        title: "Prompt based\noutfit suggestions",
                        symbol: "sparkles.rectangle.stack",
                        gradient: [.brandOrange, .brandYellow],
                        textColor: .black,
                        height: cardHeight
                    )
                }
                
                NavigationLink {
                    ManualSuggestionView(userId: Auth.auth().currentUser?.uid ?? "")
                } label: {
                    ActionCardView(
                        title: "Manual outfit\ncreation",
                        symbol: "square.and.pencil",
                        gradient: [.brandPink, .brandPeach],
                        textColor: .black,
                        height: cardHeight
                    )
                }
            }
        }
        .padding(20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(Color.brandDarkGrey)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
    
    // MARK: Haptic
    private func haptic() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
    }
}

// MARK: - Subviews

private struct DayChip: View {
    let date: Date
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            Text(weekdayShortFormatter.string(from: date).uppercased())
                .font(AppFont.agdasima(size: 18))
            Text(dayNumberFormatter.string(from: date))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .opacity(0.85)
        }
        .frame(width: 50, height: 60)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.95) : .black.opacity(0.08),
                              lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06),
                radius: 0,
                y: isSelected ? 3 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            let df = DateFormatter(); df.dateStyle = .full
            return (isSelected ? "Selected, " : "") + df.string(from: date)
        }())
    }
    
    private var background: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LinearGradient(colors: [.brandPink.opacity(0.95), .brandPurple.opacity(0.85)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        } else if Calendar.current.isDateInToday(date) {
            return AnyShapeStyle(LinearGradient(colors: [.brandYellow.opacity(0.9), .brandPeach.opacity(0.85)],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            return AnyShapeStyle(Color.brandGrey)
        }
    }
}

/// Pure visual card (no nested Button) so NavigationLink is the tap target.
private struct ActionCardView: View {
    let title: String
    let symbol: String
    let gradient: [Color]
    var textColor: Color = .black
    var height: CGFloat = 220
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
            
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 0, style: .continuous))
                
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }
            .padding(14)
        }
        .frame(height: height)
        .frame(maxWidth: 140)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
    }
}

// MARK: - Formatters
private let fullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEEE, d MMMM yyyy")
    return f
}()
private let dayNumberFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("d")
    return f
}()
private let weekdayShortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEE")
    return f
}()
private let monthShortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("MMM")
    return f
}()

// MARK: - Preview
struct MagicView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack { MagicView() }
            .previewDisplayName("MagicView — Light")
    }
}
