//
//  YouTubeSettingsView.swift
//  youtube
//
//  Created by Alex Titarenko on 4/17/26.
//


import SwiftUI
import WebKit

struct YouTubeSettingsView: View {
    @Binding var userAgentRaw: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("User Agent", selection: $userAgentRaw) {
                    ForEach(UserAgentOption.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
