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
            guard let host : String = self.host else { return "No host"}
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

let TOOLBAR_H : CGFloat = 36.0
let STATUS_H : CGFloat = 20.0


class WebViewController: UIViewController, WKNavigationDelegate, UIGestureRecognizerDelegate, UIActivityItemSource, UIScrollViewDelegate {
    
    var webView: WKWebView!
    
    var searchView: SearchView!
    var searchDismissScrim: UIScrollView!
    
    var webViewColor: ColorTransitionController!
    
    var statusBar: ColorStatusBarView!
    var toolbar: ColorToolbar!
    
    var errorView: UIView!
    var cardView: UIView!

    var backButton: ToolbarIconButton!
    var forwardButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var locationBar: LocationBar!
    
    var overflowController: UIAlertController!
    var stopRefreshAlertAction: UIAlertAction!
        
    var onePasswordExtensionItem : NSExtensionItem!

    // MARK: - Derived properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        guard webViewColor != nil else { return .default }
//        print("Getting status bar | dismissing: \(isInteractiveDismiss), isLight: \(webViewColor.top.isLight)")
        if isInteractiveDismiss && cardView.frame.origin.y > 15 {
            return .lightContent
        }
        return webViewColor.top.isLight ? .lightContent : .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return isInteractiveDismissToolbar
    }

    var displayTitle : String {
        get {
            guard let url = webView.url else { return "Search" }
            if isSearching { return trimText(url.searchQuery) }
            else { return displayURL }
        }
    }
    
    var displayURL : String {
        get {
            let url = webView.url!
            return url.displayHost
        }
    }
    
    func trimText(_ query: String) -> String {
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
            guard let url = webView.url else { return false }
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
        
        
        let rect = CGRect(
            origin: CGPoint(x: 0, y: STATUS_H),
            size:CGSize(
                width: UIScreen.main.bounds.size.width,
                height: UIScreen.main.bounds.size.height - TOOLBAR_H - STATUS_H
            )
        )

        webView = WKWebView(frame: rect, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self  // req'd for target=_blank override
        webView.scrollView.delegate = self
        
        webView.allowsBackForwardNavigationGestures = true
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal

//        webView.clipsToBounds = false
//        webView.scrollView.layer.masksToBounds = false
//        webView.scrollView.backgroundColor = .clear
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        cardView = UIView(frame: CGRect(
            x: 0,
            y: 0,
            width: view.frame.width,
            height: view.frame.height - TOOLBAR_H
        ))
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardView.layer.cornerRadius = 8.0
        cardView.layer.masksToBounds = true
        
        cardView.addSubview(webView)

        statusBar = ColorStatusBarView()
        cardView.addSubview(statusBar)

        toolbar = setUpToolbar()
        
        view.addSubview(toolbar)
        view.addSubview(cardView)


        searchView = SearchView(for: self)
        
        searchDismissScrim = makeScrim()
        view.addSubview(searchDismissScrim)

//        self.navigationController?.hidesBarsOnSwipe = true
        
//        let bc = BookmarksViewController()
//        bc.webViewController = self
//        bookmarksController = WebNavigationController(rootViewController: bc)
//        bookmarksController.modalTransitionStyle = .crossDissolve
//        bookmarksController.modalPresentationStyle = .overCurrentContext

        
        webViewColor = ColorTransitionController(from: webView, inViewController: self)
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(self.dismissPan))
        dismissPanner.cancelsTouchesInView = true
        view.addGestureRecognizer(dismissPanner)
        
        let toolbarDismissPanner = UIPanGestureRecognizer()
        toolbarDismissPanner.delegate = self
        toolbarDismissPanner.addTarget(self, action: #selector(self.toolbarDismissPan))
        toolbarDismissPanner.cancelsTouchesInView = true
        toolbar.addGestureRecognizer(toolbarDismissPanner)


        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        toolbar.addGestureRecognizer(longPress)
        
        if let restored : String = restoreURL() {
            navigateToText(restored)
        }
        else {
            navigateToText("evanbrooks.info")
        }
        
//        makeSuperTitle()
    }
    
    var topWindow : UIWindow!
    var topLabel : UILabel!
    func makeSuperTitle() {
        topWindow = UIWindow(frame: self.statusBar.frame)
        topWindow.windowLevel = UIWindowLevelStatusBar + 1
        
        topLabel = UILabel()
        topLabel.text = "apple.com"
//        topLabel.font = UIFont.systemFont(ofSize: 12.0)
        topLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFontWeightSemibold)
        topLabel.backgroundColor = .red
        topLabel.frame = CGRect(x: 0, y: 0, width: 290, height: STATUS_H)
        topLabel.center = topWindow.center
        topLabel.textAlignment = .center
        
        topWindow.addSubview(topLabel)
        topWindow.isHidden = false
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
    
    
    func setUpToolbar() -> ColorToolbar {
        
        // let toolbar = (navigationController?.toolbar)!
        let toolbar = ColorToolbar(frame: CGRect(
            x: 0,
            y: UIScreen.main.bounds.size.height - TOOLBAR_H,
            width: UIScreen.main.bounds.size.width,
            height: TOOLBAR_H
        ))
                
        
        backButton = ToolbarIconButton(
            icon: UIImage(named: "back"),
            onTap: { self.webView.goBack() }
        )
        forwardButton = ToolbarIconButton(
            icon: UIImage(named: "fwd"),
            onTap: { self.webView.goForward() }
        )

        let actionButton = ToolbarIconButton(
            icon: UIImage(named: "action"),
            onTap: displayOverflow
        )
        tabButton = ToolbarIconButton(
            icon: UIImage(named: "tab"),
            onTap: dismissSelf
        )
        tabButton.isHidden = true
        
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let space = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        let negSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        
        space.width = 16.0
        negSpace.width = -16.0
        
        locationBar = LocationBar(onTap: self.displaySearch)
        
        let items : [UIBarButtonItem] = [
            negSpace,
            UIBarButtonItem(customView: backButton),
            UIBarButtonItem(customView: forwardButton),
            flex,
            UIBarButtonItem(customView: locationBar),
            flex,
            UIBarButtonItem(customView: tabButton),
            UIBarButtonItem(customView: actionButton),
            negSpace
        ]
        toolbar.items = items
        
        
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
    
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Restore State

    
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
            
            displayEditMenu()
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
    }
    
    func cancelScroll() {
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentOffset.y = 0
        webView.scrollView.isScrollEnabled = true
    }

    var isInteractiveDismiss : Bool = false
    var interactiveDismissStartPoint : CGPoint = .zero

    func dismissPan(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            if webView.scrollView.contentOffset.y < 0 {
                isInteractiveDismiss = true
                interactiveDismissStartPoint = .zero
                cancelScroll()
            }
        }
            
        else if gesture.state == .changed {
            let gesturePos = gesture.translation(in: webView)

            if isInteractiveDismiss {
//                let velY = gesture.velocity(in: webView).y
                
                cardView.frame.origin.x = gesturePos.x * 0.5 - interactiveDismissStartPoint.x
                cardView.frame.origin.y = gesturePos.y - interactiveDismissStartPoint.y
                
                let progress = 1 - (abs(gesturePos.y) / 100)
                toolbar.alpha = progress
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.setNeedsStatusBarAppearanceUpdate()
                })
            }
            else {
                if webView.scrollView.contentOffset.y < 0 {
                    isInteractiveDismiss = true
                    interactiveDismissStartPoint = gesturePos
                    cancelScroll()
                }
            }
        }
            
        else if gesture.state == .ended {
            if isInteractiveDismiss {
                let gestureY = gesture.translation(in: webView).y
                if gestureY > 100 {
                    dismissSelf()
                }
                else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.cardView.frame.origin = .zero
                        self.setNeedsStatusBarAppearanceUpdate()
                        self.toolbar.alpha = 1
                    })
                }
                isInteractiveDismiss = false
            }
            

        }
    }
    
    var isInteractiveDismissToolbar : Bool = false
    var interactiveDismissToolbarStartPoint : CGPoint = .zero
    
    func toolbarDismissPan(gesture:UIPanGestureRecognizer) {
        if gesture.state == .began {
            // do nothing until the gesture gets to -20
        }
            
        else if gesture.state == .changed {
            let gesturePos = gesture.translation(in: webView)

            if isInteractiveDismissToolbar {
                cardView.frame.origin.x = gesturePos.x - interactiveDismissToolbarStartPoint.x
                cardView.frame.origin.y = gesturePos.y - interactiveDismissToolbarStartPoint.y

                let progress = 1 - (abs(gesturePos.y) / 100)
                toolbar.alpha = progress
            }
            else {
                if gesturePos.y < -20 {
                    isInteractiveDismissToolbar = true
                    interactiveDismissToolbarStartPoint = gesturePos

                    cancelScroll()
                }
            }

        }
            
        else if gesture.state == .ended {
            if isInteractiveDismissToolbar {
                let gestureY = gesture.translation(in: view).y
                if gestureY < -100 {
                    dismissSelf()
                }
                else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.cardView.frame.origin = .zero
                        self.toolbar.alpha = 1
                    })
                }
                isInteractiveDismissToolbar = false
            }
            
            
        }
    }

    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

        

    // MARK: - Actions

    func displayBookmarks() {
        let bc = BookmarksViewController()
        bc.webVC = self
        present(WebNavigationController(rootViewController: bc), animated: true)
    }
    

    // MARK: - Edit Menu / First Responder

    // This enables docked inputaccessory and long-press edit menu
    // http://stackoverflow.com/questions/19764293/inputaccessoryview-docked-at-bottom/23880574#23880574
    override var canBecomeFirstResponder : Bool {
        return true
    }
    override var inputAccessoryView:UIView{
        get { return searchView }
    }

    func displayEditMenu() {
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
    
    func copyURL() {
        UIPasteboard.general.string = self.editableURL
    }
    
    func pasteURLAndGo() {
        hideSearch()
        if let str = UIPasteboard.general.string {
            navigateToText(str)
        }
    }

    // MARK: - Search
    
    func displaySearch() {
        guard !UIMenuController.shared.isMenuVisible else { return }
        
        searchView.prepareToShow()

        let url = locationBar!
        let back = backButton!
        let tab = tabButton!

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
        let back = backButton!
        let tab = tabButton!
        
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
    
    // MARK: - Share ActivityViewController and 1Password
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.webView!.url!
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType) -> Any? {
        if OnePasswordExtension.shared().isOnePasswordExtensionActivityType(activityType.rawValue) {
            // Return the 1Password extension item
            return self.onePasswordExtensionItem
        } else {
            // Return the current URL
            return self.webView!.url!
        }
        
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        // Because of our UTI declaration, this UTI now satisfies both the 1Password Extension and the usual NSURL for Share extensions.
        return "org.appextension.fill-browser-action"
        
    }
    
    func webViewCheckFixedNav(completion: @escaping (Bool) -> Void ) {
        
        // for some reason this doesn't work during a drag. assuming document coordinates are
        // not updated live or something?
//        guard !webView.scrollView.isDragging else {
//            return
//        }

        let js = ""
        + "(function() {"
        + "function isFixed(el) {"
        + "    let pos = getComputedStyle(el).position;"
        + "    if (pos == 'fixed' || pos.includes('sticky')) {"
        + "        return true;"
        + "    }"
        + "    if (el.parentElement) {"
        + "        return isFixed(el.parentElement);"
        + "    }"
        + "    return false;"
        + "}"
        + ""
        + "let el = document.elementFromPoint(2,2);"
        + "console.log(el);"
        + "return isFixed(el);"
        + "})()"
        
        webView.evaluateJavaScript(js) { (result, error) in
            if (result != nil) {
                let isFixed : Bool = result as! Bool
                completion(isFixed)
            }
            else {
                // something went wrong
                completion(false)
            }
        }
    }
    
    func displayShareSheet() {
        self.resignFirstResponder() // without this, action sheet dismiss animation won't go all the way
        
        
        let onePass = OnePasswordExtension.shared()
        
        onePass.createExtensionItem(
            forWebView: self.webView,
            completion: { (extensionItem, error) in
                if (extensionItem == nil) {
                    print("Failed to create an extension item: \(String(describing: error))")
                    return
                }
                self.onePasswordExtensionItem = extensionItem
                
                let activityItems : [Any] = [self, self.webView.url!]
                
                let avc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
                
                avc.excludedActivityTypes = [ .addToReadingList ]
                
                avc.completionWithItemsHandler = { (type, completed, returned, error) in
                    if onePass.isOnePasswordExtensionActivityType(type?.rawValue) {
                        if (returned != nil && returned!.count > 0) {
                            onePass.fillReturnedItems(returned, intoWebView: self.webView, completion: {(success, error) in
                                if !success {
                                    print("Failed to fill into webview: \(String(describing: error))")
                                }
                            })
                        }
                    }
                }
                self.present(avc, animated: true, completion: nil)
        })
        
        
    }
    
    func updateStopRefreshAlertAction() {
        if webView.isLoading {
            stopRefreshAlertAction.setValue("Stop", forKey: "title")
        }
        else {
            stopRefreshAlertAction.setValue("Refresh", forKey: "title")
        }
        
        overflowController.view.setNeedsLayout()
        

    }
    
    func stopOrRefresh(_ action : UIAlertAction) {
        if webView.isLoading { self.webView.stopLoading() }
        else { self.webView.reload() }
    }
    
    func displayOverflow() {
        
        let ac = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)
        self.overflowController = ac
        
        if Settings.shared.blockAds.isOn {
            ac.addAction(UIAlertAction(title: "Stop Blocking Ads", style: .default, handler: { action in
                Settings.shared.blockAds.isOn = false
                self.webView.reload()
            }))
        }
        else {
            ac.addAction(UIAlertAction(title: "Block Ads", style: .default, handler: { action in
                Settings.shared.blockAds.isOn = true
                self.webView.reload()
            }))
        }
        
        ac.addAction(UIAlertAction(title: "Passwords", style: .default, handler: { action in
            self.displayPassword()
        }))
        ac.addAction(UIAlertAction(title: "Bookmarks", style: .default, handler: { action in
            self.displayBookmarks()
        }))
        ac.addAction(UIAlertAction(title: "Share", style: .default, handler: { action in
            self.displayShareSheet()
        }))
        
        stopRefreshAlertAction = UIAlertAction(title: "_", style: .destructive, handler: stopOrRefresh)
        updateStopRefreshAlertAction()
        ac.addAction(stopRefreshAlertAction)
        
        
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(ac, animated: true, completion: nil)
    }
    
    func displayPassword() {
        OnePasswordExtension.shared().fillItem(
            intoWebView: self.webView,
            for: self,
            sender: nil,
            showOnlyLogins: true,
            completion: { (success, error) in
                if success == false {
                    print("Failed to fill into webview: <\(String(describing: error))>")
                }
            }
        )
    }


    // MARK: - Webview State
    
    func openPage(action: UIAlertAction) {
        let url = URL(string: "https://" + action.title!)!
        webView.load(URLRequest(url: url))
    }
    
    func isProbablyURL(_ text: String) -> Bool {
        // TODO: Make more robust
        return text.range(of:".") != nil && text.range(of:" ") == nil
    }
    
    func navigateToText(_ text: String) {
        
        locationBar.isLoading = true
        errorView?.removeFromSuperview()

        if isProbablyURL(text) {
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
            let query = text.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
            //            let searchURL = "https://duckduckgo.com/?q="
            let searchURL = "https://www.google.com/search?q="
            let url = URL(string: searchURL + query)!
            
            if let btn = locationBar {
                btn.text = trimText(text)
            }
            
            self.webView.load(URLRequest(url: url))
        }
        
    }

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
    
    func updateLoadingUI() {
        locationBar.text = self.displayTitle
        topLabel?.text = self.displayTitle

        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching || webView.url == nil
        locationBar.isLoading = webView.isLoading
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
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
    
    func hideError() {
        errorView.removeFromSuperview()
    }

    func displayError(text: String) {
        if errorView == nil {
            errorView = UIView(frame: webView.bounds)
            errorView.frame.size.height = 120
            errorView.frame.origin.y = webView.frame.height - 120
            
//            errorView.isUserInteractionEnabled = false
            errorView.backgroundColor = .darkGray
            
            let errorLabel = UILabel()
            errorLabel.textAlignment = .natural
            errorLabel.font = UIFont.systemFont(ofSize: 15.0)
            errorLabel.numberOfLines = 0
            errorLabel.textColor = .white
            errorView.addSubview(errorLabel)
            
            let errorButton = UIButton(type: .system)
//            let errorButton = ToolbarTouchView(frame: .zero, onTap: hideError)
            errorButton.tintColor = .white
            errorButton.setTitle("Okay", for: .normal)
            errorButton.sizeToFit()
            errorButton.frame.origin.y = 20
            errorButton.frame.origin.x = errorView.frame.width - errorButton.frame.width - 20
            errorButton.addTarget(self, action: #selector(hideError), for: .primaryActionTriggered)
            errorView.addSubview(errorButton)
        }
        
        let errorLabel = errorView.subviews.first as! UILabel
        errorLabel.text = text
        let size = errorLabel.sizeThatFits(CGSize(width: 280, height: 200))
        errorLabel.frame = CGRect(origin: CGPoint(x: 20, y: 20), size: size)
//        errorLabel.center = CGPoint(
//            x: errorView.center.x,
//            y: errorView.center.y * 0.7
//        )
        
        
        webView.addSubview(errorView)
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        print("Tried to close window")
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("server redirect")
    }
        
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {

            locationBar.isLoading = webView.isLoading
            toolbar.progress = Float(webView.estimatedProgress)
            
            backButton.isEnabled = webView.canGoBack
            forwardButton.isEnabled = webView.canGoForward
            forwardButton.tintColor = webView.canGoForward ? nil : .clear
            
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

