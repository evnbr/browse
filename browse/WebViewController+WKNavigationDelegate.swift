//
//  WebViewController+WKNavigationDelegate.swift
//  browse
//
//  Created by Evan Brooks on 6/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

extension WebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        errorView?.removeFromSuperview()
        
        updateLoadingUI()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        updateLoadingUI()
        
        if overflowController != nil {
            updateStopRefreshAlertAction()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        
        if (error as NSError).code == NSURLErrorCancelled { return }
        
        updateLoadingUI()
        displayError(text: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        
        if (error as NSError).code == NSURLErrorCancelled { return }
        
        updateLoadingUI()
        displayError(text: error.localizedDescription)
    }

        
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("server redirect")
    }

}
