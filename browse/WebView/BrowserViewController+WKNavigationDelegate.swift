//
//  BrowserViewController+WKNavigationDelegate.swift
//  browse
//
//  Created by Evan Brooks on 6/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        errorView?.removeFromSuperview()
        
        loadingDidChange()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingDidChange()
    }
    
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
        loadingDidChange()

        if (error as NSError).code == NSURLErrorCancelled { return }
        
        displayError(text: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        loadingDidChange()
        
        print("failed provisional")
        
        displayError(text: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if webView != self.webView {
            decisionHandler(.allow)
            return
        }
        
        let app = UIApplication.shared
        if let url = navigationAction.request.url {
            if navigationAction.targetFrame == nil { // Handle target="_blank"
                decisionHandler(.allow)
                return
//                if app.canOpenURL(url) {
//                    app.open(url, options: [:], completionHandler: nil)
//                    decisionHandler(.cancel)
//                    return
//                }
            }
            if url.scheme == "http" || url.scheme == "https" || url.scheme == "about" || url.scheme == "data" {
                decisionHandler(.allow)
                return
            }
//            if url.scheme == "tel" || url.scheme == "mailto" {
            else {
                let canOpen = app.canOpenURL(url)
                decisionHandler(.cancel)
                let ac = UIAlertController(title: "\(url.absoluteString)", message: "Open this in app?", preferredStyle: .actionSheet)
                
                if !canOpen { ac.message = "Not sure if I can open this." }
                
                ac.addAction(UIAlertAction(title: "Open", style: .default, handler: { _ in
                    app.open(url, options: [:], completionHandler: nil)
                }))
                ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                
                present(ac, animated: true, completion: nil)
                return
            }
        }
    }
    

        
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("server redirect")
    }

}
