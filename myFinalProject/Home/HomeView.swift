//
//  HomeView.swift
//  myDresser
//
//  Created by Derya Baglan on 30/07/2025.
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    // Use your existing VMs
    @EnvironmentObject private var wardrobeVM: WardrobeViewModel
    @StateObject private var profileVM = ProfileViewModel()
    
    // Sheets
    @State private var showManualSheet = false
    @State private var showAISheet = false
    
    // Payloads for sheets
    @State private var manualStartPinned: WardrobeItem? = nil
    @State private var aiInitialPrompt: String? = nil
    
    // Challenge
    @State private var challengeText: String = "Tap spin to get today’s style challenge!"
    @State private var spinning = false
    @State private var challengeFocusItem: WardrobeItem? = nil
    @State private var challengeImages: [String] = []
    
    // Info popovers
    @State private var showStreakInfo = false
    @State private var showDiversityInfo = false
    @State private var showBadgesInfo = false
    
    // Usage window
    enum Window: String, CaseIterable, Identifiable {
        case all = "All", d90 = "90d", d30 = "30d"
        var id: String { rawValue }
        var days: Int? { self == .all ? nil : (self == .d90 ? 90 : 30) }
    }
    @State private var window: Window = .d90
    
    // MARK: - Layout tokens
    enum UX {
        static let sectionGap: CGFloat = 16
        static let cardCorner: CGFloat = 12
        static let cardPadding: CGFloat = 12
        static let thumb = CGSize(width: 120, height: 120)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: UX.sectionGap) {
                    
                    // Greeting + monthly summary + streak (tap for info)
                    greetingCard
                    
                    // CO2 estimate this month
                    co2Card
                    
                    // New items (latest 6)
                    HomeSectionCard(title: "New Items!") {
                        if recentItems.isEmpty {
                            HomeEmptyRow(text: "No items yet")
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(recentItems, id: \.id) { item in
                                        NavigationLink {
                                            ItemDetailView(item: item, wardrobeVM: wardrobeVM, onDelete: { })
                                        } label: {
                                            ItemTile(url: item.imageURL)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    // Style diversity (with ⓘ definition)
                    HomeSectionCard(title: "Style diversity", accessory: {
                        Button { showDiversityInfo = true } label: {
                            Image(systemName: "info.circle").foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("What is style diversity?")
                    }) {
                        HStack(alignment: .center) {
                            DiversityBadge(level: diversityLevel)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(diversityCopy)
                                    .font(AppFont.agdasima(size: 18))
                                ProgressView(value: diversityScore)
                                    .tint(diversityColor)
                                    .animation(.easeInOut(duration: 0.3), value: diversityScore)
                            }
                            Spacer()
                        }
                    }
                    .popover(isPresented: $showDiversityInfo) {
                        DefinitionPopover(
                            title: "Style diversity",
                            definition: """
                            Measures the variety of **categories you actually wore** in the selected window.
                            
                            We compute a diversity index across items in your outfits (e.g. Tops, Bottoms, Outerwear, Shoes, Accessories). Higher = more variety.
                            """
                        )
                        .frame(maxWidth: 360)
                        .padding()
                    }
                    
                    // Usage + Unused in window
                    usageCard
                    
                    // Playful challenge (image centered + purple "Challenge accepted")
                    challengeCard
                    
                    // Badges (with definitions sheet)
                    HomeSectionCard(title: "Badges", accessory: {
                        Button { showBadgesInfo = true } label: {
                            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("What do badges mean?")
                    }) {
                        HStack(spacing: 12) {
                            BadgeView(title: "Starter",    system: "tshirt",        achieved: wardrobeVM.items.count >= 1)
                            BadgeView(title: "Builder",    system: "tshirt.fill",   achieved: wardrobeVM.items.count >= 15)
                            BadgeView(title: "Outfit Pro", system: "sparkles",      achieved: outfitsThisMonth >= 12)
                            BadgeView(title: "Eco Hero",   system: "leaf.fill",     achieved: co2SavedThisMonth >= 10)
                            BadgeView(title: "Streak 5",   system: "flame.fill",    achieved: streak7 >= 5)
                        }
                    }
                    .sheet(isPresented: $showBadgesInfo) {
                        BadgeDefinitionsSheet(
                            outfitsThisMonth: outfitsThisMonth,
                            co2ThisMonth: co2SavedThisMonth,
                            itemsCount: wardrobeVM.items.count,
                            streak7: streak7
                        )
                    }
                    
                    // Bottom CTA → Magic (AI) view
                    footerMagicCTA
                    
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                wardrobeVM.startAllOutfitsListener()
            }
            .task {
                wardrobeVM.startAllOutfitsListener()
            }
            // Sheets (hook these to your real flows)
            .sheet(isPresented: $showManualSheet) {
                ManualCreateSheet(userId: authUID, startPinned: manualStartPinned)
            }
            .sheet(isPresented: $showAISheet) {
                AIStylistSheet(userId: authUID, initialPrompt: aiInitialPrompt)
            }
        }
    }
}

// MARK: - Cards

private extension HomeView {
    var greetingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Optional avatar
                Group {
                    if let img = profileVM.profileImage {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(Color.brandPeach)
                            Text(initials(profileVM.username))
                                .font(.title2.bold())
                                .foregroundColor(.black)
                        }
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 2))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi, \(displayName)")
                        .font(AppFont.spicyRice(size: 26))
                        .foregroundColor(.black)
                    Text(monthlyHeadline)
                        .font(AppFont.agdasima(size: 18))
                        .foregroundColor(.black.opacity(0.8))
                }
                Spacer()
                // 7-day streak (tap to explain)
                VStack(spacing: 2) {
                    Text("Streak").font(.caption).foregroundStyle(.secondary)
                    Text("\(streak7)🔥").font(.headline)
                }
                .padding(8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .onTapGesture { showStreakInfo = true }
                .popover(isPresented: $showStreakInfo) {
                    DefinitionPopover(
                        title: "Your streak",
                        definition: """
                        Counts consecutive days (up to 7) you **logged at least one outfit**. If yesterday had an outfit but today not yet, we still show your streak continuing.
                        """
                    )
                    .frame(maxWidth: 360)
                    .padding()
                }
                .accessibilityLabel("Streak \(streak7) days. Double tap for info.")
            }
        }
        .padding(UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [
                Color.pink.opacity(0.35),
                Color.yellow.opacity(0.35),
                Color.purple.opacity(0.35)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: UX.cardCorner))
    }
    
    var co2Card: some View {
        let kg = co2SavedThisMonth
        return HStack {
            Text("We estimate you saved")
            Spacer()
            Text(String(format: "%.1f kg CO₂", kg))
                .font(AppFont.spicyRice(size: 20))
        }
        .foregroundColor(.black)
        .padding(UX.cardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.brandYellow)
        .clipShape(RoundedRectangle(cornerRadius: UX.cardCorner))
        .accessibilityLabel("Estimated carbon saved this month \(kg, specifier: "%.1f") kilograms")
    }
    
    var usageCard: some View {
        HomeSectionCard(title: "Your usage") {
            VStack(alignment: .leading, spacing: 10) {
                // Window picker
                Picker("", selection: $window) {
                    ForEach(Window.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("\(usedItemIDs.count) used")
                        .foregroundStyle(.secondary)
                    Text("·").foregroundStyle(.secondary)
                    Text("\(max(wardrobeVM.items.count - usedItemIDs.count, 0)) not used")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(usagePercent)%")
                        .font(.headline)
                }
                
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 22)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.brandGreen.opacity(0.7))
                            .frame(width: geo.size.width * CGFloat(usagePercent) / 100, height: 22)
                            .animation(.easeInOut(duration: 0.4), value: usagePercent)
                    }
                }
                .frame(height: 22)
                
                // Unused 90d quick stat (independent of picker to mirror your mock)
                HStack {
                    Text("Unused for 90 days:")
                    Spacer()
                    Text("\(unused90Count) items")
                        .font(AppFont.spicyRice(size: 18))
                }
            }
        }
    }
    
    var challengeCard: some View {
        HomeSectionCard(title: "Spin a challenge") {
            VStack(spacing: 12) {
                Text(challengeText)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                
                // Centered preview image if we focused a specific item
                if let url = challengeImages.first {
                    HStack {
                        Spacer()
                        ItemTile(url: url)
                            .frame(width: 160, height: 200)
                        Spacer()
                    }
                }
                
                // Spin for a new challenge
                Button {
                    spinChallenge()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .rotationEffect(.degrees(spinning ? 360 : 0))
                            .animation(.linear(duration: 0.6), value: spinning)
                        Text("Spin")
                            .font(AppFont.spicyRice(size: 18))
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.brandPeach)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // Purple CTA → Manual creator with pinned item (only when we have a focus item)
                if let focus = challengeFocusItem {
                    Button {
                        manualStartPinned = focus
                        showManualSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Challenge accepted · Create outfit")
                                .font(AppFont.spicyRice(size: 18))
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.brandPurple)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
    }
    
    // Bottom single CTA → Magic (AI) view
    var footerMagicCTA: some View {
        Button {
            if let focus = challengeFocusItem {
                let coloursList = focus.colours.joined(separator: ", ")
                aiInitialPrompt = "Create an outfit featuring my \(focus.category) \(focus.subcategory). Prefer colors \(coloursList). Use items from my wardrobe."
            } else {
                aiInitialPrompt = "Create an outfit using my wardrobe."
            }
            showAISheet = true
        } label: {
            Text("Create outfits")
                .font(AppFont.spicyRice(size: 18))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.brandBlue)
                .foregroundColor(.black)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Derived data

private extension HomeView {
    var authUID: String {
        Auth.auth().currentUser?.uid ?? "unknown"
    }

    var displayName: String {
        let n = profileVM.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Username" : n
    }

    var monthStart: Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: Date())
        return cal.date(from: comps) ?? Date()
    }

    var outfitsThisMonth: Int {
        wardrobeVM.allOutfits.filter { ($0.createdAt ?? .distantPast) >= monthStart }.count
    }

    var monthlyHeadline: String {
        "Well done – you wore \(outfitsThisMonth) outfit\(outfitsThisMonth == 1 ? "" : "s") this month!"
    }

    /// quick estimation: 0.8 kg per re-wear
    var co2SavedThisMonth: Double {
        Double(outfitsThisMonth) * 0.8
    }

    var recentItems: [WardrobeItem] {
        wardrobeVM.items
            .sorted { ($0.addedAt ?? .distantPast) > ($1.addedAt ?? .distantPast) }
            .prefix(6).map { $0 }
    }

    // Window-filtered outfits for usage/diversity
    var filteredOutfits: [Outfit] {
        guard let days = window.days else { return wardrobeVM.allOutfits }
        let from = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
        return wardrobeVM.allOutfits.filter { o in
            // include undated outfits so usage doesn’t appear as 0
            guard let d = o.createdAt else { return true }
            return d >= from
        }
    }

    var usedItemIDs: Set<String> {
        Set(filteredOutfits.flatMap { $0.itemIds })
    }

    var usagePercent: Int {
        let total = wardrobeVM.items.count
        guard total > 0 else { return 0 }
        let used = wardrobeVM.items.filter { $0.id.map(usedItemIDs.contains) ?? false }.count
        return Int((Double(used) / Double(total) * 100.0).rounded())
    }

    var unused90Count: Int {
        let from = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
        let recentUsed = Set(
            wardrobeVM.allOutfits
                .filter { ($0.createdAt ?? .distantPast) >= from }
                .flatMap { $0.itemIds }
        )
        return wardrobeVM.items.filter { !( $0.id.map(recentUsed.contains) ?? false ) }.count
    }

    // 7-day streak: count consecutive days (ending today or yesterday) with ≥1 outfit
    var streak7: Int {
        let cal = Calendar.current
        let daysSet: Set<Date> = Set(wardrobeVM.allOutfits.compactMap { o in
            guard let d = o.createdAt else { return nil }
            return cal.startOfDay(for: d)
        })
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        for _ in 0..<7 {
            if daysSet.contains(cursor) {
                streak += 1
            } else if daysSet.contains(cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor) && streak == 0 {
                // allow “ended yesterday” to still count forward
                streak += 0
            } else {
                break
            }
            cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    // Diversity: categories used by items in filtered outfits
    var diversityScore: Double {
        let usedIDs = usedItemIDs
        let usedItems = wardrobeVM.items.filter { $0.id.map(usedIDs.contains) ?? false }
        guard !usedItems.isEmpty else { return 0 }
        let groups = Dictionary(grouping: usedItems) { normalizeCategory($0.category) }
        // Simpson diversity index → convert to 0..1 where higher = more diverse
        let n = Double(usedItems.count)
        let sumPi2 = groups.values
            .map { Double($0.count) / n }
            .map { $0 * $0 }
            .reduce(0, +)
        return max(0, min(1, 1 - sumPi2))
    }

    var diversityLevel: String {
        switch diversityScore {
        case ..<0.35: return "Low"
        case ..<0.65: return "Medium"
        default:      return "High"
        }
    }
    var diversityColor: Color {
        switch diversityScore {
        case ..<0.35: return .red.opacity(0.6)
        case ..<0.65: return .orange.opacity(0.7)
        default:      return .green.opacity(0.7)
        }
    }
    var diversityCopy: String {
        "Last \(window.rawValue) variety: \(diversityLevel)"
    }

    // Challenge generator
    func spinChallenge() {
        spinning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            spinning = false

            // Prefer an item not worn in 90 days
            let from = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
            let recentlyUsedIDs = Set(
                wardrobeVM.allOutfits
                    .filter { ($0.createdAt ?? .distantPast) >= from }
                    .flatMap { $0.itemIds }
            )

            let unused90 = wardrobeVM.items.filter { item in
                guard let id = item.id else { return false }
                return !recentlyUsedIDs.contains(id)
            }

            let useItemChallenge = Bool.random() && (!unused90.isEmpty || !wardrobeVM.items.isEmpty)

            if useItemChallenge {
                let pool = unused90.isEmpty ? wardrobeVM.items : unused90
                if let pick = pool.randomElement() {
                    challengeFocusItem = pick
                    challengeImages = [pick.imageURL].compactMap { $0 }
                    challengeText = "Make an outfit with **this item**"
                    return
                }
            }

            let categories = Set(wardrobeVM.items.map { normalizeCategory($0.category) })
            let colours    = Set(wardrobeVM.items.flatMap { $0.colours.map { $0.capitalized } })
            let prompts: [String] = [
                ifLet(categories.randomElement()) { "Wear something from **\($0)**" },
                ifLet(colours.randomElement())    { "Build an outfit around **\($0)**" },
                "Pick one item you haven’t worn in 90 days",
                "Create a look using only two colours",
                "Try a new **layering** combo today"
            ].compactMap { $0 }

            challengeFocusItem = nil
            challengeImages = []
            if let pick = prompts.randomElement() {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    challengeText = pick
                }
            }
        }
    }

    func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    func normalizeCategory(_ raw: String) -> String {
        let c = raw.lowercased()
        if ["top","tops","shirt","blouse","tshirt"].contains(where: c.contains) { return "Top" }
        if ["outerwear","jacket","coat","blazer"].contains(where: c.contains) { return "Outerwear" }
        if ["dress","dresses"].contains(where: c.contains) { return "Dress" }
        if ["bottom","bottoms","pants","trousers","jeans","skirt","shorts","leggings"].contains(where: c.contains) { return "Bottoms" }
        if ["shoes","shoe","footwear","sneaker","boot"].contains(where: c.contains) { return "Shoes" }
        if ["accessory","accessories","jewelry","jewellery"].contains(where: c.contains) { return "Accessories" }
        if ["bag","handbag","purse"].contains(where: c.contains) { return "Bag" }
        return raw.capitalized
    }

    // tiny helper to lift optionals into array literals
    func ifLet<T>(_ value: T?, map: (T) -> String) -> String? {
        value.map(map)
    }
}

// MARK: - Reusable pieces (scoped to this file to avoid clashes)

/// Card container (unique name in this file to avoid re-declarations)
private struct HomeSectionCard<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: Content

    init(title: String,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(AppFont.agdasima(size: 22))
                    .foregroundColor(.black)
                Spacer()
                accessory()
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(HomeView.UX.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: HomeView.UX.cardCorner)
                    .fill(Color(.systemGray6))
            )
        }
    }
}

private struct HomeEmptyRow: View {
    let text: String
    var body: some View {
        HStack { Text(text).foregroundStyle(.secondary); Spacer() }
            .padding(.vertical, 8)
    }
}

private struct ItemTile: View {
    let url: String
    var body: some View {
        ZStack {
            Color.white
            AsyncImage(url: URL(string: url)) { ph in
                switch ph {
                case .success(let img): img.resizable().scaledToFit()
                case .empty: Color.white
                default: Color.white
                }
            }
        }
        .frame(width: HomeView.UX.thumb.width, height: HomeView.UX.thumb.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(.separator), lineWidth: 0.5))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
    }
}

private struct DiversityBadge: View {
    let level: String
    var body: some View {
        Text(level)
            .font(AppFont.spicyRice(size: 18))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                (level == "High" ? Color.green.opacity(0.25) :
                 level == "Medium" ? Color.orange.opacity(0.25) :
                 Color.red.opacity(0.25))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct BadgeView: View {
    let title: String
    let system: String
    let achieved: Bool
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: system)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(achieved ? Color.brandGreen.opacity(0.35) : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(title).font(.caption)
                .foregroundStyle(achieved ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .opacity(achieved ? 1 : 0.6)
    }
}
