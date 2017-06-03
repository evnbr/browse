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

class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate {
    
    var webView: WKWebView!
    
    var searchView: SearchView!
    var searchDismissScrim: UIScrollView!
    
    var webViewColor: WebViewColorFetcher!
    
    var statusBar: ColorStatusBarView!
    
    var toolbar: UIToolbar!
    var toolbarInner: UIView!
    var toolbarBack: UIView!

    var progressView: UIProgressView!
    var backButton: UIBarButtonItem!
    var forwardButton: UIBarButtonItem!
    var tabButton: UIBarButtonItem!
    var locationBar: LocationBar!
    
    var homeVC : HomeViewController!
    

    // MARK: - Derived properties

    // This enables docked inputaccessory and long-press edit menu
    // http://stackoverflow.com/questions/19764293/inputaccessoryview-docked-at-bottom/23880574#23880574
    override var canBecomeFirstResponder : Bool {
        return true
    }
    override var inputAccessoryView:UIView{
        get { return searchView }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard webViewColor != nil else { return .default }
        return webViewColor.top.isLight ? .lightContent : .default
    }

    var displayTitle : String {
        get {
            let url = webView.url!
            if isSearching { return makeDisplaySearch(url.searchQuery) }
            else { return displayURL }
        }
    }
    
    var displayURL : String {
        get {
            let url = webView.url!
            return url.displayHost
        }
    }
    
    func makeDisplaySearch(_ query: String) -> String {
        if query.characters.count > 28 {
            let index = query.index(query.startIndex, offsetBy: 28)
            let trimmed = query.substring(to: index)
            return "\(trimmed)..."
        }
        else {
            return query
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
    
    // MARK: - Lifecycle

    override func loadView() {
        super.loadView()
        
        // --
        
        
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
//        let prefs = WKPreferences()
//        prefs.javaScriptEnabled = false
//        config.preferences = prefs
        

//        let scriptContent = ""
//            + " document.documentElement.querySelectorAll('form').forEach((form) => {"
//            + "  form.addEventListener('submit', (e) => {"
//            + "     /* e.preventDefault(); */"
//            + "     alert('form submitted');"
//            + "  });"
//            + " });"
        
//        let scriptContent = "document.head.querySelectorAll('script').forEach((s) => console.log(s.src))"
//        let scriptContent = "document.documentElement.querySelectorAll('script').forEach((s) => console.log(s.src))"
//        let scriptContent = "(function() { "
//            + " var target = document.documentElement; "
//            + " var observer = new MutationObserver(function(mutations) {"
//            + "     mutations.forEach(function(mutation) {"
//            + "         document.documentElement.querySelectorAll('script').forEach((s) => s.remove() )"
//            + "     }); "
//            + " }); "
//            + " var config = { attributes: true, childList: true, characterData: true }; "
//            + " observer.observe(target, config);"
//            + " })(); "
//        let script = WKUserScript(source: scriptContent, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
//        config.userContentController.addUserScript(script)
        
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
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateProtocolRegistration), name: NSNotification.Name(rawValue: "adBlockSettingDidChange"), object: nil)
        
        toolbar = setUpToolbar()
        view.addSubview(toolbar)
        
        statusBar = ColorStatusBarView()
        view.addSubview(statusBar)

        searchView = SearchView(for: self)
        
        searchDismissScrim = makeScrim()
        view.addSubview(searchDismissScrim)

//        self.navigationController?.hidesBarsOnSwipe = true
        
//        let bc = BookmarksViewController()
//        bc.webViewController = self
//        bookmarksController = WebNavigationController(rootViewController: bc)
//        bookmarksController.modalTransitionStyle = .crossDissolve
//        bookmarksController.modalPresentationStyle = .overCurrentContext

        
        webViewColor = WebViewColorFetcher(from: webView, inViewController: self)
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        toolbar.addGestureRecognizer(longPress)

        updateProtocolRegistration()
        
        if let restored : String = restoreURL() {
            navigateToText(restored)
        }
        else {
            navigateToText("fonts.google.com")
        }
    }
    
    func updateProtocolRegistration() {
        let newValue : Bool = Settings.shared.blockAds.isOn
        if newValue { registerProtocol()   }
        else        { unregisterProtocol() }
    }
    func registerProtocol() {
         URLProtocol.wk_registerScheme("http")
         URLProtocol.wk_registerScheme("https")
         URLProtocol.registerClass(BrowseURLProtocol.self)
    }
    func unregisterProtocol() {
        URLProtocol.wk_unregisterScheme("http")
        URLProtocol.wk_unregisterScheme("https")
        URLProtocol.unregisterClass(BrowseURLProtocol.self)
    }
    
    func makeScrim() -> UIScrollView {
        let scrim = UIScrollView(frame: UIScreen.main.bounds)
        scrim.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        scrim.alpha = 0
        
        scrim.keyboardDismissMode = .interactive
        scrim.alwaysBounceVertical = true
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideSearch))
        tap.numberOfTapsRequired = 1
        tap.isEnabled = true
        tap.cancelsTouchesInView = false
        scrim.addGestureRecognizer(tap)
        
        return scrim
    }
    
    
    func setUpToolbar() -> UIToolbar {
        
        // let toolbar = (navigationController?.toolbar)!
        let toolbar = UIToolbar()
        
        let TOOLBAR_H : CGFloat = 36.0
        
        toolbar.frame = CGRect(
            x: 0,
            y: UIScreen.main.bounds.size.height - TOOLBAR_H,
            width: UIScreen.main.bounds.size.width,
            height: TOOLBAR_H
        )
        toolbar.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
        
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
        let actionButton = UIBarButtonItem(image: UIImage(named: "action"), style: .plain, target: self, action: #selector(displayOverflow))
        tabButton = UIBarButtonItem(image: UIImage(named: "tab"), style: .plain, target: self, action: #selector(dismissSelf))
        
        backButton.width = 48.0
        forwardButton.width = 48.0
        actionButton.width = 48.0
        tabButton.width = 48.0
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let negSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        space.width = 16.0
        negSpace.width = -16.0
        
//        let pwd = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(displayPassword))
        
        locationBar = LocationBar(onTap: self.displaySearch)
        let urlButton = UIBarButtonItem(customView: locationBar)
        
        toolbar.items = [negSpace, backButton, forwardButton, flex, urlButton, flex, actionButton, tabButton, negSpace]
//        navigationController?.isToolbarHidden = false
        toolbar.isTranslucent = false
        toolbar.barTintColor = .white
        toolbar.tintColor = .darkText
        
        toolbarInner = UIView()
        toolbarInner.frame = toolbar.bounds
        toolbarInner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolbarInner.backgroundColor = .white
        toolbar.addSubview(toolbarInner)
        toolbar.sendSubview(toBack: toolbarInner)
        
        toolbarBack = UIView()
        toolbarBack.frame = toolbar.bounds
        toolbarBack.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        toolbarBack.backgroundColor = .white
        toolbar.addSubview(toolbarBack)
        toolbar.sendSubview(toBack: toolbarBack)

        toolbar.clipsToBounds = true
        
        return toolbar
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
        self.setNeedsStatusBarAppearanceUpdate()

        // disable mysterious delays
        // https://stackoverflow.com/questions/19799961/uisystemgategesturerecognizer-and-delayed-taps-near-bottom-of-screen
//        let window = view.window!
//        let gr0 = window.gestureRecognizers![0] as UIGestureRecognizer
//        let gr1 = window.gestureRecognizers![1] as UIGestureRecognizer
//        gr0.delaysTouchesBegan = false
//        gr1.delaysTouchesBegan = false
        
    }
        
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        // This is probably called too often, should only be when app closes
        saveURL()
    }
    
    func saveURL() {
        guard let url_str : String = webView.url?.absoluteString else { return }
        UserDefaults.standard.setValue(url_str, forKey: "current_url")
        print("Saved location: \(url_str)")
    }
    
    func restoreURL() -> String! {
        let saved_url_val = UserDefaults.standard.value(forKey: "current_url")
        if saved_url_val != nil {
            let saved_url_str = saved_url_val as! String
            //            let saved_url = URL(string: saved_url_str)
            return saved_url_str
        }
        return nil
    }

    
    // MARK: - Gestures
    
    func longPressURL(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            displayURLMenu()
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
    }
    
        

    // MARK: - Actions

//    func displayBookmarks() {
//         
//        bookmarksController.modalPresentationStyle = .custom
//        bookmarksController.transitioningDelegate = self
//
//        present(bookmarksController, animated: true)
//
//    }
    
    func dismissSelf() {
        homeVC.updateSnapshot()
        self.dismiss(animated: true, completion: nil)
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

        let url = locationBar!
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.searchDismissScrim.alpha = 1
            
            url.transform  = CGAffineTransform(translationX: -30, y: -100)
            back.transform = CGAffineTransform(translationX: 0, y: -50)
            tab.transform  = CGAffineTransform(translationX: 0, y: -50)
            
        })
        
        self.becomeFirstResponder()
        searchView.textView.becomeFirstResponder()
        
    }

    
    func hideSearch() {
        let startPoint = searchView.convert(searchView.frame.origin, to: toolbar)
        
        searchView.textView.resignFirstResponder()
//        self.resignFirstResponder()
        
        let url = locationBar!
        let back = self.backButton.value(forKey: "view") as! UIView
        let tab = self.tabButton.value(forKey: "view") as! UIView
        
        url.transform  = CGAffineTransform(translationX: -30, y: startPoint.y)
        back.transform = CGAffineTransform(translationX: 0,   y: startPoint.y)
        tab.transform  = CGAffineTransform(translationX: 0,   y: startPoint.y)

        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.searchDismissScrim.alpha = 0
            
            url.transform  = .identity
            back.transform = .identity
            tab.transform  = .identity
        })
    }
    
    func displayShareSheet() {
        let avc = UIActivityViewController(activityItems: [webView.url!], applicationActivities: nil)
        self.resignFirstResponder() // without this, action sheet dismiss animation won't go all the way
        self.present(avc, animated: true, completion: nil)
    }
    
    func displayOverflow() {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Passwords", style: .default, handler: { action in
            self.displayPassword()
        }))
        ac.addAction(UIAlertAction(title: "Share", style: .default, handler: { action in
            self.displayShareSheet()
        }))
        ac.addAction(UIAlertAction(title: "Refresh", style: .default, handler: { action in
            self.webView.reload()
        }))
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(ac, animated: true, completion: nil)
    }
    
    func displayPassword() {
        OnePasswordExtension.shared().fillItem(intoWebView: self.webView, for: self, sender: nil, showOnlyLogins: true) { (success, error) -> Void in
            if success == false {
                print("Failed to fill into webview: <\(String(describing: error))>")
            }
        }
    }


    // MARK: - Webview State
    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    
    func navigateToText(_ text: String) {
        // TODO: More robust url detection
        
        if ( text.range(of:".") != nil && text.range(of:" ") == nil ) {
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                let url = URL(string: text)!
                if let btn = locationBar { btn.text = url.displayHost }
                self.webView.load(URLRequest(url: url))
            }
            else {
                let url = URL(string: "http://" + text)!
                if let btn = locationBar { btn.text = url.displayHost }
                self.webView.load(URLRequest(url: url))
            }
        }
        else {
            let query = text.addingPercentEncoding(
                withAllowedCharacters: .urlHostAllowed)!
            //            let searchURL = "https://duckduckgo.com/?q="
            let searchURL = "https://www.google.com/search?q="
            let url = URL(string: searchURL + query)!
            
            if let btn = locationBar {
                btn.text = makeDisplaySearch(text)
            }
            
            self.webView.load(URLRequest(url: url))
        }
        
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        locationBar.text = self.displayTitle
        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        locationBar.text = self.displayTitle
        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching

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
    
    func webViewDidClose(_ webView: WKWebView) {
        print("Tried to close window")
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("server redirect")
    }
    
    // this handles target=_blank links by opening them in the same view
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            print("Tried to open new window")
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
    
    // MARK: - Webview Javascript Inputs
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
            completionHandler()
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        
        let alertController = UIAlertController(title: nil, message: message, preferredStyle: .actionSheet)
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            completionHandler(false)
        }))
        
        present(alertController, animated: true, completion: nil)
    }
    
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        
        let alertController = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        
        alertController.addTextField { (textField) in
            textField.text = defaultText
        }
        
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let text = alertController.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            completionHandler(nil)
        }))
        
        present(alertController, animated: true, completion: nil)
    }


}

