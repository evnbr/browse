//
//  ViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

extension UIColor
{
    func isLight() -> Bool
    {
        let components : Array<CGFloat> = self.cgColor.components!
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return (r * 299 + g * 587 + b * 114 ) < 700
    }
}


class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {
    
    var webView: WKWebView!
    var statusBack: UIView!
    
    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!
    var urlButton: UIBarButtonItem!
    
    var colorFetcher: WebViewColorFetcher!

    override func loadView() {
        super.loadView()
        
        // --
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 20),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - 20
            )
        )

        webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self  // req'd for target=_blank override

        view.addSubview(webView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let url = URL(string: "https://www.hackingwithswift.com")!
        webView.load(URLRequest(url: url))
        webView.allowsBackForwardNavigationGestures = true
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)

        self.navigationController?.toolbar.addSubview(progressView)


        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        backButton = UIBarButtonItem(barButtonSystemItem: .rewind, target: webView, action: #selector(webView.goBack))
        forwardButton = UIBarButtonItem(barButtonSystemItem: .fastForward, target: webView, action: #selector(webView.goForward))
        
        let bookmarks = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(bookmarksSheet))
        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(displayShareSheet))
        urlButton = UIBarButtonItem(title: "URL...", style: .plain, target: self, action: #selector(askURL))
//        let color = UIBarButtonItem(title: "Color", style: .plain, target: self, action: #selector(updateStatusBarColor))
        

        
        toolbarItems = [backButton, forwardButton, flex, urlButton, flex, share, bookmarks]
        navigationController?.isToolbarHidden = false
        navigationController?.toolbar.isTranslucent = false
        navigationController?.toolbar.barTintColor = UIColor.black
        navigationController?.toolbar.tintColor = UIColor.white

        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:20)
        )
        statusBack = UIView.init(frame: rect)
        statusBack.autoresizingMask = [.flexibleWidth]
        statusBack.backgroundColor = UIColor.black
        self.view?.addSubview(statusBack)
        

        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;


        colorFetcher = WebViewColorFetcher(webView)
        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.5,
            target: self,
            selector: #selector(self.updateStatusBarColor),
            userInfo: nil,
            repeats: true
        )
//        RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)

    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func bookmarksSheet() {
        let ac = UIAlertController(title: "Open page…", message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: "apple.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "google.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "maps.google.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "plus.google.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "wikipedia.org", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "theoutline.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "twitter.com", style: .default, handler: openPage))
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    

    func getDisplayURL() -> String {
        var displayURL : String = (webView.url?.host)!
        if displayURL.hasPrefix("www.") {
            let index = displayURL.index(displayURL.startIndex, offsetBy: 4)
            displayURL = displayURL.substring(from: index)
        }
        return displayURL
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        urlButton.title = getDisplayURL()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlButton.title = getDisplayURL()
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        updateStatusBarColor()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.updateStatusBarColor()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        let alert = UIAlertController(title: "Failed Nav", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        let alert = UIAlertController(title: "Failed Provisional Nav", message: error.localizedDescription, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func goToText(_ text: String) {
        // TODO: More robust url detection
        if text.range(of:".") != nil{
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                let url = URL(string: text)!
                self.webView.load(URLRequest(url: url))
            }
            else {
                let url = URL(string: "http://" + text)!
                self.webView.load(URLRequest(url: url))
            }
        }
        else {
            let query = text.addingPercentEncoding(
                withAllowedCharacters: .urlHostAllowed)!
//            let duck = "https://duckduckgo.com/?q="
            let goog = "https://www.google.com/search?q="
            let url = URL(string: goog + query)!
            self.webView.load(URLRequest(url: url))
        }

    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }

    
    func askURL() {
        let alertController = UIAlertController(title: "Where to?", message: "Current: \(title!)", preferredStyle: .alert)
        
        let confirmAction = UIAlertAction(title: "Go", style: .default) { (_) in
            if let field = alertController.textFields?[0] {
                self.goToText(field.text!)
            } else {
                // user did not fill field
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.text = self.webView.url?.absoluteString
            textField.placeholder = "www.example.com"
            textField.keyboardType = UIKeyboardType.URL
            textField.returnKeyType = .go
            textField.delegate = self
        }
        
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }

    func displayShareSheet() {
        let avc = UIActivityViewController(activityItems: [webView.url!], applicationActivities: nil)
        self.present(avc, animated: true, completion: nil)
    }

    
    func getCSSColor(done: @escaping (_ color: UIColor) -> Void) {
        let js = "(function() { var bodyColor = getComputedStyle(document.body).backgroundColor; if (bodyColor !== \"rgba(0, 0, 0, 0)\") return bodyColor; else return getComputedStyle(document.documentElement).backgroundColor; })()"
        
        webView.evaluateJavaScript(js) { (result, error) in
            if error != nil {
                // print("JS Error: \(error!)")
            }
            else {
                // print("Computed BG: \(result!)")
                let bodyColor : UIColor = self.makeColor(fromCSS: result as! String)!
                done(bodyColor)
            }
        }
    }
    
    func updateStatusBarColor() {
        // ---
        // Status bar — Using color at top
        let colorAtTop = colorFetcher.getColorAt(x: 5, y: 5)
        
        self.statusBack.backgroundColor = colorAtTop
        webView.backgroundColor = colorAtTop
        webView.scrollView.backgroundColor = colorAtTop
        
        UIApplication.shared.statusBarStyle = colorAtTop.isLight()
            ? .lightContent
            : .default
        
        // ---
        // Toolbar — Using color at bottom
        let colorAtBottom = colorFetcher.getColorAt(x: 5, y: webView.bounds.size.height - 5)
        
        navigationController?.toolbar.barTintColor = colorAtBottom
        navigationController?.toolbar.tintColor = colorAtBottom.isLight()
            ? UIColor.white
            : UIColor.darkText
        progressView.progressTintColor = colorAtBottom.isLight()
            ? UIColor.white.withAlphaComponent(0.2)
            : UIColor.black.withAlphaComponent(0.08)

        // ---
        // Toolbar — Using CSS background color

//        getCSSColor( done: {(bodyColor) in
//            self.navigationController?.toolbar.barTintColor = bodyColor
//            self.navigationController?.toolbar.tintColor = bodyColor.isLight()
//                ? UIColor.white
//                : UIColor.darkText
//        })
    }
    
    
    func makeColor(fromCSS str: String) -> UIColor! {
        if str.hasPrefix("rgba(") || str.hasPrefix("rgb(") {
            let parts = str.components(separatedBy: NSCharacterSet.decimalDigits.inverted)
            let values : Array<Float> = parts.filter {
                if let _ = Float($0) { return true }
                else { return false }
            }.map { Float($0)! }
            return UIColor(
                colorLiteralRed: values[0] / 255.0,
                green: values[1] / 255.0,
                blue: values[2] / 255.0,
                alpha: 1
            )
        }
        return nil
    }
    
    // this handles target=_blank links by opening them in the same view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.alpha = 1.0
            
            let isIncreasing = progressView.progress < Float(webView.estimatedProgress)
            progressView.setProgress(Float(webView.estimatedProgress), animated: isIncreasing)
            
            if (webView.estimatedProgress >= 1.0) {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: UIViewAnimationOptions.curveEaseOut, animations: { 
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear
            
            // TODO this is probably expensive
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateStatusBarColor()
            }
        }
        else if keyPath == "isLoading" {
            print("loading change")
            //            backButton.isEnabled = webView.canGoBack
            //            forwardButton.isEnabled = webView.canGoForward
        }
        else if keyPath == "title" {
//             catches custom navigation
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
                updateStatusBarColor()
            }
        }
        else if keyPath == "url" {
            // catches custom navigation
            // TODO this is probably expensive
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateStatusBarColor()
            }
        }
    }



}

