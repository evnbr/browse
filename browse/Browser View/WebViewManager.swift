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

class WebViewManager: NSObject {
    private var webViewMap: [ Tab : WKWebView ] = [:]
    private var blocker = Blocker()
    
    override init() {
        super.init()
        blocker.getRules { lists in
            lists.forEach {
                self.baseConfiguration.userContentController.add($0)
                for (_, wv) in self.webViewMap { // in case we already have some
                    wv.configuration.userContentController.add($0)
                }
            }
        }
    }
    
    private var baseConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.userContentController.addUserScript(
            WKUserScript(source: checkFixedFunc, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        return configuration
    }()
    
    func webViewFor(_ tab: Tab) -> WKWebView {
        if let existing = webViewMap[tab] {
            return existing
        }
        else {
            let newWebView = createWebView(with: baseConfiguration)
            webViewMap[tab] = newWebView
            return newWebView
        }
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
        
        return webView
    }
}

extension WKWebView {
    func evaluateFixedNav(_ completionHandler: @escaping (Bool) -> Void) {
        evaluateJavaScript("window.\(checkFixedFuncName)()") { (result, error) in
            if let isFixed : Bool = result as? Bool {
                completionHandler(isFixed)
            }
        }
    }
}

fileprivate let checkFixedFuncName = "__BROWSE_HAS_FIXED_NAV__"
fileprivate let checkFixedFunc = """
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
        window.\(checkFixedFuncName) = () => isFixed(document.elementFromPoint(1,1));
    })();
"""
