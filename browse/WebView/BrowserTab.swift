//
//  BrowserTab.swift
//  browse
//
//  Created by Evan Brooks on 7/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

//import UIKit
//import WebKit
//
//class BrowserTabDEPRECATED: NSObject {
//    
//    var webView: WKWebView!
//    var parentTab : BrowserTab?
//    var canGoBackToParent: Bool {
//        return parentTab != nil
//    }
//
//    var restored : TabInfo?
//
//    var currentItem : HistoryItem?
//    var historyPageMap : [ WKBackForwardListItem : HistoryItem ] = [:]
//
//    static var baseConfiguration: WKWebViewConfiguration = {
//        let configuration = WKWebViewConfiguration()
//        configuration.processPool = WKProcessPool()
//        configuration.allowsInlineMediaPlayback = true
//        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
//        
//        configuration.userContentController.addUserScript(
//            WKUserScript(source: checkFixedFunc, injectionTime: .atDocumentStart, forMainFrameOnly: false)
//        )
//        return configuration
//    }()
//    
//    override init() {
//        super.init()
//        webView = loadWebView(withConfig: nil)
//    }
//    
//    init(withNewTabConfig config : WKWebViewConfiguration) {
//        super.init()
//        webView = loadWebView(withConfig: config)
//    }
//    
//    init(restoreInfo : TabInfo) {
//        super.init()
//        restored = restoreInfo
//        webView = loadWebView(withConfig: nil)
//    }
//    
//    var restorableTitle : String? {
//        return webView?.title ?? restored?.title
//    }
//    var restorableURL : String? {
//        return webView?.url?.absoluteString ?? restored?.urlString
//    }
//    
//    var restorableInfo : TabInfo {
//        if let current = currentItem {
//            return TabInfo(
//                title: restorableTitle ?? "",
//                urlString: restorableURL ?? "",
//                topColor: current.topColor ?? .white,
//                bottomColor: current.bottomColor ?? .white,
//                id: current.uuid?.uuidString ?? "",
//                image: current.snapshot
//            )
//        }
//        else if let restored = restored {
//            return restored
//        }
//        else {
//            return TabInfo(
//                title: restorableTitle ?? "",
//                urlString: restorableURL ?? "",
//                topColor: .white, bottomColor: .white, id: nil, image: nil
//            )
//        }
//    }
//    
//    func loadWebView(withConfig config : WKWebViewConfiguration?) -> WKWebView {
//        let config = config ?? BrowserTabDEPRECATED.baseConfiguration
//        let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
//        
//        webView.translatesAutoresizingMaskIntoConstraints = false
//        webView.scrollView.contentInset = .zero
//        webView.scrollView.contentInsetAdjustmentBehavior = .never
//        webView.scrollView.clipsToBounds = false
//        webView.allowsLinkPreview = false
//        
//        return webView
//    }
//    
//    func updateSnapshot(completionHandler: @escaping (UIImage) -> Void = { _ in }) {
//        // Image snapshot
//        let wasShowingIndicators = webView.scrollView.showsVerticalScrollIndicator
//        webView.scrollView.showsVerticalScrollIndicator = false
//        webView.takeSnapshot(with: nil) { (image, error) in
//            if wasShowingIndicators {
//                 self.webView.scrollView.showsVerticalScrollIndicator = true
//            }
//            if let img : UIImage = image {
//                self.currentItem?.snapshot = img
//                completionHandler(img)
//            }
//        }
//    }
//    
//    func updateHistory() {
//        guard let currentWKItem = webView.backForwardList.currentItem else { return }
//        var anItem = historyPageMap[currentWKItem]
//        if anItem == nil {
//            if let backWKItem = webView.backForwardList.backItem,
//                let backItem = historyPageMap[backWKItem],
//                backItem == currentItem {
//                // We went forward, link these pages together
//                anItem = HistoryManager.shared.addPage(from: currentWKItem, parent: currentItem)
//                if let it = anItem { currentItem?.addToForwardItems(it) }
//            }
//            else {
//                // Create a new entry (probably restored)
//                print("unknown parent")
//                anItem = HistoryManager.shared.addPage(from: currentWKItem, parent: nil)
//            }
//            historyPageMap[currentWKItem] = anItem
//        } else {
//            // Update title and url
//            currentItem?.title = currentWKItem.title
//            currentItem?.url = currentWKItem.url
//        }
//        currentItem = anItem
//    }
//}
//
//
//fileprivate let checkFixedFuncName = "__BROWSE_HAS_FIXED_NAV__"
//fileprivate let checkFixedFunc = """
//    (function() {
//        const isFixed = (elm) => {
//            let el = elm;
//            while (typeof el === 'object' && el.nodeName.toLowerCase() !== 'body') {
//                const pos = window.getComputedStyle(el).getPropertyValue('position').toLowerCase()
//                if (pos === 'fixed' || pos === 'sticky' || pos === '-webkit-sticky') return true;
//                el = el.parentElement;
//            }
//            return false;
//        };
//        window.\(checkFixedFuncName) = () => isFixed(document.elementFromPoint(1,1));
//    })();
//"""

