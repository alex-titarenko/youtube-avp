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
    @State private var canGoBack = false
    @State private var isSettingsPresented = false
    @State private var isNavExpanded = false

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
            styleSheets: []//Self.stylesheets
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
                        if let back = page.backForwardList.backList.last {
                            _ = page.load(back)
                        }
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!canGoBack)

                    Button {
                        page.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                .padding(12)
                .glassBackgroundEffect()
            }
            .ornament(attachmentAnchor: .scene(.leading)) {
                VStack(alignment: .leading, spacing: 16) {
                    Button { navigate(to: Self.homeURL) } label: {
                        Label("Home", systemImage: "house")
                    }
                    Button { navigate(to: "https://www.youtube.com/playlist?list=WL") } label: {
                        Label("Watch Later", systemImage: "clock")
                    }
                    Button { navigate(to: "https://www.youtube.com/feed/playlists") } label: {
                        Label("Playlists", systemImage: "rectangle.stack")
                    }
                    Button { navigate(to: "https://www.youtube.com/feed/downloads") } label: {
                        Label("Downloads", systemImage: "arrow.down.circle")
                    }
                }
                .labelStyle(AdaptiveLabelStyle(showsTitle: isNavExpanded))
                .animation(.easeInOut(duration: 0.2), value: isNavExpanded)
                .padding(12)
                .glassBackgroundEffect()
                .onHover { hovering in
                    isNavExpanded = hovering
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                YouTubeSettingsView(userAgentRaw: $userAgentRaw)
            }
            .onChange(of: userAgentRaw) { _, _ in
                page.customUserAgent = userAgent.userAgentString
                if let url = page.url {
                    page.load(URLRequest(url: url))
                }
            }
            .onChange(of: page.url) { _, _ in
                canGoBack = !page.backForwardList.backList.isEmpty
            }
    }

    private func navigate(to urlString: String) {
        if let url = URL(string: urlString) {
            page.load(URLRequest(url: url))
        }
    }

    private static func makePage(from model: WebViewModel) -> WebPage {
        var configuration = WebPage.Configuration()
        configuration.limitsNavigationsToAppBoundDomains = true
        configuration.mediaPlaybackBehavior = .allowsInlinePlayback
        configuration.allowsAirPlayForMediaPlayback = true

        let userContentController = WKUserContentController()

        userContentController.addUserScript(Self.makeFullscreenRedirectScript())
        userContentController.addUserScript(Self.makeFullscreenExitRepaintScript())

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

    /// Routes `Element.requestFullscreen` calls on non-`<video>` elements (e.g. YouTube's
    /// player container) down to the underlying `<video>`, so fullscreen goes through
    /// visionOS's native AVPlayerViewController path instead of the broken element-fullscreen path.
    private static func makeFullscreenRedirectScript() -> WKUserScript {
        let source = """
        (function() {
            function findVideo(el) {
                if (!el) return document.querySelector('video');
                if (el.tagName === 'VIDEO') return el;
                return el.querySelector('video') || document.querySelector('video');
            }
            const origRequest = Element.prototype.requestFullscreen;
            if (origRequest) {
                Element.prototype.requestFullscreen = function(options) {
                    const v = findVideo(this);
                    if (v && v !== this) return origRequest.call(v, options);
                    return origRequest.call(this, options);
                };
            }
            const origWebkitRequest = Element.prototype.webkitRequestFullscreen;
            if (origWebkitRequest) {
                Element.prototype.webkitRequestFullscreen = function(options) {
                    const v = findVideo(this);
                    if (v && v !== this) return origWebkitRequest.call(v, options);
                    return origWebkitRequest.call(this, options);
                };
            }
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }

    /// On fullscreen exit, forces the `<video>` element's compositing layer to reattach.
    /// Without this, visionOS WebKit leaves the video layer detached — audio keeps playing
    /// but the video frame stays blank in the inline player.
    private static func makeFullscreenExitRepaintScript() -> WKUserScript {
        let source = """
        (function() {
            function nudge() {
                document.querySelectorAll('video').forEach(function(v) {
                    const prev = v.style.transform;
                    v.style.transform = 'translateZ(0)';
                    requestAnimationFrame(function() {
                        v.style.transform = prev;
                        void v.offsetHeight;
                    });
                });
                window.dispatchEvent(new Event('resize'));
            }
            function onExit() {
                if (!document.fullscreenElement && !document.webkitFullscreenElement) {
                    nudge();
                }
            }
            document.addEventListener('fullscreenchange', onExit, true);
            document.addEventListener('webkitfullscreenchange', onExit, true);
            document.addEventListener('webkitendfullscreen', nudge, true);
        })();
        """
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
}

private struct AdaptiveLabelStyle: LabelStyle {
    var showsTitle: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.icon
            if showsTitle {
                configuration.title
            }
        }
    }
}
