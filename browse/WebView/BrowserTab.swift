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
    var restoredColor : UIColor?
    
    var history : HistorTree = HistorTree()
    
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
        topColorSample = restoreInfo.topColor
        bottomColorSample = restoreInfo.bottomColor
        restoredTitle = restoreInfo.title
        restoredLocation = restoreInfo.urlString
        webView = loadWebView(withConfig: nil)
    }
    
    func updateSnapshot(completionHandler: @escaping (UIImage?, Error?) -> Void) {
        // Image snapshot
        webView.takeSnapshot(with: nil) { (image, error) in
            if let img : UIImage = image {
                self.history.current?.snapshot = img
            }
            completionHandler(image, error)
        }
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
        webView.backgroundColor = bottomColorSample
        
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.clipsToBounds = false
        
        webView.allowsLinkPreview = false
        
        return webView
    }
    
}
