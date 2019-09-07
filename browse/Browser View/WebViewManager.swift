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
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: checkFixedFunc,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: getLinkFunc,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: preventTextSelection,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
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
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInset = .zero
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.clipsToBounds = false
//        webView.scrollView.alwaysBounceHorizontal = true
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
    let hasTopNav: Bool
    let hasBottomNav: Bool
}
extension WKWebView {
    func evaluateFixedNav(_ completionHandler: @escaping (FixedNavResult) -> Void) {
        evaluateJavaScript("window.\(checkFixedFuncName)()") { (result, _) in
            if let dict = result as? [String: Bool],
                let top = dict["top"],
                let bottom = dict["bottom"] {
                completionHandler(FixedNavResult(
                    hasTopNav: top,
                    hasBottomNav: bottom))
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

private let findLinkFuncName = "__BROWSE_GET_LINK__"
private let clearLinkFuncName = "__BROWSE__CLEAR_ACTIVE_LINK__"
private let highlightLinkClassName = "__BROWSE_ACTIVE_LINK__"

private let getLinkFunc = """
    (function() {
        window.\(findLinkFuncName) = (x, y) => {
            let el = document.elementFromPoint(x, y);
            if (!el) {
                return "No el";
            }
            // Walk up to find parent with href
            while (
                typeof el === 'object'
                && el.nodeName.toLowerCase() !== 'body'
                && !el.hasAttribute('href')
            ) {
                el = el.parentElement;
            }

            const href = el.getAttribute('href');
            if (!href) {
                return "No href for " + el.tagName;
            }
            el.classList.add('__BROWSE_ACTIVE_LINK__');
            return {
                href: href,
                title: el.getAttribute('title')
            };
        };
        window.\(clearLinkFuncName) = () => {
            const els = document.querySelectorAll('.\(highlightLinkClassName)');
            for (const el of els) {
                el.classList.remove('\(highlightLinkClassName)');
            }
        };
    })();
"""

private let preventTextSelection = """
    const style = document.createElement('style');
    style.type = 'text/css';
    style.innerText = `
        *:not(input):not(textarea) {
            -webkit-user-select: none;
            -webkit-touch-callout: none;
        }
        .\(highlightLinkClassName) {
            background-color: cyan;
        }
    `;
    const head = document.getElementsByTagName('head')[0];
    head.appendChild(style);
"""

struct LinkInfo {
    let href: String
    let title: String?
}

extension WKWebView {
    func linkAt(_ position: CGPoint, completionHandler: @escaping ((LinkInfo?) -> ()) ) {
        
        // Translate gesture point into the coordinate system of the zoomed page
        let scaleFactor = 1 / scrollView.zoomScale
        let pt = CGPoint(x: position.x * scaleFactor, y: position.y * scaleFactor)
        
        self.evaluateJavaScript("window.\(findLinkFuncName)(\(pt.x), \(pt.y))") { (val, err) in
            if let err = err {
                print(err)
            }
            if let dict = val as? [String: String?],
                let href = dict["href"], href != nil,
                let title = dict["title"] {
                completionHandler(LinkInfo(href: href!, title: title))
                return
            }
            
            print("no link info: \(val ?? "Missing val")")
            completionHandler(nil)
        }
    }
    
    func clearHighlightedLinks() {
        self.evaluateJavaScript("window.\(clearLinkFuncName)()") { (val, err) in
            if let err = err {
                print(err)
            }
        }
    }
}
