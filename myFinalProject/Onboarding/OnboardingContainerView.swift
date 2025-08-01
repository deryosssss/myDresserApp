//
//  OnboardingContainerView.swift
//  myDresser
//
//  Created by Derya Baglan on 28/07/2025.
//

import SwiftUI

struct OnboardingContainerView: View {
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            Image("onboardingGradient")
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { idx in
                    OnboardingPageView(
                        content: onboardingPages[idx],
                        totalPages: onboardingPages.count,
                        currentPage: idx
                    )
                    .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
    }
}


struct OnboardingContainerView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingContainerView()
    }
}
