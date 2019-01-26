//
//  WebViewManager.swift
//  browse
//
//  Created by Evan Brooks on 3/17/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//
//  Stores a mapping between Tab (persistent) and WKWebview (recreated)

import UIKit
import WebKit

typealias BrowseLoadingHandler = (WKScriptMessage) -> Void

let USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 12_1 like Mac OS X) AppleWebKit/602.1.38 (KHTML, like Gecko) Version/12.7.7 Mobile/14A5297c Safari/602.1"

class WebViewManager: NSObject {
    private var webViewMap: [ Tab: WKWebView ] = [:]
    private var blocker = Blocker()
    private var baseConfiguration: WKWebViewConfiguration!

    var loadingHandler: BrowseLoadingHandler?

    override init() {
        super.init()
        baseConfiguration = createBaseConfiguration()
        blocker.getRules { lists in
            lists.forEach {
                self.baseConfiguration.userContentController.add($0)
                for (_, existingWebView) in self.webViewMap { // in case we already have some
                    existingWebView.configuration.userContentController.add($0)
                }
            }
        }
    }

    func createBaseConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(
            WKUserScript(source: checkFixedFunc, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        let loadAlerterStr = """
            document.addEventListener("DOMContentLoaded", () => {
                console.log("hey")
                window.webkit.messageHandlers["\(browseLoadHandlerName)"].postMessage("DOMContentLoaded");
            });
        """
        let readyStateStr = """
            document.onreadystatechange = () => {
                if (document.readyState === "interactive") {
                    window.webkit.messageHandlers["\(browseLoadHandlerName)"].postMessage("interactive");
                }
            }
        """

        configuration.userContentController.addUserScript(
            WKUserScript(source: readyStateStr, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        )
        configuration.userContentController.add(self, name: browseLoadHandlerName)
        return configuration
    }

    func webViewFor(_ tab: Tab) -> WKWebView {
        if let existing = webViewMap[tab] {
            return existing
        } else {
            let newWebView = createWebView(with: baseConfiguration)
            webViewMap[tab] = newWebView
            return newWebView
        }
    }

    func removeWebViewFor(_ tab: Tab) {
        webViewMap.removeValue(forKey: tab)
    }

    func addWebView(for tab: Tab, with config: WKWebViewConfiguration) -> WKWebView {
        let newWebView = createWebView(with: config)
        webViewMap[tab] = newWebView
        return newWebView
    }

    private func createWebView(with config: WKWebViewConfiguration) -> WKWebView {
        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInset = .zero
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.clipsToBounds = false
        webView.scrollView.alwaysBounceHorizontal = true
        webView.allowsLinkPreview = false
        webView.customUserAgent = USER_AGENT

        return webView
    }
}

let browseLoadHandlerName = "browseLoadEvent"

extension WebViewManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == browseLoadHandlerName {
            loadingHandler?(message)
        }
    }
}

struct FixedNavResult {
    let top: Bool
    let bottom: Bool
}
extension WKWebView {
    func evaluateFixedNav(_ completionHandler: @escaping (FixedNavResult) -> Void) {
        evaluateJavaScript("window.\(checkFixedFuncName)()") { (result, _) in
            if let dict = result as? [String: Bool],
                let top = dict["top"],
                let bottom = dict["bottom"] {
                completionHandler(FixedNavResult(top: top, bottom: bottom))
            }
        }
    }
}

private let checkFixedFuncName = "__BROWSE_HAS_FIXED_NAV__"
private let checkFixedFunc = """
    (function() {
        const isFixed = (elm) => {
            let el = elm;
            while (typeof el === 'object' && el.nodeName.toLowerCase() !== 'body') {
                const pos = window.getComputedStyle(el).getPropertyValue('position').toLowerCase()
                if (pos === 'fixed' || pos === 'sticky' || pos === '-webkit-sticky') return true;
                el = el.parentElement;
            }
            return false;
        };
        window.\(checkFixedFuncName) = () => {
            return {
                top: isFixed(document.elementFromPoint(1,1)),
                bottom: isFixed(document.elementFromPoint(1,window.innerHeight - 1))
            }
        };
    })();
"""
