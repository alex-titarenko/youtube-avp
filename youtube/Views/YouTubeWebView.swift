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
        """,
    ]

    @AppStorage(SettingsKeys.userAgentOption)
    private var userAgentRaw: String = UserAgentOption.systemDefault.rawValue
    
    @AppStorage(SettingsKeys.disableTextSelection)
    private var disableTextSelection: Bool = true

    private enum NavItem: String, Hashable, CaseIterable {
        case home, watchLater, playlists, downloads

        var title: String {
            switch self {
            case .home: "Home"
            case .watchLater: "Watch Later"
            case .playlists: "Playlists"
            case .downloads: "Downloads"
            }
        }

        var systemImage: String {
            switch self {
            case .home: "house"
            case .watchLater: "clock"
            case .playlists: "rectangle.stack"
            case .downloads: "arrow.down.circle"
            }
        }

        var url: String {
            switch self {
            case .home: "https://www.youtube.com/"
            case .watchLater: "https://www.youtube.com/playlist?list=WL"
            case .playlists: "https://www.youtube.com/feed/playlists"
            case .downloads: "https://www.youtube.com/feed/downloads"
            }
        }
    }

    @State private var page: WebPage
    @State private var canGoBack = false
    @State private var isSettingsPresented = false
    @State private var navSelection: NavItem = .home

    init(initialURL: String? = nil) {
        let url: String
        if let initialURL, initialURL.hasPrefix(Self.homeURL) {
            url = initialURL
        } else {
            url = Self.homeURL
        }

        let stored = UserDefaults.standard.string(forKey: SettingsKeys.userAgentOption)
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
        TabView(selection: $navSelection) {
            ForEach(NavItem.allCases, id: \.self) { item in
                Tab(item.title, systemImage: item.systemImage, value: item) {
                    EmptyView()
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .overlay {
            WebView(page)
                .webViewElementFullscreenBehavior(.enabled)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
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
        }
        .onChange(of: navSelection) { _, newValue in
            navigate(to: newValue.url)
        }
        .sheet(isPresented: $isSettingsPresented) {
            YouTubeSettingsView()
        }
        .onChange(of: userAgentRaw) { _, _ in
            page.customUserAgent = userAgent.userAgentString
            if let url = page.url {
                page.load(URLRequest(url: url))
            }
        }
        .onChange(of: disableTextSelection) { _, _ in
            applyTextSelectionSetting()
        }
        .onChange(of: page.url) { _, _ in
            canGoBack = !page.backForwardList.backList.isEmpty
            applyTextSelectionSetting()
        }
        .task {
            applyTextSelectionSetting()
        }
    }

    private func applyTextSelectionSetting() {
        let js = disableTextSelection ? Self.addNoSelectStyleJS : Self.removeNoSelectStyleJS
        Task { try? await page.callJavaScript(js) }
    }

    private static let addNoSelectStyleJS = """
    (function() {
        var id = 'avp-no-select-style';
        if (document.getElementById(id)) return;
        var s = document.createElement('style');
        s.id = id;
        s.textContent = '*, *::before, *::after { user-select: none !important; -webkit-user-select: none !important; -webkit-touch-callout: none !important; }';
        (document.head || document.documentElement).appendChild(s);
    })();
    """

    private static let removeNoSelectStyleJS = """
    (function() {
        var s = document.getElementById('avp-no-select-style');
        if (s) s.remove();
    })();
    """

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

        let initialDisableSelection =
            UserDefaults.standard.object(forKey: SettingsKeys.disableTextSelection) as? Bool ?? true
        if initialDisableSelection {
            userContentController.addUserScript(Self.makeDisableSelectionScript())
        }

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

    private static func makeDisableSelectionScript() -> WKUserScript {
        WKUserScript(source: addNoSelectStyleJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
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
