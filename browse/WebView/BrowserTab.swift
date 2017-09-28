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
    var webSnapshot : UIView?
    
    var restoredLocation : String?
    var restoredTitle : String?
    var restoredColor : UIColor?
    
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
        topColorSample = restoreInfo.topColor
        bottomColorSample = restoreInfo.bottomColor
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
    var color : UIColor {
        return bottomColorSample ?? restoredColor ?? .white
    }
    var topColorSample : UIColor?
    var bottomColorSample : UIColor?
    
    var restorableInfo : TabInfo {
        return TabInfo(
            title: restorableTitle ?? "",
            urlString: restorableURL ?? "",
            topColor: bottomColorSample ?? .white,
            bottomColor: bottomColorSample ?? .white
        )
    }
    
    func loadWebView(withConfig config : WKWebViewConfiguration?) -> WKWebView {
        let config = config ?? WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: Const.shared.statusHeight),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - Const.shared.toolbarHeight - Const.shared.statusHeight
            )
        )
        
        let userContentController = config.userContentController
        if let ruleList = Blocker.shared.ruleList {
            userContentController.add(ruleList)
        }
        
        let webView = WKWebView(frame: rect, configuration: config)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInset = .zero
        webView.backgroundColor = bottomColorSample
        webView.isOpaque = false
        webView.allowsBackForwardNavigationGestures = true
        
        webView.scrollView.contentInsetAdjustmentBehavior = .never
//        webView.layer.borderWidth = 1
//        webView.layer.borderColor = UIColor.red.cgColor
        
//        webView.scrollView.layer.borderWidth = 1
//        webView.scrollView.layer.borderColor = UIColor.cyan.cgColor

        
        return webView
    }
    
}
