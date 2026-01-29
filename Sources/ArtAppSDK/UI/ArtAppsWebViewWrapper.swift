import SwiftUI
import WebKit

struct ArtAppsWebViewWrapper: UIViewRepresentable {
    let url: URL
    let onLoad: () -> Void
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    @MainActor
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: ArtAppsWebViewWrapper
        
        init(parent: ArtAppsWebViewWrapper) {
            self.parent = parent
        }
        
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                return .cancel
            }
            return .allow
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.onLoad()
        }
    }
}
