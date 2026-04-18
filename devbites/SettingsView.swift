//
//  SettingsView.swift
//  devbites
//

import SwiftUI

struct SettingsView: View {
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                }

                Section {
                    Text("Kernel surfaces curated engineering reads in a calm, focused feed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.navChrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

#Preview {
    SettingsView()
}
