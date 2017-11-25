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

class BrowserViewController: UIViewController, UIGestureRecognizerDelegate, UIActivityItemSource {
    
    var home: HomeViewController!
    var webView: WKWebView!
    var snap: UIView!
    var browserTab: BrowserTab?
    
    var heightConstraint : NSLayoutConstraint!
    var topConstraint : NSLayoutConstraint!
    var accessoryHeightConstraint : NSLayoutConstraint!
    var toolbarHeightConstraint : NSLayoutConstraint!
    var toolbarBottomConstraint : NSLayoutConstraint!

    var isDisplayingSearch : Bool = false
    var searchView: SearchView!
    var colorSampler: ColorSampler!
    
    var statusBar: ColorStatusBarView!
    var toolbar: ProgressToolbar!
    var accessoryView: GradientColorChangeView!
    
    var errorView: UIView!
    var cardView: UIView!

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
        return statusBar.lastColor.isLight ? .lightContent : .default
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    var isShowingToolbar : Bool {
        return toolbarHeightConstraint.constant > 0
    }
    
    var shouldUpdateColors : Bool {
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
            return webView.alpha < 1
        }
        set {
            webView.alpha = newValue ? 0 : 1
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
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.title))
        oldWebView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.url))

        browserTab = newTab
        webView = newTab.webView
        
        if snap != nil && snap.isDescendant(of: cardView) {
            snap?.removeFromSuperview()
        }
        snap = nil
        if let img = newTab.history.current?.snapshot {
            snap = UIImageView(image: img)
            updateSnapshotPosition()
        }
        
        if let newTop = newTab.topColorSample {
            statusBar.backgroundColor = newTop
            // TODO: just need to reset tint color, dont need animate gradient
            let _ = statusBar.animateGradient(toColor: newTop, duration: 0.1, direction: .fromBottom)
        }
        else {
            statusBar.backgroundColor = .white
        }
        if let newBottom = newTab.bottomColorSample {
            toolbar.backgroundColor = newBottom
            cardView.backgroundColor = newBottom
            webView.backgroundColor = newBottom
            // TODO: just need to reset tint color, dont need animate gradient
            let _ = toolbar.animateGradient(toColor: newBottom, duration: 0.1, direction: .fromTop)
        }
        else {
            toolbar.backgroundColor = .white
            cardView.backgroundColor = .white
            webView.backgroundColor = .white
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.delegate = gestureController
        
        colorSampler.webView = webView
        
        cardView.addSubview(webView)
        cardView.bringSubview(toFront: toolbar)
        cardView.bringSubview(toFront: statusBar)
        
        topConstraint = webView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: Const.shared.statusHeight)
        topConstraint.isActive = true
        
        webView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        webView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        
        heightConstraint = webView.heightAnchor.constraint(equalTo: view.heightAnchor, constant: (-Const.shared.statusHeight - Const.shared.toolbarHeight))
        heightConstraint.isActive = true
        
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
        cardView.layer.cornerRadius = Const.shared.cardRadius
        cardView.layer.masksToBounds = true
        
        statusBar = ColorStatusBarView()
        cardView.addSubview(statusBar)
        
        searchView = SearchView(for: self)
        
        toolbar = setUpToolbar()
        
        view.addSubview(cardView)
        
        cardView.addSubview(toolbar)
        cardView.bringSubview(toFront: toolbar)
        
        toolbar.centerXAnchor.constraint(equalTo: cardView.centerXAnchor).isActive = true
        toolbar.widthAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true
        toolbarBottomConstraint = toolbar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        toolbarBottomConstraint.isActive = true
        
//        view.addSubview(toolbar)
//        view.sendSubview(toBack: toolbar)
        
        accessoryView = setupAccessoryView()
        
        colorSampler = ColorSampler(inViewController: self)
        
        gestureController = BrowserGestureController(for: self)
        

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressURL(recognizer:)))
        longPress.minimumPressDuration = 0.4
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        locationBar.addGestureRecognizer(longPress)
        
        let historyPress = UILongPressGestureRecognizer(target: self, action: #selector(showHistory))
        backButton.addGestureRecognizer(historyPress)
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func showHistory(_ : Any?) {
        let history = HistoryViewController(collectionViewLayout: UICollectionViewFlowLayout() )
        let hNav = UINavigationController(rootViewController: history)
        present(hNav, animated: true, completion: nil)
    }
    
    var keyboardHeight : CGFloat = 250
    @objc func keyboardWillShow(notification: NSNotification) {
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
    func makeSuperTitle() {
        topWindow = UIWindow(frame: self.statusBar.frame)
        topWindow.windowLevel = UIWindowLevelStatusBar + 1
        
        topLabel = UILabel()
        topLabel.text = "apple.com"
//        topLabel.font = UIFont.systemFont(ofSize: 12.0)
        topLabel.font = UIFont.systemFont(ofSize: 12.0, weight: UIFont.Weight.semibold)
        topLabel.backgroundColor = .red
        topLabel.frame = CGRect(x: 0, y: 0, width: 290, height: Const.shared.statusHeight)
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
            height: UIScreen.main.bounds.height// - Const.shared.toolbarHeight
        )
    }
    
    func hideToolbar(animated : Bool = true) {
        guard webView.scrollView.isScrollable else { return }
        guard !webView.isLoading else { return }
        guard !isDisplayingSearch else { return }
        
//        self.toolbarHeightConstraint.constant = 0

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                self.view.layoutIfNeeded()
                self.webView.scrollView.contentInset.bottom = -Const.shared.toolbarHeight
            }, completion: { _ in
//                self.webView.scrollView.contentInset.bottom = 0
//                self.heightConstraint.constant = -Const.shared.statusHeight
            }
        )
    }
    func showToolbar(animated : Bool = true) {
        guard !isDisplayingSearch else { return }

//        self.toolbarHeightConstraint.constant = Const.shared.toolbarHeight

        UIView.animate(
            withDuration: animated ? 0.2 : 0,
            delay: 0,
            options: [.curveEaseInOut, .allowAnimatedContent],
            animations: {
                self.view.layoutIfNeeded()
                self.webView.scrollView.contentInset.bottom = 0
            }, completion: { _ in
//                self.webView.scrollView.contentInset.bottom = 0
//                self.heightConstraint.constant = -Const.shared.statusHeight - Const.shared.toolbarHeight
            }
        )
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
        searchView.widthAnchor.constraint(equalTo: toolbar.widthAnchor).isActive = true
        
//        toolbar.alpha = 0.5
        
        return toolbar
    }
    
    func setupAccessoryView() -> GradientColorChangeView {
        let acc = GradientColorChangeView(frame: CGRect(x: 0, y: 0, width: 375, height: 48))
        acc.tintColor = UIColor.darkText
        acc.backgroundColor = UIColor(r: 0.83, g: 0.84, b: 0.85).withAlphaComponent(0.95)
//        acc.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        let blur = UIVisualEffectView(frame: acc.frame, isTransparent: true)
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
            return snap?.isHidden ?? false
        }
        set {
            if newValue && snap != nil {
                snap.isHidden = false
                updateSnapshotPosition()
                webView.isHidden = true
            } else {
                webView.isHidden = false
                snap?.removeFromSuperview()
            }
        }
    }
    
    func updateSnapshotPosition(fromBottom: Bool = false) {
        guard snap != nil else { return }
        if snap.superview !== cardView {
            cardView.addSubview(snap)
            cardView.bringSubview(toFront: statusBar)
        }
        
        let aspect = snap.frame.height / snap.frame.width

        snap.frame.size = CGSize(
            width: cardView.frame.width,
            height: cardView.frame.width * aspect
        )
        
        statusBar.label.alpha = isExpandedSnapshotMode ? 0 : 1
        statusBar.frame.size.height = isExpandedSnapshotMode ? Const.shared.statusHeight : THUMB_OFFSET_COLLAPSED
        snap.frame.origin.y = isExpandedSnapshotMode ? Const.shared.statusHeight : (fromBottom ? -400 : THUMB_OFFSET_COLLAPSED)
    }
    
    
    func updateSnapshot() {
        snap?.removeFromSuperview()
        webView.scrollView.showsVerticalScrollIndicator = false
        snap = webView.snapshotView(afterScreenUpdates: true)!
        snap.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        webView.scrollView.showsVerticalScrollIndicator = true
        
        // Image snapshot
        webView.takeSnapshot(with: nil, completionHandler: { (image, error) in
            if let img : UIImage = image {
                self.browserTab?.history.current?.snapshot = img
            }
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        statusBar.label.text = webView.url?.displayHost
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
        heightConstraint.isActive = true
        toolbarBottomConstraint.isActive = true
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
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
        
        let cardH = cardViewDefaultFrame.height - keyboardHeight
        
        self.toolbar.progressView.isHidden = true

        if animated {
            UIView.animate(
                withDuration: 0.5,
                delay: 0.0,
                usingSpringWithDamping: 1,
                initialSpringVelocity: 0.0,
                options: [.curveLinear, .allowUserInteraction],
                animations: {
                    
                self.cardView.frame.size.height = cardH
                self.toolbarHeightConstraint.constant = self.searchView.frame.height

                self.locationBar.alpha = 0
                self.toolbar.layoutIfNeeded()
                    
                self.backButton.isHidden = true
                self.forwardButton.isHidden = true
                self.actionButton.isHidden = true
                self.tabButton.alpha = 0
            })
        }
        else {
            self.cardView.frame.size.height = cardH
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

        UIView.animate(
            withDuration: 0.55,
            delay: 0.0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.0,
            options: [.curveLinear, .allowUserInteraction],
            animations: {
            
                self.cardView.frame = self.cardViewDefaultFrame
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
            let cardH = cardViewDefaultFrame.height - keyboardHeight
            self.cardView?.frame.size.height = cardH
            self.toolbarHeightConstraint.constant = self.searchView.frame.height
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

        pasteAction.isEnabled = false
        // Avoid blocking UI if pasting from another device
        DispatchQueue.global(qos: .userInitiated).async {
            if (UIPasteboard.general.hasStrings) {
                if let str = UIPasteboard.general.string {
                    var pasted = str
                    if pasted.count > 32 {
                        pasted = "\(pasted[...pasted.index(pasted.startIndex, offsetBy: 32)])..."
                    }
                    DispatchQueue.main.async {
                        if self.isProbablyURL(pasted) {
                            pasteAction.setValue("Go to \"\(pasted)\"", forKey: "title")
                        }
                        else {
                            pasteAction.setValue("Search \"\(pasted)\"", forKey: "title")
                        }
                        pasteAction.isEnabled = true
                    }
                }
            }
        }
        
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
        statusBar.frame.origin.y = 0
        webView.frame.origin.y = Const.shared.statusHeight
        view.transform = .identity
        cardView.frame = cardViewDefaultFrame
        
        if isBlank && withKeyboard {
            // hack for better transition with keyboard
            cardView.frame.size.height = cardViewDefaultFrame.height - keyboardHeight
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
        
        if hideUntilNavigationDone && webView.estimatedProgress == 1 {
            UIView.animate(withDuration: 0.1, delay: 0.1, animations: {
                self.hideUntilNavigationDone = false
            }, completion: nil)
        }
        
        if browserTab?.history.current == nil
            && webView.backForwardList.currentItem != nil {
            browserTab?.history.current = HistoryItem(parent: nil, from: webView.backForwardList.currentItem!)
        }
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
