//
//  RichWebView.swift
//  youtube
//
//  Created by Alex Titarenko on 9/22/24.
//

import SwiftUI
import WebKit

struct RichWebView: View {
    @State private var page: WebPage

    init(webViewModel: WebViewModel) {
        _page = State(wrappedValue: Self.makePage(from: webViewModel))
    }

    var body: some View {
        WebView(page)
            .webViewContentBackground(.hidden)
    }

    private static func makePage(from model: WebViewModel) -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.limitsNavigationsToAppBoundDomains = true
        configuration.mediaPlaybackBehavior = .allowsInlinePlayback

        let userContentController = WKUserContentController()
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

        // TODO: WKPreferences.isElementFullscreenEnabled has no equivalent on
        // WebPage.Configuration; element fullscreen relies on the WebKit default.

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
