//
//  MainTabView.swift
//  devbites
//

import SwiftUI
import UIKit

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tint(AppTheme.brandOrange)
        .toolbarBackground(AppTheme.navChrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppTheme.navChrome)
            appearance.shadowColor = UIColor(AppTheme.hairline)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    MainTabView()
}
