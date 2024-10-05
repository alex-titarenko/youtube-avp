//
//  ContentView.swift
//  youtube
//
//  Created by Alex Titarenko on 9/22/24.
//

import SwiftUI
import RealityKit

struct ContentView: View {
    let DefaultAppUrl = "https://www.youtube.com/"
    let DefaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0"
        
    @ObservedObject var webViewModel: WebViewModel
    
    init(url: String? = nil) {
        let styleSheets = [
            """
html[dark] {
    background-color: transparent !important;
}

html[dark], [dark] {
    --yt-spec-base-background: transparent !important;
    --ytd-searchbox-background: transparent !important;
}

/* Sidebar */
#guide-content.ytd-app {
    background-color: rgba(0, 0, 0, 0.8);
}

/* Top bar */
#masthead-container {
    backdrop-filter: contrast(0.1);
}

/* Feed filter */
ytd-feed-filter-chip-bar-renderer {
    display: none;
}
""",
        ]
        
        let appUrl = (url != nil && url!.starts(with: DefaultAppUrl)) ? url! : DefaultAppUrl
        self.webViewModel = WebViewModel(
            url: appUrl,
            userAgent: DefaultUserAgent,
            styleSheets: styleSheets
        )
    }
    
    var body: some View {
        WebView(webViewModel: webViewModel)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
