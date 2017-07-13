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

class WebViewController: UIViewController, UIGestureRecognizerDelegate, UIActivityItemSource {
    
    var home: HomeViewController!
    var webView: WKWebView!
    
    var isDisplayingSearch : Bool = false
    var searchView: SearchView!
    var webViewColor: ColorTransitionController!
    
    var statusBar: ColorStatusBarView!
    var toolbar: ProgressToolbar!
    
    var errorView: UIView!
    var cardView: UIView!

    var backButton: ToolbarIconButton!
    var stopButton: ToolbarIconButton!
    var forwardButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var actionButton: ToolbarIconButton!
    var locationBar: LocationBar!
    
    var overflowController: UIAlertController!
//    var stopRefreshAlertAction: UIAlertAction!
        
    var onePasswordExtensionItem : NSExtensionItem!
    
    var interactiveDismissController : WebViewInteractiveDismissController!

    // MARK: - Derived properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        
        if interactiveDismissController.isInteractiveDismiss && (cardView.frame.origin.y > 10) {
            return .lightContent
        }
        
        guard webViewColor != nil else { return .default }
        return webViewColor.top.isLight ? .lightContent : .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    var shouldUpdateColors : Bool {
        return (
            isViewLoaded
            && view.window != nil
            && !interactiveDismissController.isInteractiveDismiss
            && !interactiveDismissController.isInteractiveDismissToolbar
            && UIApplication.shared.applicationState == .active
            && webView.scrollView.contentOffset.y >= 0
        )
    }
    
    var displayTitle : String {
        get {
            guard let url = webView.url else { return "" }
            if isSearching { return url.searchQuery }
            else { return displayURL }
        }
    }
    
    var displayURL : String {
        get {
            let url = webView.url!
            return url.displayHost
        }
    }
    
    var isBlank : Bool {
        return webView.url == nil
    }
    
    var isSearching : Bool {
        get {
            guard let url = webView.url else { return false }
            let searchURL = "https://duckduckgo.com/?"
            // let searchURL = "https://www.google.com/search?"
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
    
    convenience init(home: HomeViewController) {
        self.init()
        self.home = home
    }
    
    
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
        
//        webView.allowsBackForwardNavigationGestures = true
        
        // TODO: Prevent webview from layout when resizing, but allow it when 
        // screen changes size
        
//         webView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        webView.scrollView.contentInset = .zero
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { context in
            //
        }, completion: { context in
            self.updateHeight()
            self.resignFirstResponder()
        })
    }
    
    func updateHeight() {
//        self.webView.frame.size.height = UIScreen.main.bounds.size.height - TOOLBAR_H - STATUS_H
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.layer.cornerRadius = CORNER_RADIUS
        view.layer.masksToBounds = true
        
        
        cardView = UIView(frame: cardViewDefaultFrame)
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardView.layer.cornerRadius = CORNER_RADIUS
        cardView.layer.masksToBounds = true
        
        cardView.addSubview(webView)
        
        statusBar = ColorStatusBarView()
        cardView.addSubview(statusBar)
        
        searchView = SearchView(for: self)
        
        toolbar = setUpToolbar()
        
        view.addSubview(cardView)
        view.addSubview(toolbar)
        view.sendSubview(toBack: toolbar)
        
//        toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true
        
        webView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: STATUS_H).isActive = true
//        webView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        webView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        
        webView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        heightConstraint = webView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: (-STATUS_H - TOOLBAR_H))
        heightConstraint.isActive = true
        webView.heightAnchor.constraint(greaterThanOrEqualTo: cardView.heightAnchor, constant: -STATUS_H)
        
        webViewColor = ColorTransitionController(from: webView, inViewController: self)
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)

        interactiveDismissController = WebViewInteractiveDismissController(for: self)
        webView.scrollView.delegate = interactiveDismissController


        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        locationBar.addGestureRecognizer(longPress)
        
        loadingDidChange()
//        if let restored : String = restoreURL() {
//            navigateToText(restored)
//        }
//        else {
//            navigateToText("evanbrooks.info")
//        }
//        makeSuperTitle()
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    var keyboardHeight : CGFloat = 250
    @objc func keyboardWillShow(notification:NSNotification) {
        let userInfo:NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame:NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let newHeight = keyboardRectangle.height
        
        if newHeight != keyboardHeight {
            keyboardHeight = newHeight
//            UIView.animate(withDuration: 0.2, options: .curveEaseInOut, animations: {
                self.searchSizeDidChange()
//            })
        }
    }
    
    var topWindow : UIWindow!
    var topLabel : UILabel!
    func makeSuperTitle() {
        topWindow = UIWindow(frame: self.statusBar.frame)
        topWindow.windowLevel = UIWindowLevelStatusBar + 1
        
        topLabel = UILabel()
        topLabel.text = "apple.com"
//        topLabel.font = UIFont.systemFont(ofSize: 12.0)
        topLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.semibold)
        topLabel.backgroundColor = .red
        topLabel.frame = CGRect(x: 0, y: 0, width: 290, height: STATUS_H)
        topLabel.center = topWindow.center
        topLabel.textAlignment = .center
        
        topWindow.addSubview(topLabel)
        topWindow.isHidden = false
    }
        
    
    var cardViewDefaultFrame : CGRect {
        return CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height - TOOLBAR_H
        )
    }

    func setUpToolbar() -> ProgressToolbar {
        
        let toolbar = ProgressToolbar(frame: CGRect(
            x: 0,
            y: UIScreen.main.bounds.size.height - TOOLBAR_H,
            width: UIScreen.main.bounds.size.width,
            height: TOOLBAR_H
        ))
        
        locationBar = LocationBar(
            onTap: { self.displaySearch(animated: true) }
        )
        backButton = ToolbarIconButton(
            icon: UIImage(named: "back"),
            onTap: { self.webView.goBack() }
        )
        forwardButton = ToolbarIconButton(
            icon: UIImage(named: "fwd"),
            onTap: { self.webView.goForward() }
        )
        actionButton = ToolbarIconButton(
            icon: UIImage(named: "action"),
            onTap: displayOverflow
        )
        stopButton = ToolbarIconButton(
            icon: UIImage(named: "stop"),
            onTap: { self.webView.stopLoading() }
        )

        toolbar.items = [backButton, forwardButton, locationBar, stopButton, actionButton]
        
        toolbar.addSubview(searchView)
        
        searchView.topAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        searchView.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
        
        return toolbar
    }
    
    var webSnapshot : UIView?
    func updateSnapshot() {
        webView.scrollView.showsVerticalScrollIndicator = false
        webSnapshot = webView.snapshotView(afterScreenUpdates: true)!
        webView.scrollView.showsVerticalScrollIndicator = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if isBlank {
            displaySearch()
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        webView.scrollView.contentInset = .zero
        self.setNeedsStatusBarAppearanceUpdate()

        
        webViewColor.startUpdates()

        // disable mysterious delays
        // https://stackoverflow.com/questions/19799961/uisystemgategesturerecognizer-and-delayed-taps-near-bottom-of-screen
        let window = view.window!
        let gr0 = window.gestureRecognizers![0] as UIGestureRecognizer
        let gr1 = window.gestureRecognizers![1] as UIGestureRecognizer
        gr0.delaysTouchesBegan = false
        gr1.delaysTouchesBegan = false
        
    }
    var heightConstraint : NSLayoutConstraint!
    
    override func viewWillLayoutSubviews() {
        // because it keeps getting deactivated every time
        // the view is removed from the hierarchy
        heightConstraint.isActive = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        // This is probably called too often, should only be when app closes
        
        webViewColor.stopUpdates()
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
    
    @objc func longPressURL(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            
            displayEditMenu()
            recognizer.isEnabled = false
            recognizer.isEnabled = true
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
//    override var inputAccessoryView:UIView{
//        get { return searchView }
//    }
    
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
    
    @objc func copyURL() {
        UIPasteboard.general.string = self.editableURL
    }
    
    @objc func pasteURLAndGo() {
        hideSearch()
        if let str = UIPasteboard.general.string {
            navigateToText(str)
        }
    }

    // MARK: - Search
    
    func displaySearch(animated: Bool = false) {
        guard !UIMenuController.shared.isMenuVisible else { return }
        
        isDisplayingSearch = true
        searchView.prepareToShow()
        
        if !searchView.textView.isFirstResponder {
            searchView.textView.becomeFirstResponder()
        }
        
        // NOTE: we probably don't have the true keyboard height yet
        
        let cardH = cardViewDefaultFrame.height - keyboardHeight - searchView.frame.height + TOOLBAR_H
        
        self.locationBar.setAlignment(.left)
        
        if animated {
            UIView.animate(
                withDuration: 0.55,
                delay: 0.0,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.0,
                options: [.curveLinear, .allowUserInteraction],
                animations: {
                    
                self.cardView.frame.size.height = cardH
                self.toolbar.frame.origin.y = cardH
                self.toolbar.frame.size.height = self.searchView.frame.height
                self.locationBar.alpha = 0
                self.toolbar.layoutIfNeeded()
                
                
                self.backButton.isHidden = true
                self.forwardButton.isHidden = true
                self.stopButton.isHidden = true
                self.actionButton.isHidden = true
                
                self.actionButton.alpha = 0
            })
        }
        else {
            self.cardView.frame.size.height = cardH
            self.toolbar.frame.origin.y = cardH
            self.toolbar.frame.size.height = self.searchView.frame.height
            self.locationBar.alpha = 0
            self.toolbar.layoutIfNeeded()
            
            
            self.backButton.isHidden = true
            self.forwardButton.isHidden = true
            self.stopButton.isHidden = true
            self.actionButton.isHidden = true
            
            self.actionButton.alpha = 0
            
        }
        
    }
    
    @objc func hideSearch() {
        
        isDisplayingSearch = false
        
        if searchView.textView.isFirstResponder {
            searchView.textView.resignFirstResponder()
        }
        
        self.locationBar.setAlignment(.centered)
        
        UIView.animate(
            withDuration: 0.55,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: [.curveLinear, .allowUserInteraction],
            animations: {
//            self.searchDismissScrim.alpha = 0
            
            self.cardView.frame = self.cardViewDefaultFrame
            self.toolbar.frame.origin.y = self.cardViewDefaultFrame.height
            self.toolbar?.frame.size.height = TOOLBAR_H
            self.locationBar.alpha = 1
            
            self.toolbar.layoutIfNeeded()
            
            self.backButton.isHidden = false
            self.forwardButton.isHidden = false
            self.stopButton.isHidden = false
            self.actionButton.isHidden = false
            
            self.actionButton.alpha = 1
        })
    }
    
    
    func searchSizeDidChange() {
        if searchView != nil && searchView.textView.isFirstResponder {
            let cardH = cardViewDefaultFrame.height - keyboardHeight - searchView.frame.height + TOOLBAR_H
            
            self.cardView?.frame.size.height = cardH
            self.toolbar?.frame.origin.y = cardH
            self.toolbar?.frame.size.height = self.searchView.frame.height
                
        }
    }

    
    // MARK: - Share ActivityViewController and 1Password
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.webView!.url!
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType?) -> Any? {
        if OnePasswordExtension.shared().isOnePasswordExtensionActivityType(activityType?.rawValue) {
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
    
    @objc func displayShareSheet() {
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
    
//    func updateStopRefreshAlertAction() {
//        if webView.isLoading {
//            stopRefreshAlertAction.setValue("Stop", forKey: "title")
//        }
//        else {
//            stopRefreshAlertAction.setValue("Refresh", forKey: "title")
//        }
//
//        overflowController.view.setNeedsLayout()
//    }
    
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
        ac.addAction(UIAlertAction(title: "Share...", style: .default, handler: { action in
            self.displayShareSheet()
        }))
        
//        stopRefreshAlertAction = UIAlertAction(title: "_", style: .destructive, handler: stopOrRefresh)
//        updateStopRefreshAlertAction()
//        ac.addAction(stopRefreshAlertAction)
        
        
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
            let searchURL = "https://duckduckgo.com/?q="
//            let searchURL = "https://www.google.com/search?q="
            let url = URL(string: searchURL + query)!
            
            if let btn = locationBar {
                btn.text = text
            }
            
            self.webView.load(URLRequest(url: url))
        }
        
    }
    
    @objc func hideError() {
        errorView.removeFromSuperview()
    }

    func displayError(text: String) {
        if errorView == nil {
            let ERROR_H : CGFloat = 80
            errorView = UIView(frame: webView.bounds)
            errorView.frame.size.height = ERROR_H
            errorView.frame.origin.y = webView.frame.height - ERROR_H
            
//            errorView.isUserInteractionEnabled = false
            errorView.backgroundColor = UIColor.red
            
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
        
        webView.addSubview(errorView)
    }
    
    
    func resetSizes(withKeyboard : Bool = false) {
        view.frame = UIScreen.main.bounds
        statusBar.frame.origin.y = 0
        webView.frame.origin.y = STATUS_H
        view.transform = .identity
        cardView.frame = cardViewDefaultFrame
        
        if isBlank && withKeyboard {
            // hack for better transition with keyboard
            cardView.frame.size.height = cardViewDefaultFrame.height - keyboardHeight - searchView.frame.height + TOOLBAR_H
        }
        
        toolbar.alpha = 1
    }
    
    func loadingDidChange() {
        
        locationBar.text = self.displayTitle
        
        let small = CGAffineTransform(scaleX: 0.6, y: 0.6)
        
        UIView.animate(withDuration: 0.25) {
            self.backButton.isEnabled = self.webView.canGoBack
            
            self.forwardButton.isEnabled = self.webView.canGoForward
            self.forwardButton.tintColor = self.webView.canGoForward ? nil : .clear
            self.forwardButton.transform = self.webView.canGoForward ? .identity : small
            
            self.stopButton.isEnabled = self.webView.isLoading
            self.stopButton.tintColor = self.webView.isLoading ? nil : .clear
            self.stopButton.transform = self.webView.isLoading ? .identity : small
            
//            self.forwardButton.isHidden = !self.webView.canGoForward
//            self.stopButton.isHidden = !self.webView.isLoading
        }
        
        
        locationBar.isLoading = webView.isLoading
        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching || isBlank
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            toolbar.progress = Float(webView.estimatedProgress)
            
            loadingDidChange()
        }
        else if keyPath == "title" {
            loadingDidChange()
            
            if (webView.title != "" && webView.title != title) {
                title = webView.title
                print("Title change: \(title!)")
            }
        }
        else if keyPath == "url" {
            loadingDidChange()
        }
    }

}

