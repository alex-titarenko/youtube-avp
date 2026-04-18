//
//  ContentView.swift
//  youtube
//
//  Created by Alex Titarenko on 9/22/24.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    let url: String?

    init(url: String? = nil) {
        self.url = url
    }

    var body: some View {
        YouTubeWebView(initialURL: url)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
