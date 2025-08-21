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

/// Landing screen for "magic" creation flows:
/// - shows today's weather + quick week picker
/// - offers 4 big entry points (manual, prompt, dress code, weather)
/// - passes user/location/date context into each flow
struct MagicView: View {
    @StateObject private var vm = MagicViewModel()        // screen data (weather, week dates, etc.)
    @State private var selectedDate: Date? = nil          // chip-selected day (nil → today)
    @State private var hasAutoScrolled = false            // ensure we center "today" only once
    
    var body: some View {
        GeometryReader { geo in
            // Compute a responsive card height from the available viewport.
            let h = geo.size.height
            let cardHeight = max(200, min(280, h * 0.27)) // clamp to 200…280
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    dayScroller
                    actionBoard(cardHeight: cardHeight)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
            .background(Color.white.ignoresSafeArea())
        }
    }
    
    // MARK: Header (weather + selected date)
    /// Shows current weather icon/temperature and the selected (or current) date.
    private var header: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = vm.icon {
                    icon.resizable().frame(width: 50, height: 50)
                } else {
                    // Fallback SF Symbol in case we don't have an icon yet
                    Image(systemName: "cloud.sun")
                        .symbolRenderingMode(.multicolor)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.temperature)
                    .font(AppFont.spicyRice(size: 36))
                // If user tapped a day chip, show that date; otherwise show "today"
                Text((selectedDate ?? vm.currentDate), formatter: fullDateFormatter)
                    .font(AppFont.spicyRice(size: 20))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
    
    
    // MARK: Week scroller (Mon–Sun chips)
    /// Horizontally scrollable week with a centered auto-scroll to today.
    /// Uses ScrollViewReader so we can programmatically position the "today" chip.
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
    /// The four entry points. Each card is a pure visual view so the NavigationLink is the tap target.
    /// We pass in the current userID and relevant context (weather/location/date) where needed.
    private func actionBoard(cardHeight: CGFloat) -> some View {
        VStack(spacing: 12) {
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 0),
                          GridItem(.flexible(), spacing: 0)],
                spacing: 15
            ) {
                // 1) Manual creation
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
                
                // 2) Prompt-based suggestions (local parsing)
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
                
                // 3) Dress code suggestions
                NavigationLink {
                    let uid = Auth.auth().currentUser?.uid ?? "demo-user"
                    DressCodeSuggestionView(userId: uid)   // keep initializer explicit for clarity
                } label: {
                    ActionCardView(
                        title: "Outfit ideas\nfor the dress code",
                        symbol: "tshirt",
                        gradient: [.brandGreen, .brandYellow],
                        textColor: .black,
                        height: cardHeight
                    )
                }
                
                // 4) Weather-aware suggestions (inject weather + location + date)
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
            }
        }
        .padding(20)
        .padding(.vertical, 20)
        .background(
            // Large neutral container that makes the colored cards pop
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.brandDarkGrey)
        )
        .overlay(
            // Subtle stroke for definition on light/dark backgrounds
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
    
    // MARK: Haptic
    /// Light feedback when selecting a date chip.
    private func haptic() {
#if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
#endif
    }
}

// MARK: - Subviews

/// A compact day chip: weekday + day number, with 3 background states:
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
            // White border when selected; faint border otherwise for shape definition
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(isSelected ? .white.opacity(0.95) : .black.opacity(0.08),
                              lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(isSelected ? 0.12 : 0.06),
                radius: 10,
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

private struct ActionCardView: View {
    let title: String
    let symbol: String
    let gradient: [Color]
    var textColor: Color = .black
    var height: CGFloat = 220
    
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.35), lineWidth: 1)
            
            VStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol)
                    .imageScale(.large)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.black)
                    .padding(10)
                    .background(.ultraThinMaterial,
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                
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
        .frame(maxWidth: 140) // keep a tidy two-up grid
        .shadow(color: .black.opacity(0.12), radius: 8, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.replacingOccurrences(of: "\n", with: " "))
    }
}

// MARK: - Formatters
/// Localized long date for header subtitle (e.g., "Wednesday, 20 August 2025").
private let fullDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEEE, d MMMM yyyy")
    return f
}()
/// Day number (1–31) used inside chips.
private let dayNumberFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("d")
    return f
}()
/// Short weekday ("Mon", "Tue", …) used on chips.
private let weekdayShortFormatter: DateFormatter = {
    let f = DateFormatter()
    f.setLocalizedDateFormatFromTemplate("EEE")
    return f
}()
/// Not used here, but kept for consistency with other screens.
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

