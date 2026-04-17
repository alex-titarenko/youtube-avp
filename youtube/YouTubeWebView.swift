//
//  YouTubeWebView.swift
//  youtube
//

import SwiftUI
import WebKit

struct YouTubeWebView: View {
    private static let homeURL = "https://www.youtube.com/"

    private static let stylesheets: [String] = [
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

    @AppStorage("userAgentOption") private var userAgentRaw: String =
        UserAgentOption.systemDefault.rawValue

    @State private var page: WebPage

    init(initialURL: String? = nil) {
        let url: String
        if let initialURL, initialURL.hasPrefix(Self.homeURL) {
            url = initialURL
        } else {
            url = Self.homeURL
        }

        let stored = UserDefaults.standard.string(forKey: "userAgentOption")
            .flatMap(UserAgentOption.init(rawValue:)) ?? .systemDefault

        let model = WebViewModel(
            url: url,
            userAgent: stored.userAgentString,
            styleSheets: Self.stylesheets
        )
        _page = State(wrappedValue: Self.makePage(from: model))
    }

    private var userAgent: UserAgentOption {
        UserAgentOption(rawValue: userAgentRaw) ?? .systemDefault
    }

    var body: some View {
        WebView(page)
            .webViewElementFullscreenBehavior(.enabled)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                HStack(spacing: 16) {
                    Button {
                        page.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Picker("User Agent", selection: $userAgentRaw) {
                        ForEach(UserAgentOption.allCases) { option in
                            Text(option.displayName).tag(option.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(12)
                .glassBackgroundEffect()
            }
            .onChange(of: userAgentRaw) { _, _ in
                page.customUserAgent = userAgent.userAgentString
                if let url = page.url {
                    page.load(URLRequest(url: url))
                }
            }
    }

    private static func makePage(from model: WebViewModel) -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.limitsNavigationsToAppBoundDomains = true
        configuration.mediaPlaybackBehavior = .allowsInlinePlayback
        configuration.allowsAirPlayForMediaPlayback = true

        let userContentController = WKUserContentController()

        let standaloneScript = WKUserScript(
            source: "Object.defineProperty(navigator, 'standalone', { get: () => true, configurable: true });",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        userContentController.addUserScript(standaloneScript)

        for styleSheet in model.styleSheets {
            let normalizedStyleSheet = styleSheet.replacingOccurrences(of: "\n", with: "")

            let script = """
              var style = document.createElement('style');
              style.innerHTML = '\(normalizedStyleSheet)';
              document.head.appendChild(style);
            """

            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }

        for script in model.scripts {
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }

        configuration.userContentController = userContentController

        let page = WebPage(configuration: configuration)

        if let userAgent = model.userAgent {
            page.customUserAgent = userAgent
        }

        #if DEBUG
        page.isInspectable = true
        #endif

        if let url = URL(string: model.url) {
            page.load(URLRequest(url: url))
        }

        return page
    }
}
