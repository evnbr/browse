//
//  WebViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import OnePasswordExtension

extension URL {
    var displayHost : String {
        get {
            let host : String = self.host!
            if host.hasPrefix("www.") {
                let index = host.index(host.startIndex, offsetBy: 4)
                return host.substring(from: index)
            }
            else {
                return host
            }
        }
    }
    var searchQuery : String {
        get {
            guard let components = URLComponents(string: self.absoluteString) else { return "?" }
            let queryParam : String = (components.queryItems?.first(where: { $0.name == "q" })?.value)!
            let withoutPlus : String = queryParam.replacingOccurrences(of: "+", with: " ")
            return withoutPlus
        }
    }
}

fileprivate extension UIBarButtonItem {
    var view: UIView? {
        return value(forKey: "view") as? UIView
    }
    func addGestureRecognizer(_ gestureRecognizer: UIGestureRecognizer) {
        view?.addGestureRecognizer(gestureRecognizer)
    }
}


class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate {
    
    var webView: WKWebView!
    var isPanning : Bool = false
    
    var searchView: SearchView!
    var scrim: UIButton!
    
    var colorFetcher: WebViewColorFetcher!
    var colorAtTop: UIColor = UIColor.clear
    var colorAtBottom: UIColor = UIColor.clear
    var colorDiffs : Sampler = Sampler(period: 12)
    var lastTopTransitionTime : CFTimeInterval = 0.0
    var lastBottomTransitionTime : CFTimeInterval = 0.0
    
    var statusBar: ColorStatusBarView!
    
    var toolbar: UIToolbar!
    var toolbarInner: UIView!

    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!
    var tabButton: UIBarButtonItem!
    var urlButton: UIBarButtonItem!
    
    var bookmarksController : BookmarksViewController!

    
    // This enables docked inputaccessory and long-press edit menu
    // http://stackoverflow.com/questions/19764293/inputaccessoryview-docked-at-bottom/23880574#23880574
    override var canBecomeFirstResponder : Bool {
        return true
    }
    override var inputAccessoryView:UIView{
        get { return searchView }
    }
    
    
    var displayTitle : String {
        get {
            let url = webView.url!
            if isSearching { return makeDisplaySearch(url.searchQuery) }
            else { return url.displayHost }
        }
    }
    
    var isSearching : Bool {
        get {
            let url = webView.url!
            let searchURL = "https://www.google.com/search?"
            return url.absoluteString.hasPrefix(searchURL)
        }
    }
    
    var editableURL : String {
        get {
            guard let url = webView.url else { return "" }
            
            if isSearching { return url.searchQuery }
            else { return url.absoluteString }
        }
    }

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
        webView.allowsBackForwardNavigationGestures = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal

        view.addSubview(webView)
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        toolbar = setUpToolbar()
        statusBar = ColorStatusBarView()
        view.addSubview(statusBar)

        searchView = SearchView(for: self)
        
        scrim = UIButton(frame: UIScreen.main.bounds)
        scrim.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        scrim.addTarget(self, action: #selector(hideSearch), for: .primaryActionTriggered)
        scrim.alpha = 0
        view.addSubview(scrim)

        bookmarksController = BookmarksViewController()
        

        colorFetcher = WebViewColorFetcher(webView)

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        
        // Detect panning to prevent status bar firing on js-implemented scrolling, like maps and pagers
        let touchRecognizer = UIPanGestureRecognizer()
        touchRecognizer.delegate = self
        touchRecognizer.addTarget(self, action: #selector(self.onWebviewPan))
        webView.scrollView.addGestureRecognizer(touchRecognizer)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        toolbar.addGestureRecognizer(longPress)

        
        let colorUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.6,
            target: self,
            selector: #selector(self.updateInterfaceColor),
            userInfo: nil,
            repeats: true
        )
        colorUpdateTimer.tolerance = 0.1
//        RunLoop.main.add(colorUpdateTimer, forMode: RunLoopMode.commonModes)
        
        navigateToText("fonts.google.com")
    }
    
    
//    var longPressBeginTime : TimeInterval
    func longPressURL(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            displayURLMenu()
            recognizer.isEnabled = false
            recognizer.isEnabled = true
            urlButton.isEnabled = false
            urlButton.isEnabled = true
        }
    }
    
    
    func onWebviewPan(gestureRecognizer:UIGestureRecognizer) {
        if gestureRecognizer.state == UIGestureRecognizerState.began {
            self.isPanning = true
        }
        else if gestureRecognizer.state == UIGestureRecognizerState.ended {
            self.isPanning = false
        }
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    func setUpToolbar() -> UIToolbar {
        
        let toolbar = (navigationController?.toolbar)!
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.3)
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        
        toolbar.addSubview(progressView)
        
        backButton = UIBarButtonItem(image: UIImage(named: "back"), style: .plain, target: webView, action: #selector(webView.goBack))
        forwardButton = UIBarButtonItem(image: UIImage(named: "fwd"), style: .plain, target: webView, action: #selector(webView.goForward))
        let actionButton = UIBarButtonItem(image: UIImage(named: "action"), style: .plain, target: self, action: #selector(displayShareSheet))
        tabButton = UIBarButtonItem(image: UIImage(named: "tab"), style: .plain, target: self, action: #selector(displayBookmarks))
        
        backButton.width = 40.0
        forwardButton.width = 40.0
        actionButton.width = 40.0
        tabButton.width = 40.0
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let negSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        space.width = 12.0
        negSpace.width = -12.0
        
        
//        let pwd = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(displayPassword))
        //        urlButton = UIBarButtonItem(title: "URL...", style: .plain, target: self, action: #selector(askURL))
        
        urlButton = UIBarButtonItem(title: "Where to?", style: .plain, target: self, action: #selector(displaySearch))
        
        
        toolbarItems = [negSpace, backButton, forwardButton, flex, urlButton, flex, tabButton, negSpace]
        navigationController?.isToolbarHidden = false
        toolbar.isTranslucent = false
        toolbar.barTintColor = .clear
        toolbar.tintColor = .white
        //        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        
        toolbarInner = UIView()
        toolbarInner.frame = toolbar.bounds
        toolbarInner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolbarInner.backgroundColor = .white
        toolbar.addSubview(toolbarInner)
        toolbar.sendSubview(toBack: toolbarInner)
        toolbar.clipsToBounds = true
        
        return toolbar
    }
    
    
    func updateInterfaceColor() {
        
        if self.isPanning {
            return
        }

        let newColorAtTop    = colorFetcher.getColorAtTop()
        let newColorAtBottom = colorFetcher.getColorAtBottom()


        self.statusBar.back.layer.removeAllAnimations()
        self.toolbar.layer.removeAllAnimations()
        
        if !self.colorAtTop.isEqual(newColorAtTop) {
            self.statusBar.inner.transform = CGAffineTransform(translationX: 0, y: 20)
            self.statusBar.inner.backgroundColor = newColorAtTop
        }
        if !self.colorAtBottom.isEqual(newColorAtBottom) {
            self.toolbarInner.transform = CGAffineTransform(translationX: 0, y: -48)
            self.toolbarInner.backgroundColor = newColorAtBottom
        }
        
        let topChange = self.colorAtTop.difference(from: newColorAtTop)
        let bottomChange = self.colorAtBottom.difference(from: newColorAtBottom)

        
        colorDiffs.addSample(value:    topChange > 0.3 ? 1 : 0)
        colorDiffs.addSample(value: bottomChange > 0.3 ? 1 : 0)
        
        let isFrantic : Bool = colorDiffs.sum > 7
        if isFrantic {

            self.statusBar.back.backgroundColor = .black
            self.toolbar.barTintColor = .black
            self.toolbar.layoutIfNeeded()
            
            UIApplication.shared.statusBarStyle = .lightContent
            self.toolbar.tintColor = .white
        }
        else {
            let throttleTop = CACurrentMediaTime() - self.lastTopTransitionTime < 1.0
            let throttleBottom = CACurrentMediaTime() - self.lastBottomTransitionTime < 1.0

            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut, animations: {
                if !self.colorAtTop.isEqual(newColorAtTop) {
                    if !throttleTop && topChange > 0.4 {
                        self.statusBar.inner.transform = .identity
                        self.lastTopTransitionTime = CACurrentMediaTime()
                    } else {
                        self.statusBar.back.backgroundColor = newColorAtTop
                    }
                    UIApplication.shared.statusBarStyle = newColorAtTop.isLight ? .lightContent : .default
                }
                if !self.colorAtBottom.isEqual(newColorAtBottom) {
                    self.toolbar.tintColor = newColorAtBottom.isLight ? .white : .darkText
                    if !throttleBottom && bottomChange > 0.4 {
                        self.toolbarInner.transform = .identity
                        self.toolbar.layoutIfNeeded()
                        self.lastBottomTransitionTime = CACurrentMediaTime()
                    } else {
                        self.toolbar.barTintColor = newColorAtBottom
                        self.toolbar.layoutIfNeeded()
                    }
                }
            }) { (completed) in
                if (completed) {
                    self.statusBar.back.backgroundColor = newColorAtTop
                    self.toolbar.barTintColor = newColorAtBottom
                    self.toolbar.layoutIfNeeded()
                }
                else {
                    print("Animation interrupted!")
                }
            }
    
            
            self.webView.backgroundColor = newColorAtTop
            self.webView.scrollView.backgroundColor = newColorAtTop
            self.view.backgroundColor = newColorAtTop
            
            self.progressView.progressTintColor = newColorAtBottom.isLight
                ? UIColor.white.withAlphaComponent(0.2)
                : UIColor.black.withAlphaComponent(0.08)
        }
        
        self.colorAtTop = newColorAtTop
        self.colorAtBottom = newColorAtBottom

    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func displayBookmarks() {
        
        let navigationController = UINavigationController(rootViewController: bookmarksController)
        bookmarksController.sender = self

        present(navigationController, animated: true)
    }
    
    func displayURLMenu() {
        if !isFirstResponder {
            UIView.setAnimationsEnabled(false)
            self.becomeFirstResponder()
            UIView.setAnimationsEnabled(true)
        }
        DispatchQueue.main.async {
            UIMenuController.shared.setTargetRect(self.toolbar.frame, in: self.view)
            let copy : UIMenuItem = UIMenuItem(title: "Copy", action: #selector(self.copyURL))
            let pasteAndGo : UIMenuItem = UIMenuItem(title: "Paste and Go", action: #selector(self.pasteURLAndGo))
            let share : UIMenuItem = UIMenuItem(title: "Share", action: #selector(self.displayShareSheet))
            UIMenuController.shared.menuItems = [ copy, pasteAndGo, share ]
            UIMenuController.shared.setMenuVisible(true, animated: true)
        }
    }
    
    func copyURL() {
        UIPasteboard.general.string = self.editableURL
    }
    
    func pasteURLAndGo() {
        hideSearch()
        if let str = UIPasteboard.general.string {
            navigateToText(str)
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if !isFirstResponder && action != #selector(pasteURLAndGo) {
            return false
        }
        switch action {
        case #selector(copyURL):
            return true
        case #selector(pasteURLAndGo):
            return UIPasteboard.general.hasStrings
        case #selector(displayShareSheet):
            return true
        default:
            return false
        }
    }
    
    func displaySearch() {
        guard !UIMenuController.shared.isMenuVisible else { return }
        
        searchView.prepareToShow()

        let url = self.urlButton.value(forKey: "view") as! UIView
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.scrim.alpha = 1
            
            url.transform  = CGAffineTransform(translationX: -30, y: -100)
            back.transform = CGAffineTransform(translationX: 0, y: -50)
            tab.transform  = CGAffineTransform(translationX: 0, y: -50)
            
        })
        
        self.becomeFirstResponder()
        searchView.textView.becomeFirstResponder()
        searchView.textView.selectAll(nil) // if not nil, will show actions
    }

    
    func hideSearch() {
        searchView.textView.resignFirstResponder()
        self.resignFirstResponder()
        
        let url = self.urlButton.value(forKey: "view") as! UIView
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.scrim.alpha = 0
            
            url.transform  = .identity
            back.transform = .identity
            tab.transform  = .identity
        })
    }

    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        urlButton.title = self.displayTitle
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlButton.title = self.displayTitle
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        let alert = UIAlertController(title: "Failed Nav", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled {
            print("Cancelled")
            return
        }
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
        let alert = UIAlertController(title: "Failed Provisional Nav", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func navigateToText(_ text: String) {
        // TODO: More robust url detection

        if ( text.range(of:".") != nil && text.range(of:" ") == nil ) {
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                let url = URL(string: text)!
                if let btn = urlButton { btn.title = url.displayHost }
                self.webView.load(URLRequest(url: url))
            }
            else {
                let url = URL(string: "http://" + text)!
                if let btn = urlButton { btn.title = url.displayHost }
                self.webView.load(URLRequest(url: url))
            }
        }
        else {
            let query = text.addingPercentEncoding(
                withAllowedCharacters: .urlHostAllowed)!
//            let searchURL = "https://duckduckgo.com/?q="
            let searchURL = "https://www.google.com/search?q="
            let url = URL(string: searchURL + query)!
            
            if let btn = urlButton {
                btn.title = makeDisplaySearch(text)
            }

            self.webView.load(URLRequest(url: url))
        }

    }
    
    func makeDisplaySearch(_ query: String) -> String {
        return "🔍 \(query)"
    }
    
    func displayShareSheet() {
        let avc = UIActivityViewController(activityItems: [webView.url!], applicationActivities: nil)
        self.present(avc, animated: true, completion: nil)
    }

    func displayPassword() {
        OnePasswordExtension.shared().fillItem(intoWebView: self.webView, for: self, sender: nil, showOnlyLogins: true) { (success, error) -> Void in
            if success == false {
                print("Failed to fill into webview: <\(String(describing: error))>")
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
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : .clear
            
        }
        else if keyPath == "isLoading" {
            print("loading change")
        }
        else if keyPath == "title" {
//             catches custom navigation
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : UIColor.clear

            
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
            }
        }
        else if keyPath == "url" {
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : .clear

        }
    }



}

