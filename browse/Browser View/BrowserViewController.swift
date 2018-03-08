//
//  BrowserViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/11/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import OnePasswordExtension
import pop

class BrowserViewController: UIViewController, UIGestureRecognizerDelegate, UIActivityItemSource {
    
    var home: TabSwitcherViewController!
    var webView: WKWebView!
    var snap: UIImageView = UIImageView()
    var browserTab: BrowserTab?
    
    var topConstraint : NSLayoutConstraint!
    var accessoryHeightConstraint : NSLayoutConstraint!
    var toolbarHeightConstraint : NSLayoutConstraint!
    var aspectConstraint : NSLayoutConstraint!
    var statusHeightConstraint : NSLayoutConstraint!

    var isDisplayingSearch : Bool = false
    var colorSampler: WebviewColorSampler!
    
    lazy var searchVC = TypeaheadViewController()

    
    var statusBar: ColorStatusBarView!
    
    var toolbar: ProgressToolbar!
    var toolbarPlaceholder = UIView()
    var accessoryView: GradientColorChangeView!
    
    var errorView: UIView!
    var cardView: UIView!
    var contentView: UIView!
    var overlay: UIView!
    var gradientOverlay: GradientView!
    
    var backButton: ToolbarIconButton!
    var stopButton: ToolbarIconButton!
    var forwardButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var locationBar: LocationBar!
    
    var overflowController: UIAlertController!
        
    var onePasswordExtensionItem : NSExtensionItem!
    
    var gestureController : BrowserGestureController!

    // MARK: - Derived properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if gestureController.isInteractiveDismiss && (cardView.frame.origin.y > 10) {
            return .lightContent
        }
        return statusBar.lastColor.isLight ? .lightContent : .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    var isShowingToolbar : Bool {
        return toolbarHeightConstraint.constant > 0
    }
    
    var displayTitle : String {
        guard let url = webView?.url else { return "" }
        if isSearching { return url.searchQuery }
        else { return displayURL }
    }
    
    var displayURL : String {
        get {
            let url = webView.url!
            return url.displayHost
        }
    }
    
    var isBlank : Bool {
        return (webView?.url == nil) ?? false
    }
    
    var isSearching : Bool {
        get {
            guard let url = webView.url else { return false }
//            let searchURL = "https://duckduckgo.com/?"
//             let searchURL = "https://www.google.com/search?"
//            return url.absoluteString.hasPrefix(searchURL)
            return url.absoluteString.contains("google") && url.absoluteString.contains("?q=")
        }
    }
    
    var editableLocation : String {
        get {
            guard let url = webView?.url else { return "" }
            if isSearching { return url.searchQuery }
            else { return url.absoluteString }
        }
    }
    
    var hiddenUntilNavigationDone = false
    
    func hideUntilNavigationDone() {
        isSnapshotMode = true
        hiddenUntilNavigationDone = true
    }
    
    
    // MARK: - Lifecycle
    
    convenience init(home: TabSwitcherViewController) {
        self.init()
        self.home = home
    }
    
    
    func setTab(_ newTab: BrowserTab ) {
        if newTab === browserTab { return }
        
        let oldWebView = webView
        
        oldWebView?.removeFromSuperview()
        
        oldWebView?.uiDelegate = nil
        oldWebView?.navigationDelegate = nil
        oldWebView?.scrollView.delegate = nil

        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward))
        
        browserTab = newTab
        webView = newTab.webView
        
        if let img = newTab.history.current?.snapshot {
            snap.image = img
//            updateSnapshotPosition()
        }
        else {
            snap.image = nil
        }
        
        if let newTop = newTab.history.current?.topColor {
            statusBar.update(toColor: newTop)
        }
        else {
            statusBar.update(toColor: .white)
        }
        if let newBottom = newTab.history.current?.bottomColor {
            toolbar.update(toColor: newBottom)
        }
        else {
            toolbar.update(toColor: .white)
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.delegate = gestureController
        webView.scrollView.isScrollEnabled = true
                
        contentView.insertSubview(webView, belowSubview: snap)
        //        topConstraint = webView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Const.statusHeight)
        topConstraint = webView.topAnchor.constraint(equalTo: statusBar.bottomAnchor)
        topConstraint.isActive = true
        
        webView.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        webView.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -Const.toolbarHeight).isActive = true
//        webView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: (-Const.statusHeight - Const.toolbarHeight)).isActive = true
        toolbarPlaceholder.topAnchor.constraint(equalTo: webView.bottomAnchor).isActive = true
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.title), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoBack), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.canGoForward), options: .new, context: nil)
        
        webView.addInputAccessory(toolbar: accessoryView)
        
        loadingDidChange()
        
        if let location = browserTab?.restoredLocation {
            if location != "" && isBlank {
                navigateToText(location)
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let isLandscape = size.width > size.height
        statusHeightConstraint.constant = isLandscape ? 0 : Const.statusHeight

//        coordinator.animate(alongsideTransition: { context in
//            //
//        }, completion: { context in
//            //
//        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        cardView = UIView(frame: cardViewDefaultFrame)
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        cardView.layer.shadowRadius = 24
//        cardView.layer.shadowOpacity = 0.16

        contentView = UIView(frame: cardViewDefaultFrame)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.radius = Const.shared.cardRadius
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .white

        overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0
        
        gradientOverlay = GradientView(frame: view.bounds)
        gradientOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gradientOverlay.alpha = 0
        
        view.addSubview(cardView)
        cardView.addSubview(contentView)
        
        statusBar = ColorStatusBarView()
        
        toolbar = setUpToolbar()
        
        toolbarPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        toolbarPlaceholder.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapToolbarPlaceholder))
        toolbarPlaceholder.addGestureRecognizer(tap)
        
        contentView.addSubview(toolbarPlaceholder)
        
        
        snap.contentMode = .scaleAspectFill
        snap.translatesAutoresizingMaskIntoConstraints = false
        snap.frame.size = CGSize(
            width: cardView.bounds.width,
            height: cardView.bounds.height - Const.statusHeight - Const.toolbarHeight
        )
        
        contentView.addSubview(snap)
        contentView.addSubview(toolbar)
        contentView.addSubview(statusBar)
        
        contentView.bringSubview(toFront: statusBar)
        contentView.bringSubview(toFront: toolbar)
        
        contentView.addSubview(overlay)
        contentView.addSubview(gradientOverlay)
        
        constrain4(contentView, overlay)
        constrainTop3(contentView, gradientOverlay)
        gradientOverlay.heightAnchor.constraint(equalToConstant: THUMB_H)

        constrainTop3(statusBar, contentView)
        statusHeightConstraint = statusBar.heightAnchor.constraint(equalToConstant: Const.statusHeight)
        statusHeightConstraint.isActive = true
        
        snap.topAnchor.constraint(equalTo: statusBar.bottomAnchor).isActive = true
        snap.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        snap.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
        snap.isHidden = true
        
        aspectConstraint = snap.heightAnchor.constraint(equalTo: snap.widthAnchor, multiplier: 1)
        aspectConstraint.isActive = true
        
        toolbar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true
        toolbar.bottomAnchor.constraint(equalTo: toolbarPlaceholder.bottomAnchor).isActive = true
        
        toolbarPlaceholder.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        toolbarPlaceholder.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
        toolbarPlaceholder.heightAnchor.constraint(equalToConstant: Const.toolbarHeight).isActive = true
        
        accessoryView = setupAccessoryView()
        
        colorSampler = WebviewColorSampler()
        colorSampler.delegate = self
        
        gestureController = BrowserGestureController(for: self)
        
        let historyPress = UILongPressGestureRecognizer(target: self, action: #selector(showHistory))
        backButton.addGestureRecognizer(historyPress)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    }
    
    @objc func showHistory(_ : Any?) {
        let history = HistoryViewController(collectionViewLayout: UICollectionViewFlowLayout() )
        let hNav = UINavigationController(rootViewController: history)
        present(hNav, animated: true, completion: nil)
    }
    
    var topWindow : UIWindow!
    var topLabel : UILabel!
    
    var cardViewDefaultFrame : CGRect {
        return CGRect(
            x: 0,
            y: 0,
            width: UIScreen.main.bounds.width,
            height: UIScreen.main.bounds.height// - Const.shared.toolbarHeight
        )
    }
    
    func hideToolbar(animated : Bool = true) {
        if !webView.scrollView.isScrollable { return }
        if webView.isLoading { return }
        if isDisplayingSearch { return }
        if toolbarHeightConstraint.constant == 0 { return }
        
//        toolbarHeightConstraint.constant = 0
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                self.webView.scrollView.scrollIndicatorInsets.bottom = -Const.toolbarHeight

                self.locationBar.alpha = 0
                self.backButton.alpha = 0
                self.tabButton.alpha = 0
                
//                self.view.layoutIfNeeded()
            }
        )
        toolbarHeightConstraint.springConstant(to: 0)
        webView.scrollView.springBottomInset(to: -Const.toolbarHeight)

    }
    @objc func tapToolbarPlaceholder() {
        showToolbar(adjustScroll: true)
    }
    func showToolbar(animated: Bool = true, adjustScroll: Bool = false) {
        if isDisplayingSearch { return }
        if toolbarHeightConstraint.constant == Const.toolbarHeight { return }
        
        let dist = Const.toolbarHeight - toolbarHeightConstraint.constant

//        toolbarHeightConstraint.constant = Const.toolbarHeight

        if (animated) {
            UIView.animate(
                withDuration: animated ? 0.2 : 0,
                delay: 0,
                options: [.curveEaseInOut, .allowAnimatedContent],
                animations: {
                    self.webView.scrollView.scrollIndicatorInsets.bottom = 0
                    self.locationBar.alpha = 1
                    self.backButton.alpha = 1
                    self.tabButton.alpha = 1
            }
            )
            
            toolbarHeightConstraint.springConstant(to: Const.toolbarHeight)
            webView.scrollView.springBottomInset(to: 0)
            if adjustScroll {
                var newOffset = webView.scrollView.contentOffset
                newOffset.y += dist
                webView.scrollView.springContentOffset(to: newOffset)
            }
        }
        else {
            toolbarHeightConstraint.constant = Const.toolbarHeight
            webView.scrollView.contentInset.bottom = 0
            webView.scrollView.scrollIndicatorInsets.bottom = 0
            locationBar.alpha = 1
            backButton.alpha = 1
            tabButton.alpha = 1
        }
    }

    func setUpToolbar() -> ProgressToolbar {
        
        let toolbar = ProgressToolbar(frame: CGRect(
            x: 0,
            y: 0,
            width: cardView.frame.width,
            height: Const.toolbarHeight
        ))
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarHeightConstraint = toolbar.heightAnchor.constraint(equalToConstant: Const.toolbarHeight)
        toolbarHeightConstraint.isActive = true
        
        locationBar = LocationBar(
            onTap: { self.displayFullSearch(animated: true) }
//            onTap: { self.displayOverflow() }
        )
        backButton = ToolbarIconButton(
            icon: UIImage(named: "back"),
            onTap: {
                if self.webView.canGoBack {
                    self.webView.goBack()
                }
                else if let parent = self.browserTab?.parentTab {
                    self.gestureController.swapTo(parentTab: parent)
                }
            }
        )
        forwardButton = ToolbarIconButton(
            icon: UIImage(named: "fwd"),
            onTap: { self.webView.goForward() }
        )
        tabButton = ToolbarIconButton(
            icon: UIImage(named: "tab"),
            onTap: dismissSelf
        )
        stopButton = ToolbarIconButton(
            icon: UIImage(named: "stop"),
            onTap: { self.webView.stopLoading() }
        )
        
        locationBar.addSubview(stopButton)
        stopButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
        stopButton.frame.origin.x = locationBar.frame.width - stopButton.frame.width

        toolbar.items = [backButton, locationBar, tabButton]
        
        toolbar.tintColor = .darkText
        return toolbar
    }
    
    func displayFullSearch(animated: Bool = true) {
        searchVC.setBackground(toolbar.lastColor)
        present(searchVC, animated: true, completion: nil)
    }
    
    func setupAccessoryView() -> GradientColorChangeView {
        let acc = GradientColorChangeView(frame: CGRect(x: 0, y: 0, width: 375, height: 48))
        acc.tintColor = UIColor.darkText
        acc.backgroundColor = UIColor(r: 0.83, g: 0.84, b: 0.85).withAlphaComponent(0.95)
//        acc.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        let blur = PlainBlurView(frame: acc.frame)
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        acc.addSubview(blur)
        
        let dismissButton = ToolbarTextButton(title: "Done", withIcon: nil) {
            UIResponder.firstResponder()?.resignFirstResponder()
        }
        dismissButton.size = .medium
        dismissButton.sizeToFit()
        acc.addSubview(dismissButton)
        dismissButton.autoresizingMask = .flexibleLeftMargin
        dismissButton.frame.origin.x = acc.frame.width - dismissButton.frame.width
        
        let passButton = ToolbarIconButton(icon: UIImage(named: "key")) {
            self.displayPassword()
        }
        
        accessoryHeightConstraint = acc.heightAnchor.constraint(equalToConstant: 24)
        accessoryHeightConstraint.isActive = true
        
//        passButton.frame.size.height = acc.frame.height
        passButton.autoresizingMask = .flexibleLeftMargin
        passButton.frame.origin.x = dismissButton.frame.origin.x - passButton.frame.width - 8
        
        acc.addSubview(passButton)
        
        return acc
    }
    
    var isSnapshotMode : Bool {
        get {
            return !snap.isHidden
        }
        set {
            if newValue {
                snap.isHidden = false
                webView.isHidden = true
            } else {
                webView.isHidden = false
                snap.isHidden = true
            }
        }
    }
    
    func updateSnapshot(then done: @escaping () -> Void = { }) {
        guard !webView.isHidden else {
            done()
            return
        }
        // Image snapshot
        browserTab?.updateSnapshot(completionHandler: { img in
            self.setSnapshot(img)
            done()
        })
    }
    
    func setSnapshot(_ image : UIImage?) {
        guard let image = image else {
            return
        }
        snap.image = image
        
        let newAspect = image.size.height / image.size.width
        if newAspect != self.aspectConstraint.multiplier {
            self.snap.removeConstraint(self.aspectConstraint)
            self.aspectConstraint = self.snap.heightAnchor.constraint(equalTo: self.snap.widthAnchor, multiplier: newAspect, constant: 0)
            self.aspectConstraint.isActive = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        showToolbar(animated: false)
        statusBar.backgroundView.alpha = 1
        toolbar.backgroundView.alpha = 1
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        hideToolbar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        webView.scrollView.contentInset = .zero
        self.setNeedsStatusBarAppearanceUpdate()

        self.colorSampler.startUpdates()
        
//         disable mysterious delays
//         https://stackoverflow.com/questions/19799961/uisystemgategesturerecognizer-and-delayed-taps-near-bottom-of-screen
        let window = view.window!
        let gr0 = window.gestureRecognizers![0] as UIGestureRecognizer
        let gr1 = window.gestureRecognizers![1] as UIGestureRecognizer
        gr0.delaysTouchesBegan = false
        gr1.delaysTouchesBegan = false
    }

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("BrowserVC received memory warning")
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        colorSampler.stopUpdates()
    }
    
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Gestures
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Actions

    func displayBookmarks() {
        let bc = BookmarksViewController()
        bc.browserVC = self
        present(WebNavigationController(rootViewController: bc), animated: true)
    }
    
    
    @objc func copyURL() {
        UIPasteboard.general.string = self.editableLocation
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
    
    func makeShareSheet(completion: @escaping (UIActivityViewController) -> ()) {
        if webView.url == nil { return }
        
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
                completion(avc)
        })
    }
    
    @objc func displayShareSheet() {
        self.resignFirstResponder() // without this, action sheet dismiss animation won't go all the way
        makeShareSheet { avc in
            self.present(avc, animated: true, completion: nil)
        }
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
        var url : URL
        
        if isProbablyURL(text) {
            if (text.hasPrefix("http://") || text.hasPrefix("https://")) {
                url = URL(string: text)!
                if let btn = locationBar { btn.text = url.displayHost }
            }
            else {
                url = URL(string: "http://" + text)!
                if let btn = locationBar { btn.text = url.displayHost }
            }
        }
        else {
            url = Typeahead.shared.serpURLfor(text)!
            if let btn = locationBar {
                btn.text = text
            }
        }
        locationBar.progress = 0
        
        // Does it feel faster if old page instantle disappears?
        hideUntilNavigationDone()
        snap.image = nil
        toolbar.update(toColor:.white)
        statusBar.update(toColor:.white)
        
        webView.load(URLRequest(url: url))
    }
    
    @objc func hideError() {
        errorView.removeFromSuperview()
    }
    
    func makeError() -> UIView {
        let ev = UIView(frame: view.bounds)
        ev.translatesAutoresizingMaskIntoConstraints = false
        ev.backgroundColor = UIColor.red
        
        let errorLabel = UILabel()
        errorLabel.textAlignment = .natural
        errorLabel.font = UIFont.systemFont(ofSize: 16.0)
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .white
        ev.addSubview(errorLabel)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideError))
        ev.addGestureRecognizer(tap)
        
        return ev
    }

    func displayError(text: String) {
        if errorView == nil { errorView = makeError() }
        
        errorView.backgroundColor = toolbar.lastColor
        let errorLabel = errorView.subviews.first as! UILabel
        errorLabel.text = text
        errorLabel.textColor = toolbar.tintColor
        let size = errorLabel.sizeThatFits(CGSize(width: cardView.bounds.size.width - 40, height: 200))
        errorLabel.frame = CGRect(origin: CGPoint(x: 20, y: 20), size: size)
        
        cardView.addSubview(errorView)
        
        errorView.leftAnchor.constraint(equalTo: cardView.leftAnchor).isActive = true
        errorView.rightAnchor.constraint(equalTo: cardView.rightAnchor).isActive = true
        errorView.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        errorView.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
    
    func resetSizes(withKeyboard : Bool = false) {
        view.frame = UIScreen.main.bounds
        webView.frame.origin.y = Const.statusHeight
        cardView.transform = .identity
        cardView.bounds.size = cardViewDefaultFrame.size
        cardView.center = view.center        
    }
    
    func loadingDidChange() {
        guard isViewLoaded else { return }
        
        locationBar.text = self.displayTitle
        
        UIView.animate(withDuration: 0.25) {
            self.backButton.isEnabled = self.webView.canGoBack || self.browserTab!.canGoBackToParent
            
            self.forwardButton.isEnabled = self.webView.canGoForward
            self.forwardButton.tintColor = self.webView.canGoForward ? nil : .clear
            self.forwardButton.scale = self.webView.canGoForward ? 1 : 0.6
            
            self.stopButton.isEnabled = self.webView.isLoading
            self.stopButton.tintColor = self.webView.isLoading ? nil : .clear
            self.stopButton.scale = self.webView.isLoading ? 1 : 0.6
        }
        
        if self.webView.isLoading {
            showToolbar()
        }
        
        locationBar.isLoading = webView.isLoading
        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching || isBlank
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
        
        if hiddenUntilNavigationDone && webView.estimatedProgress > 0.7 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hiddenUntilNavigationDone = false
                self.isSnapshotMode = false
            }
        }
        
        browserTab?.updateHistory()
    }
        
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            toolbar.progress = Float(webView.estimatedProgress)
            locationBar.progress = CGFloat(webView.estimatedProgress)
        }
        loadingDidChange()
    }
}

private weak var currentFirstResponder: UIResponder?

extension UIResponder {
    
    static func firstResponder() -> UIResponder? {
        currentFirstResponder = nil
        UIApplication.shared.sendAction(#selector(self.findFirstResponder), to: nil, from: nil, for: nil)
        return currentFirstResponder
    }
    
    @objc func findFirstResponder(sender: AnyObject) {
        currentFirstResponder = self
    }
    
}


extension BrowserViewController : WebviewColorSamplerDelegate {
    var sampledWebView : WKWebView {
        return webView
    }
    
    var shouldUpdateSample : Bool {
        return (
            isViewLoaded
                && view.window != nil
                && !gestureController.isInteractiveDismiss
                && UIApplication.shared.applicationState == .active
                && webView != nil
                && !hiddenUntilNavigationDone
                && !(webView.scrollView.contentOffset.y < 0)
//                && abs(cardView.frame.origin.y) < 1.0
//                && abs(cardView.frame.origin.x) < 1.0
        )
    }
    
    var bottomSamplePosition : CGFloat {
        return cardView.bounds.height - Const.statusHeight - toolbarHeightConstraint.constant
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let newHeight = keyboardRectangle.height
        
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = newHeight < 50 ? 0 : 48
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint?.constant = 0
    }

    
    func topColorChange(_ newColor: UIColor) {
        browserTab?.history.current?.topColor = newColor // this is a hack
        
        webView.evaluateFixedNav() { (isFixed) in
            let sv = self.webView.scrollView
            
            let newAlpha : CGFloat = (
                sv.isScrollable
                && sv.contentOffset.y > Const.statusHeight
                && !isFixed
            ) ? 0.8 : 1
            if newAlpha != self.statusBar.backgroundView.alpha {
                UIView.animate(withDuration: 0.6, delay: 0, options: [.beginFromCurrentState], animations: {
                    self.statusBar.backgroundView.alpha = newAlpha
                })
            }
        }
        
        if shouldUpdateSample {
            
            let didChange = statusBar.animateGradient(toColor: newColor, direction: .fromBottom)

            UIView.animate(withDuration: 0.6, delay: 0, options: [.beginFromCurrentState], animations: {
                self.setNeedsStatusBarAppearanceUpdate()
            })
        }
    }
    
    func bottomColorChange(_ newColor: UIColor) {
        browserTab?.history.current?.bottomColor = newColor
        
        
        let newAlpha : CGFloat = webView.scrollView.isScrollable ? 0.8 : 1
        if newAlpha != self.toolbar.backgroundView.alpha {
            UIView.animate(withDuration: 0.6, delay: 0, options: [.beginFromCurrentState], animations: {
                self.toolbar.backgroundView.alpha = newAlpha
            })
        }

        if shouldUpdateSample {
            let _ = toolbar.animateGradient(toColor: newColor, direction: .fromTop)
        }

    }
    
    func cancelColorChange() {
        statusBar.cancelColorChange()
        toolbar.cancelColorChange()
    }
}

