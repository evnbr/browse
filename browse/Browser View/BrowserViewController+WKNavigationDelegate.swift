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
        
        updateLoadingState()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateLoadingState()
        
        if navigation == navigationToHide {
            // wait a sec... just because the first navigation is done,
            // doesnt mean the first paint is done
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.finishHiddenNavigation()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateSnapshot()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        updateLoadingState()

        if (error as NSError).code == NSURLErrorCancelled { return }
        displayError(text: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        updateLoadingState()
        
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
            }
            if url.scheme == "http" || url.scheme == "https" || url.scheme == "about" || url.scheme == "data" {
                self.updateSnapshot {
                    decisionHandler(.allow)
                }
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
    }
    
    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic {
            let space = challenge.protectionSpace
            
            let ac = UIAlertController(
                title: "Log in to \(space.host)",
                message: "",
                preferredStyle: .alert)

            ac.addTextField { field in
                field.keyboardAppearance = .light
                field.placeholder = "username"
                field.returnKeyType = .next
            }
            ac.addTextField { field in
                field.keyboardAppearance = .light
                field.isSecureTextEntry = true
                field.placeholder = "password"
                field.returnKeyType = .go
            }
            ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
            }))
            ac.addAction(UIAlertAction(title: "Submit", style: .default, handler: { action in
                if let userName = ac.textFields?.first?.text,
                    let password = ac.textFields?.last?.text {
                    print("u: \(userName), p: \(password)")
                    let credential = URLCredential(user: userName, password: password, persistence: URLCredential.Persistence.forSession)
                    challenge.sender?.use(credential, for: challenge)
                    completionHandler(URLSession.AuthChallengeDisposition.useCredential, credential)
                }
            }))
            present(ac, animated: true, completion: nil)
            
        }
        else {
            completionHandler(URLSession.AuthChallengeDisposition.performDefaultHandling, nil)
        }
    }

}
