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
    
    var home: HomeViewController!
    var webView: WKWebView!
    var snap: UIImageView = UIImageView()
    var browserTab: BrowserTab?
    
    var topConstraint : NSLayoutConstraint!
    var accessoryHeightConstraint : NSLayoutConstraint!
    var toolbarHeightConstraint : NSLayoutConstraint!
    var toolbarBottomConstraint : NSLayoutConstraint!

    var isDisplayingSearch : Bool = false
    var searchView: SearchView!
    var colorSampler: WebviewColorSampler!
    
    var statusBarBack: ColorStatusBarView!
    var statusBarFront: ColorStatusBarView!
    var statusBarShadow: UIView!
    
    var toolbar: ProgressToolbar!
    var toolbarHiddenPlaceholder = UIView()
    var accessoryView: GradientColorChangeView!
    
    var errorView: UIView!
    var cardView: UIView!
    var roundedClipView: UIView!
    var overlay: UIView!

    let keyboardBack = UIView()
    
    var backButton: ToolbarIconButton!
    var stopButton: ToolbarIconButton!
    var forwardButton: ToolbarIconButton!
    var tabButton: ToolbarIconButton!
    var actionButton: ToolbarIconButton!
    var locationBar: LocationBar!
    
    var overflowController: UIAlertController!
        
    var onePasswordExtensionItem : NSExtensionItem!
    
    var gestureController : BrowserGestureController!

    // MARK: - Derived properties
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if gestureController.isInteractiveDismiss && (cardView.frame.origin.y > 10) {
            return .lightContent
        }
        return (browserTab?.history.current?.topColor?.isLight ?? true) ? .lightContent : .default
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
        return webView.url == nil
    }
    
    var isSearching : Bool {
        get {
            guard let url = webView.url else { return false }
//            let searchURL = "https://duckduckgo.com/?"
             let searchURL = "https://www.google.com/search?"
            return url.absoluteString.hasPrefix(searchURL)
        }
    }
    
    var editableLocation : String {
        get {
            guard let url = webView?.url else { return "" }
            if isSearching { return url.searchQuery }
            else { return url.absoluteString }
        }
    }
    
    var hideUntilNavigationDone : Bool {
        get {
            return isSnapshotMode
        }
        set {
//            webView.alpha = newValue ? 0 : 1
            isSnapshotMode = newValue
        }
    }
    
    
    // MARK: - Lifecycle
    
    convenience init(home: HomeViewController) {
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
            updateSnapshotPosition()
        }
        else {
            snap.image = nil
        }
        
        if let newTop = newTab.history.current?.topColor {
            statusBarFront.backgroundColor = newTop
            // TODO: just need to reset tint color, dont need animate gradient
            let _ = statusBarFront.animateGradient(toColor: newTop, direction: .fromBottom)
        }
        else {
            statusBarFront.backgroundColor = .white
        }
        if let newBottom = newTab.history.current?.bottomColor {
//            toolbar.backgroundColor = newBottom
            roundedClipView.backgroundColor = newBottom
            webView.backgroundColor = newBottom
            // TODO: just need to reset tint color, dont need animate gradient
            let _ = toolbar.animateGradient(toColor: newBottom, direction: .fromTop)
        }
        else {
//            toolbar.backgroundColor = .white
            roundedClipView.backgroundColor = .white
            webView.backgroundColor = .white
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.delegate = gestureController
                
        roundedClipView.addSubview(webView)
        roundedClipView.insertSubview(webView, aboveSubview: statusBarBack)
        
        topConstraint = webView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Const.shared.statusHeight)
        topConstraint.isActive = true
        
        webView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        webView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        webView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: (-Const.shared.statusHeight - Const.shared.toolbarHeight)).isActive = true
        
        
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
        coordinator.animate(alongsideTransition: { context in
            //
        }, completion: { context in
            //
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        cardView = UIView(frame: cardViewDefaultFrame)
        cardView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cardView.layer.shadowRadius = 24
        cardView.layer.shadowOpacity = 0.16

        roundedClipView = UIView(frame: cardViewDefaultFrame)
        roundedClipView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        roundedClipView.layer.cornerRadius = Const.shared.cardRadius
        roundedClipView.layer.masksToBounds = true
        
        overlay = UIView(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0
        roundedClipView.addSubview(overlay)
        
        view.addSubview(cardView)
        cardView.addSubview(roundedClipView)
        
        statusBarFront = ColorStatusBarView()
        statusBarBack = ColorStatusBarView()
        
        
//        statusBarShadow = UIView(frame: CGRect(x: 20, y: 12, width: 54, height: 24))
//        statusBarShadow = PlainBlurView(frame:  CGRect(x: 20, y: 12, width: 54, height: 24))
//        statusBarShadow.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
//        statusBarShadow.clipsToBounds = true
//        statusBarShadow.layer.cornerRadius = 12

//        roundedClipView.addSubview(statusBarShadow)
        roundedClipView.addSubview(statusBarFront)
        roundedClipView.addSubview(statusBarBack)
        roundedClipView.sendSubview(toBack: statusBarBack)
        

        searchView = SearchView(for: self)
        
        toolbar = setUpToolbar()
        
        toolbarHiddenPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        toolbarHiddenPlaceholder.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.tapToolbarPlaceholder))
        toolbarHiddenPlaceholder.addGestureRecognizer(tap)
        
        roundedClipView.addSubview(toolbarHiddenPlaceholder)

        roundedClipView.addSubview(toolbar)
        roundedClipView.bringSubview(toFront: toolbar)
        roundedClipView.addSubview(snap)

        toolbar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true
        toolbarBottomConstraint = toolbar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        toolbarBottomConstraint.isActive = true
        
        toolbarHiddenPlaceholder.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        toolbarHiddenPlaceholder.widthAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true
        toolbarHiddenPlaceholder.bottomAnchor.constraint(equalTo: cardView.bottomAnchor).isActive = true
        toolbarHiddenPlaceholder.heightAnchor.constraint(equalToConstant: Const.shared.toolbarHeight).isActive = true


        keyboardBack.translatesAutoresizingMaskIntoConstraints = false
        keyboardBack.backgroundColor = .cyan
//        roundedClipView.addSubview(keyboardBack)
//        keyboardBack.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor).isActive = true
//        keyboardBack.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
//        keyboardBack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor).isActive = true
//        keyboardBack.topAnchor.constraint(equalTo: toolbar.bottomAnchor).isActive = true
        
        accessoryView = setupAccessoryView()
        
        colorSampler = WebviewColorSampler()
        colorSampler.delegate = self
        
        gestureController = BrowserGestureController(for: self)
        

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        longPress.minimumPressDuration = 0.4
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        locationBar.addGestureRecognizer(longPress)
        
        let historyPress = UILongPressGestureRecognizer(target: self, action: #selector(showHistory))
        backButton.addGestureRecognizer(historyPress)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func showHistory(_ : Any?) {
        let history = HistoryViewController(collectionViewLayout: UICollectionViewFlowLayout() )
        let hNav = UINavigationController(rootViewController: history)
        present(hNav, animated: true, completion: nil)
    }
    
    var keyboardHeight : CGFloat = 250
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        let newHeight = keyboardRectangle.height
        
        if newHeight != keyboardHeight {
            keyboardHeight = newHeight
            self.searchSizeDidChange()
        }
        // Hack to prevent accessory of showing up at bottom
//        accessoryView.isHidden = keyboardHeight < 50
        accessoryHeightConstraint.constant = keyboardHeight < 50 ? 0 : 48
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        // Hack to prevent accessory of showing up at bottom
        accessoryHeightConstraint.constant = 0
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
        guard webView.scrollView.isScrollable else { return }
        guard !webView.isLoading else { return }
        guard !isDisplayingSearch else { return }
        
        self.toolbarHeightConstraint.constant = 0
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
//                self.webView.scrollView.contentInset.bottom = -Const.shared.toolbarHeight
                self.webView.scrollView.scrollIndicatorInsets.bottom = -Const.shared.toolbarHeight

                self.locationBar.alpha = 0
                self.backButton.alpha = 0
                self.tabButton.alpha = 0
                
                self.view.layoutIfNeeded()
            }, completion: { _ in
//                self.webView.scrollView.contentInset.bottom = 0
//                self.heightConstraint.constant = -Const.shared.statusHeight
            }
        )
        
        webView.scrollView.springBottomInset(to: -Const.shared.toolbarHeight)

    }
    @objc func tapToolbarPlaceholder() {
        self.showToolbar()
    }
    func showToolbar(animated : Bool = true) {
        guard !isDisplayingSearch else { return }

        self.toolbarHeightConstraint.constant = Const.shared.toolbarHeight

        UIView.animate(
            withDuration: animated ? 0.2 : 0,
            delay: 0,
            options: [.curveEaseInOut, .allowAnimatedContent],
            animations: {
                self.webView.scrollView.scrollIndicatorInsets.bottom = 0

                self.locationBar.alpha = 1
                self.backButton.alpha = 1
                self.tabButton.alpha = 1
                
                self.view.layoutIfNeeded()
            }, completion: { _ in
//                self.webView.scrollView.contentInset.bottom = 0
//                self.heightConstraint.constant = -Const.shared.statusHeight - Const.shared.toolbarHeight
            }
        )
        
        webView.scrollView.springBottomInset(to: 0)
    }

    func setUpToolbar() -> ProgressToolbar {
        
        let toolbar = ProgressToolbar(frame: CGRect(
            x: 0,
            y: 0,
            width: cardView.frame.width,
            height: Const.shared.toolbarHeight
        ))
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarHeightConstraint = toolbar.heightAnchor.constraint(equalToConstant: Const.shared.toolbarHeight)
        toolbarHeightConstraint.isActive = true
        
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
        
        toolbar.addSubview(searchView)
        
        searchView.topAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        searchView.centerXAnchor.constraint(equalTo: toolbar.centerXAnchor).isActive = true
        searchView.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
//        searchView.widthAnchor.constraint(lessThanOrEqualToConstant: 320.0).isActive = true
        
//        toolbar.alpha = 0.5
        
        return toolbar
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
    
//    var hasStatusbarOffset : Bool {
//        get {
//            return snap.frame.origin.y == Const.shared.statusHeight
//        }
//        set {
//            statusBar.label.text = webView.url?.displayHost
//            statusBar.label.alpha = newValue ? 0 : 1
//
//            statusBar.frame.size.height = newValue ? Const.shared.statusHeight : THUMB_OFFSET_COLLAPSED
//            snap?.frame.origin.y = newValue ? Const.shared.statusHeight : THUMB_OFFSET_COLLAPSED
//        }
//    }
    var isExpandedSnapshotMode : Bool = false
    var isSnapshotMode : Bool {
        get {
            return !snap.isHidden
        }
        set {
            if newValue {
                snap.isHidden = false
                updateSnapshotPosition()
                webView.isHidden = true
            } else {
                webView.isHidden = false
                snap.isHidden = true
                updateStatusbar()
            }
        }
    }
    
    func updateSnapshotPosition(fromBottom: Bool = false) {
        guard let img : UIImage = snap.image else { return }
        
        let aspect = img.size.height / img.size.width

        snap.frame.size = CGSize(
            width: cardView.bounds.width,
            height: cardView.bounds.width * aspect
        )
        snap.frame.origin.y = isExpandedSnapshotMode ? Const.shared.statusHeight : (fromBottom ? -400 : THUMB_OFFSET_COLLAPSED)

        updateStatusbar()
    }
    
    func updateStatusbar() {
        statusBarFront.frame.size.height = isExpandedSnapshotMode ? Const.shared.statusHeight : THUMB_OFFSET_COLLAPSED
        statusBarBack.frame.size.height = isExpandedSnapshotMode ? Const.shared.statusHeight : THUMB_OFFSET_COLLAPSED
    }
    
    
    func updateSnapshot() {        
        // Image snapshot
        self.browserTab?.updateSnapshot(completionHandler: { img in
            self.snap.image = img
        })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if isBlank {
            
            displaySearch()
        }
        showToolbar()
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

    override func viewWillLayoutSubviews() {
        // because it keeps getting deactivated every time
        // the view is removed from the hierarchy
//        heightConstraint.isActive = true
//        toolbarBottomConstraint.isActive = true
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
    
    @objc func longPressURL(recognizer: UIGestureRecognizer) {
        if recognizer.state == .began {
            
//            displayEditMenu()
            displayOverflow()
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
        bc.browserVC = self
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
        UIPasteboard.general.string = self.editableLocation
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
        searchView.isUserInteractionEnabled = true
        searchView.prepareToShow()
        
        if !searchView.textView.isFirstResponder {
            if !animated { UIView.setAnimationsEnabled(false) }
            searchView.textView.becomeFirstResponder()
            if !animated { UIView.setAnimationsEnabled(true) }
        }
        
        // NOTE: we probably don't have the true keyboard height yet
        
        self.toolbar.progressView.isHidden = true
        
        self.toolbarBottomConstraint.constant = -keyboardHeight

        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0.0,
                options: [.curveLinear, .allowUserInteraction],
                animations: {
                    
                self.toolbarHeightConstraint.constant = self.searchView.bounds.height
                    
                self.locationBar.alpha = 0
                self.toolbar.layoutIfNeeded()
                    
                self.backButton.isHidden = true
                self.forwardButton.isHidden = true
                self.actionButton.isHidden = true
                self.tabButton.alpha = 0
            })
        }
        else {
//            self.cardView.frame.size.height = cardH
//            self.cardView.layer.cornerRadius = 8

            self.toolbarHeightConstraint.constant = self.searchView.frame.height
            self.locationBar.alpha = 0
            self.toolbar.layoutIfNeeded()
            
            
            self.backButton.isHidden = true
            self.forwardButton.isHidden = true
//            self.stopButton.isHidden = true
            self.actionButton.isHidden = true
            self.tabButton.alpha = 0
        }
        
    }
    
    @objc func hideSearch() {
        
        isDisplayingSearch = false
        
        if searchView.textView.isFirstResponder {
            searchView.textView.resignFirstResponder()
        }
        searchView.isUserInteractionEnabled = false
        toolbar.progressView.isHidden = false
        locationBar.backgroundColor = locationBar.tapColor

        self.toolbarBottomConstraint.constant = 0
        
        UIView.animate(
            withDuration: 0.55,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: [.curveLinear, .allowUserInteraction],
            animations: {
            
//                self.cardView.bounds.size = self.cardViewDefaultFrame.size
//                self.cardView.center = self.view.center
//                self.cardView.layer.cornerRadius = Const.shared.cardRadius

                self.toolbarHeightConstraint.constant = Const.shared.toolbarHeight
                self.locationBar.alpha = 1
                self.locationBar.backgroundColor = .clear
            
                self.toolbar.layoutIfNeeded()
                
                self.backButton.isHidden = false
                self.forwardButton.isHidden = false
                self.actionButton.isHidden = false
                self.tabButton.alpha = 1
        })
    }
    
    
    func searchSizeDidChange() {
        if searchView != nil && isDisplayingSearch {
//            let cardH = cardViewDefaultFrame.height - keyboardHeight
//            self.cardView?.frame.size.height = cardH
            self.toolbarBottomConstraint.constant = -keyboardHeight
            self.toolbarHeightConstraint.constant = self.searchView.frame.height
            self.toolbar.layoutIfNeeded()
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
    
    func displayOverflow() {
        
        let ac = UIAlertController(title: webView.title, message: webView.url?.absoluteString, preferredStyle: .actionSheet)
        self.overflowController = ac
        
//        ac.addAction(UIAlertAction(title: "Passwords", style: .default, handler: { action in
//            self.displayPassword()
//        }))
        ac.addAction(UIAlertAction(title: "Refresh", style: .default, handler: { action in
            self.webView.reload()
        }))
//        ac.addAction(UIAlertAction(title: "Full Refresh", style: .default, handler: { action in
//            self.webView.reloadFromOrigin()
//        }))
        
        ac.addAction(UIAlertAction(title: "Copy URL", style: .default, handler: { action in
            self.copyURL()
        }))
        
//        ac.addAction(UIAlertAction(title: "Bookmarks", style: .default, handler: { action in
//            self.displayBookmarks()
//        }))
        ac.addAction(UIAlertAction(title: "Share...", style: .default, handler: { action in
            self.displayShareSheet()
        }))
        
        let pasteAction = UIAlertAction(title: "Paste and go", style: .default, handler: { action in
            self.pasteURLAndGo()
        })
        ac.addAction(pasteAction)

//        pasteAction.isEnabled = false
        // Avoid blocking UI if pasting from another device
//        DispatchQueue.global(qos: .userInitiated).async {
//            if (UIPasteboard.general.hasStrings) {
//                if let str = UIPasteboard.general.string {
//                    var pasted = str
//                    if pasted.count > 32 {
//                        pasted = "\(pasted[...pasted.index(pasted.startIndex, offsetBy: 32)])..."
//                    }
//                    DispatchQueue.main.async {
//                        if self.isProbablyURL(pasted) {
//                            pasteAction.setValue("Go to \"\(pasted)\"", forKey: "title")
//                        }
//                        else {
//                            pasteAction.setValue("Search \"\(pasted)\"", forKey: "title")
//                        }
//                        pasteAction.isEnabled = true
//                    }
//                }
//            }
//        }
        
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
//            let searchURL = "https://duckduckgo.com/?q="
            let searchURL = "https://www.google.com/search?q="
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
        webView.frame.origin.y = Const.shared.statusHeight
        cardView.transform = .identity
        cardView.bounds.size = cardViewDefaultFrame.size
        cardView.center = view.center
        
        if isBlank && withKeyboard {
            // hack for better transition with keyboard
//            cardView.frame.size.height = cardViewDefaultFrame.height - keyboardHeight
        }
        
//        toolbar.alpha = 1
    }
    
    func loadingDidChange() {
        guard isViewLoaded else { return }
        
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
        }
        
        if self.webView.isLoading {
            showToolbar()
        }
        
//        self.stopButton.isHidden = !self.webView.isLoading
        self.actionButton.isHidden = self.webView.isLoading
        
        
        locationBar.isLoading = webView.isLoading
        locationBar.isSecure = webView.hasOnlySecureContent
        locationBar.isSearch = isSearching || isBlank
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = webView.isLoading
        
        if hideUntilNavigationDone && webView.estimatedProgress > 0.9 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.hideUntilNavigationDone = false
            }
        }
        
        browserTab?.updateHistory()
    }
        
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            toolbar.progress = Float(webView.estimatedProgress)
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
                && !hideUntilNavigationDone
                && !(webView.scrollView.contentOffset.y < 0)
                && abs(cardView.frame.origin.y) < 1.0
                && abs(cardView.frame.origin.x) < 1.0
        )
    }
    
    var bottomSamplePosition : CGFloat {
        return cardView.bounds.height - Const.shared.statusHeight - toolbarHeightConstraint.constant
//        return cardView.bounds.height - (-toolbarBottomConstraint.constant) - Const.shared.statusHeight - toolbarHeightConstraint.constant
    }
    
    func topColorChange(_ newColor: UIColor) {
        browserTab?.history.current?.topColor = newColor // this is a hack
        
//        webView.evaluateFixedNav() { (isFixed) in
//            let newAlpha : CGFloat = isFixed ? 1 : 0
//            if self.statusBarFront.alpha != newAlpha {
//                UIView.animate(withDuration: 0.15, animations: {
//                    self.statusBarFront.alpha = newAlpha
//                })
//            }
//        }
        
        if shouldUpdateSample {
            webView.scrollView.backgroundColor = newColor
            
            var didChange : Bool
            if true && statusBarFront.alpha > 0 {
                didChange = statusBarFront.animateGradient(toColor: newColor, direction: .fromBottom)
                statusBarBack.backgroundColor = newColor
            }
            else {
                didChange = statusBarBack.animateGradient(toColor: newColor, direction: .fromBottom)
                statusBarFront.backgroundColor = newColor
            }

            if didChange {
                UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
                    self.setNeedsStatusBarAppearanceUpdate()
                })
            }
        }
    }
    
    func bottomColorChange(_ newColor: UIColor) {
        browserTab?.history.current?.bottomColor = newColor
        
        toolbar.gradientHolder.alpha = webView.scrollView.isScrollable ? 0.8 : 1
        
        if shouldUpdateSample {
//            UIView.animate(withDuration: 0.2, delay: 0.1, options: .curveEaseInOut, animations: {
//                self.keyboardBack.backgroundColor = newColor //newColor.isLight ? newColor.withBrightness(2.5) : newColor.saturated()
//            })
            let _ = toolbar.animateGradient(toColor: newColor, direction: .fromTop)
            
        }

    }
    
    func cancelColorChange() {
        statusBarFront.cancelColorChange()
        toolbar.cancelColorChange()
    }
}
