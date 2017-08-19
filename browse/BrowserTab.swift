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
        self.restoredColor = restoreInfo.color
        self.restoredTitle = restoreInfo.title
        self.restoredLocation = restoreInfo.urlString
        webView = loadWebView(withConfig: nil)
    }
    
    var restorableTitle : String? {
        if webView?.url == nil { return restoredTitle }
        return webView?.title ?? restoredTitle
    }
    var restorableURL : String? {
        return webView?.url?.absoluteString ?? restoredLocation
    }
    var color : UIColor {
        return colorSample ?? restoredColor ?? .white
    }
    var colorSample : UIColor?
    
    var restorableInfo : TabInfo {
        return TabInfo(
            title: restorableTitle ?? "",
            urlString: restorableURL ?? "",
            color: color
        )
    }
    
    func loadWebView(withConfig config : WKWebViewConfiguration?) -> WKWebView {
        let config = config ?? WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: STATUS_H),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - TOOLBAR_H - STATUS_H
            )
        )
        
        let userContentController = config.userContentController
        if let ruleList = Blocker.shared.ruleList {
            print("list added")
            userContentController.add(ruleList)
        }
        
        let webView = WKWebView(frame: rect, configuration: config)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.backgroundColor = colorSample
        webView.allowsBackForwardNavigationGestures = true
        
        
        return webView
    }
    
}
