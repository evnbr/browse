//
//  BrowserTab.swift
//  browse
//
//  Created by Evan Brooks on 7/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class BrowserTab: NSObject {
    
    var webView: WKWebView!
    var parentTab : BrowserTab?
    
    var restoredLocation : String?
    var restoredTitle : String?
    var restoredTopColor : UIColor?
    var restoredBottomColor : UIColor?

    var history : HistoryTree = HistoryTree()
    var historyItemMap : [ WKBackForwardListItem : HistoryItem ] = [:]
    
    static var baseConfiguration: WKWebViewConfiguration = {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = WKProcessPool()
        configuration.allowsInlineMediaPlayback = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        return configuration
    }()
    
    override init() {
        super.init()
        webView = loadWebView(withConfig: nil)
    }
    
    init(withNewTabConfig config : WKWebViewConfiguration) {
        super.init()
        webView = loadWebView(withConfig: config)
    }
    
    init(restoreInfo : TabInfo) {
        super.init()
        restoredTopColor = restoreInfo.topColor
        restoredBottomColor = restoreInfo.bottomColor
        restoredTitle = restoreInfo.title
        restoredLocation = restoreInfo.urlString
        webView = loadWebView(withConfig: nil)
    }
    
    var restorableTitle : String? {
        if webView?.url == nil { return restoredTitle }
        return webView?.url?.displayHost ?? restoredTitle
    }
    var restorableURL : String? {
        return webView?.url?.absoluteString ?? restoredLocation
    }
    
    var restorableInfo : TabInfo {
        return TabInfo(
            title: restorableTitle ?? "",
            urlString: restorableURL ?? "",
            topColor: history.current?.topColor ?? .white,
            bottomColor: history.current?.bottomColor ?? .white
        )
    }
    
    func loadWebView(withConfig config : WKWebViewConfiguration?) -> WKWebView {
        let config = config ?? BrowserTab.baseConfiguration
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: Const.shared.statusHeight),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - Const.shared.toolbarHeight - Const.shared.statusHeight
            )
        )
                
        let webView = WKWebView(frame: rect, configuration: config)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInset = .zero
        webView.backgroundColor = restoredBottomColor
        
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.clipsToBounds = false
//        webView.scrollView.layer.masksToBounds = false
        
        webView.allowsLinkPreview = false
        
        return webView
    }
    
    func updateSnapshot(completionHandler: @escaping (UIImage) -> Void = { _ in }) {
        // Image snapshot
        webView.takeSnapshot(with: nil) { (image, error) in
            if let img : UIImage = image {
                self.history.current?.snapshot = img
                completionHandler(img)
            }
        }
    }
    
    func updateHistory() {
        guard let currentItem = webView.backForwardList.currentItem else { return }
        var historyItem = historyItemMap[currentItem]
        if historyItem == nil {
            // Create entry to mirror backForwardList
            historyItem = HistoryItem(parent: nil, from: currentItem)
            historyItemMap[currentItem] = historyItem
        }
        history.current = historyItem
    }
    
}


extension WKWebView {
    func evaluateFixedNav(_ completionHandler: @escaping (Bool) -> Void) {
        evaluateJavaScript(checkFixedTopScript) { (result, error) in
            if let isFixed : Bool = result as? Bool {
                completionHandler(isFixed)
            }
        }
    }
}

fileprivate let checkFixedTopScript = """
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
        return isFixed(document.elementFromPoint(1,1));
    })();
"""
