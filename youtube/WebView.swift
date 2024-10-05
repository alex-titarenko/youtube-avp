//
//  WebView.swift
//  youtube
//
//  Created by Alex Titarenko on 9/22/24.
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    typealias UIViewType = WKWebView
    
    @ObservedObject var webViewModel: WebViewModel
    
    func makeUIView(context: Context) -> UIViewType {
        return self.makeWebView(context: context)
    }
     
    func updateUIView(_ uiView: WKWebView, context: Context) {
        print("updateUIView")
    }
    
    
    func makeWebView(context: Context) -> WKWebView {
        guard let url = URL(string: self.webViewModel.url) else {
            return WKWebView()
        }
        
        let config = WKWebViewConfiguration()
        
        config.limitsNavigationsToAppBoundDomains = true
        config.allowsInlineMediaPlayback = true
        config.preferences.isElementFullscreenEnabled = true
        config.preferences.setValue(true, forKey: "standalone")
        
        let userContentController = WKUserContentController()
        for styleSheet in self.webViewModel.styleSheets {
            let normalizedStyleSheet = styleSheet.replacingOccurrences(of: "\n", with: "")
            
            let script = """
              var style = document.createElement('style');
              style.innerHTML = '\(normalizedStyleSheet)';
              document.head.appendChild(style);
            """

            let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }

        for script in self.webViewModel.scripts {
            let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            userContentController.addUserScript(userScript)
        }

        config.userContentController = userContentController
        
        let request = URLRequest(url: url)
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.customUserAgent = self.webViewModel.userAgent
        
        webView.load(request)
        
        #if DEBUG
        if #available(iOS 16.4, macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif
        
        return webView
    }
    
    /**
     This is needed to fix fullscreen elements
     https://developer.apple.com/forums/thread/720612
    */
    static func wrapIntoView(_ childView: UIView) -> UIView {
        childView.translatesAutoresizingMaskIntoConstraints = true

        // Note: This actually not fixing the issue in iOS/iPadOS
        childView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let wrapView = UIView()
        wrapView.translatesAutoresizingMaskIntoConstraints = true
        wrapView.addSubview(childView)
        return wrapView
    }

    static func unwrapFromView<T: UIView>(_ parentView: UIView) -> T {
        return parentView.subviews[0] as! T
    }
}
