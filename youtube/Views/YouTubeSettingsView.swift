//
//  YouTubeSettingsView.swift
//  youtube
//
//  Created by Alex Titarenko on 4/17/26.
//


import SwiftUI
import WebKit

struct YouTubeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @AppStorage(SettingsKeys.userAgentOption)
    private var userAgentRaw: String = UserAgentOption.systemDefault.rawValue
    
    @AppStorage(SettingsKeys.disableTextSelection)
    private var disableTextSelection: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Picker("User Agent", selection: $userAgentRaw) {
                    ForEach(UserAgentOption.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                Toggle("Disable Text Selection", isOn: $disableTextSelection)
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
