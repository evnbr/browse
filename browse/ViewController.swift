//
//  ViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import OnePasswordExtension

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate {
    
    var webView: WKWebView!
    var statusBack: UIView!
    
    var statusBackInner: UIView!
    var toolBarInner: UIView!
    
    var colorAtTop: UIColor = UIColor.clear
    var colorAtBottom: UIColor = UIColor.clear
    
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
        
        goToText("fonts.google.com")
        
        webView.allowsBackForwardNavigationGestures = true
        
        let toolbar : UIToolbar = (navigationController?.toolbar)!
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)

        toolbar.addSubview(progressView)


        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let negSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        backButton = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: webView, action: #selector(webView.goBack))
        forwardButton = UIBarButtonItem(image: UIImage(named: "fwd"), style: .plain, target: webView, action: #selector(webView.goForward))
        backButton.width = 40.0
        forwardButton.width = 40.0
        space.width = 12.0
        negSpace.width = -12.0
        
        
//        let bookmarks = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(displayBookmarks))
        let share = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(displayShareSheet))
        let pwd = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(displayPassword))
        urlButton = UIBarButtonItem(title: "URL...", style: .plain, target: self, action: #selector(askURL))
        

        
        toolbarItems = [negSpace, backButton, forwardButton, flex, urlButton, flex, pwd, share, negSpace]
        navigationController?.isToolbarHidden = false
        toolbar.isTranslucent = false
        toolbar.barTintColor = .clear
        toolbar.tintColor = .white
//        navigationController?.toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)

        
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
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        
//        statusBack.backgroundColor = UIColor.clear
//        webView.scrollView.layer.masksToBounds = false
//        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
//        let blurEffectView = UIVisualEffectView(effect: blurEffect)
//        blurEffectView.frame = statusBack.bounds
//        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        statusBack.addSubview(blurEffectView)
        
        statusBackInner = UIView()
        statusBackInner.frame = statusBack.bounds
        statusBackInner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        statusBackInner.backgroundColor = .red
        statusBack.addSubview(statusBackInner)
        statusBack.clipsToBounds = true
        
        toolBarInner = UIView()
        toolBarInner.frame = toolbar.bounds
        toolBarInner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolBarInner.backgroundColor = .cyan
        toolbar.addSubview(toolBarInner)
        toolbar.sendSubview(toBack: toolBarInner)
        toolbar.clipsToBounds = true



        colorFetcher = WebViewColorFetcher(webView)
        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.4,
            target: self,
            selector: #selector(self.updateStatusBarColor),
            userInfo: nil,
            repeats: true
        )
        colorUpdateTimer.tolerance = 0.2
        // RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func displayBookmarks() {
        let ac = UIAlertController(title: "Open page…", message: nil, preferredStyle: .actionSheet)
        
        let bookmarks : Array<String> = [
            "apple.com",
            "fonts.google.com",
            "flights.google.com",
            "maps.google.com",
            "plus.google.com",
            "wikipedia.org",
            "theoutline.com",
        ]
        
        bookmarks.forEach() { item in ac.addAction(UIAlertAction(title: item, style: .default, handler: openPage)) }
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(ac, animated: true)
    }
    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        urlButton.title = getDisplayTitle()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlButton.title = getDisplayTitle()
        
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
    
    func getDisplayTitle() -> String {

        let url = webView.url!
        let absolute : String = url.absoluteString
        let google = "https://www.google.com/search?"
        
        if absolute.hasPrefix(google) {
            guard let components = URLComponents(string: absolute) else { return "?" }
            let queryParam : String = (components.queryItems?.first(where: { $0.name == "q" })?.value)!
            let search : String = queryParam.replacingOccurrences(of: "+", with: " ")
            return "🔍 \(search)"
        }
        
        let host : String = url.host!
        if host.hasPrefix("www.") {
            let index = host.index(host.startIndex, offsetBy: 4)
            return host.substring(from: index)
        }
        else {
            return host
        }
    }

    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        self.dismiss(animated: true, completion: nil)
        self.goToText(textField.text!)
        return true
    }

    
    func askURL() {
        let alertController = UIAlertController(title: "Where to?", message: "Current: \(title!)", preferredStyle: .alert)
        
        
        let bookmarksAction = UIAlertAction(title: "Bookmarks", style: .default) { (_) in
            self.displayBookmarks()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        
        alertController.addTextField { (textField) in
            textField.text = self.webView.url?.absoluteString
            textField.placeholder = "www.example.com"
            textField.keyboardType = UIKeyboardType.URL
            textField.returnKeyType = .go
            textField.delegate = self
        }
        
        alertController.addAction(bookmarksAction)
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
        
//        if webView.scrollView.isDragging {
//            return
//        }
        
        let colorAtTopLeft = colorFetcher.getColorAt(x: 5, y: 1)
        let colorAtTopMid = colorFetcher.getColorAt(x: webView.bounds.size.width / 2, y: 1)
        let colorAtTopRight = colorFetcher.getColorAt(x: webView.bounds.size.width - 5, y: 1)

        let newColorAtTop = UIColor.average([colorAtTopLeft, colorAtTopMid, colorAtTopRight])
        
        let colorAtBottomLeft = colorFetcher.getColorAt(
            x: 5,
            y: webView.bounds.size.height - 2)
        let colorAtBottomRight = colorFetcher.getColorAt(
            x: webView.bounds.size.width - 5,
            y: webView.bounds.size.height - 2)

        let newColorAtBottom = UIColor.average([colorAtBottomLeft, colorAtBottomRight])
        
        statusBack.layer.removeAllAnimations()
        navigationController?.toolbar.layer.removeAllAnimations()

        if !colorAtTop.isEqual(newColorAtTop) {
            statusBackInner.transform = statusBackInner.transform.translatedBy(x: 0, y: 20)
            statusBackInner.backgroundColor = newColorAtTop
        }
        if !colorAtBottom.isEqual(newColorAtBottom) {
            toolBarInner.transform = toolBarInner.transform.translatedBy(x: 0, y: -40)
            toolBarInner.backgroundColor = newColorAtBottom
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            if !self.colorAtTop.isEqual(newColorAtTop) {
                self.statusBackInner.transform = self.statusBackInner.transform.translatedBy(x: 0, y: -20)
            }
            if !self.colorAtBottom.isEqual(newColorAtBottom) {
                self.toolBarInner.transform = self.toolBarInner.transform.translatedBy(x: 0, y: 40)
            }
            
        }) { (completed) in
            self.statusBack.backgroundColor = self.colorAtTop

            self.navigationController?.toolbar.barTintColor = self.colorAtBottom
            self.navigationController?.toolbar.layoutIfNeeded()
        }
        
        colorAtTop = newColorAtTop
        colorAtBottom = newColorAtBottom

        webView.backgroundColor = colorAtTop
        webView.scrollView.backgroundColor = colorAtTop
        
        UIApplication.shared.statusBarStyle = colorAtTop.isLight()
            ? .lightContent
            : .default
        
        navigationController?.toolbar.tintColor = colorAtBottom.isLight()
            ? UIColor.white
            : UIColor.darkText
        progressView.progressTintColor = colorAtBottom.isLight()
            ? UIColor.white.withAlphaComponent(0.2)
            : UIColor.black.withAlphaComponent(0.08)

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
    
    func displayPassword() {
        OnePasswordExtension.shared().fillItem(intoWebView: self.webView, for: self, sender: nil, showOnlyLogins: false) { (success, error) -> Void in
            if success == false {
                print("Failed to fill into webview: <\(error)>")
            }
        }
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
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                self.updateStatusBarColor()
//            }
        }
        else if keyPath == "isLoading" {
            print("loading change")
            //            backButton.isEnabled = webView.canGoBack
            //            forwardButton.isEnabled = webView.canGoForward
        }
        else if keyPath == "title" {
//             catches custom navigation
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear

            
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
//                updateStatusBarColor()
            }
        }
        else if keyPath == "url" {
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear

            // catches custom navigation
            // TODO this is probably expensive
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                self.updateStatusBarColor()
//            }
        }
    }



}

