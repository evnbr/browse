//
//  SearchViewController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

let typeaheadReuseID = "TypeaheadRow"
let MAX_ROWS : Int = 4
let SEARCHVIEW_MAX_H : CGFloat = 240.0
let TEXTVIEW_PADDING = UIEdgeInsetsMake(16, 20, 32, 20 )

class SearchViewController: UIViewController {

    var contentView: UIView!
    var backgroundView: PlainBlurView!
    var scrim: UIView!
    var textView: UITextView!
    var cancel: ToolbarTextButton!
    var suggestionTable: UITableView!
    var keyboardPlaceholder: UIImageView!
    var dragHandle: UIView!
    var pageActionView: PageActionView!
    
    var keyboardSnapshot: UIImage?
    var lastKeyboardSize: CGSize?
    var lastKeyboardColor: UIColor?

    var isTransitioning = false

    var displaySearchTransition = SearchTransitionController()
    
    var kbHeightConstraint : NSLayoutConstraint!
    var suggestionHeightConstraint : NSLayoutConstraint!
    var contextAreaHeightConstraint : NSLayoutConstraint!
    var textHeightConstraint : NSLayoutConstraint!
    var toolbarBottomMargin : NSLayoutConstraint!
    var actionsHeight : NSLayoutConstraint!

    var textHeight : CGFloat = 12
    var suggestionSpacer : CGFloat = 24
    var contextAreaHeight: CGFloat = 24
    var keyboardHeight : CGFloat = 250
    var showingCancel = true
    
    var browserOffset: CGFloat {
        return keyboardHeight + textHeight + suggestionSpacer - 100
    }
    
    var suggestions : [TypeaheadSuggestion] = []
    
    var isFakeTab = false
    var defaultBackground: UIColor = .white //.black
    
    var browser : BrowserViewController? {
        return self.presentingViewController as? BrowserViewController
    }
    var switcher : TabSwitcherViewController? {
        if let nav = self.presentingViewController as? UINavigationController,
            let switcher = nav.topViewController as? TabSwitcherViewController {
            return switcher
        }
        else { return nil }
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        scrim = UIView(frame: view.bounds)
//        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        view.addSubview(scrim, constraints: [
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Const.toolbarHeight),
            scrim.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrim.rightAnchor.constraint(equalTo: view.rightAnchor),
        ])

        if (showingCancel) {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
            scrim.addGestureRecognizer(tap)
        }
        
        contentView = UIView(frame: view.bounds)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        contentView.clipsToBounds = true
//        contentView.radius = Const.shared.cardRadius
        view.addSubview(contentView)
        
        backgroundView = PlainBlurView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.overlayAlpha = 1//isFakeTab ? 1 : 0.8
        contentView.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(handleDimissPan(_:)))
        dismissPanner.cancelsTouchesInView = true
        dismissPanner.delaysTouchesBegan = false
        view.addGestureRecognizer(dismissPanner)
        
        suggestionTable = UITableView(frame:self.view.frame)
        suggestionTable.rowHeight = 48.0
        suggestionTable.register(TypeaheadCell.self, forCellReuseIdentifier: typeaheadReuseID)
        suggestionTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionTable.dataSource = self
        suggestionTable.delegate = self
        suggestionTable.isScrollEnabled = false
        suggestionTable.separatorStyle = .none
        suggestionTable.backgroundColor = .clear
        suggestionTable.backgroundView?.backgroundColor = .clear

        textView = UITextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.font = Const.shared.textFieldFont
        textView.text = ""
        textView.placeholder = "Where to?"
        textView.delegate = self
        textView.isScrollEnabled = true
        textView.backgroundColor = .clear
        textView.textColor = .darkText
        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = .light
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = .webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        let maskView = UIView(frame: textView.bounds)
        maskView.backgroundColor = .red
        maskView.frame = textView.bounds
        maskView.frame.size.height = 500 // TODO Large number because mask is scrollable :(
        textView.mask = maskView
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: dismissSelf)
        cancel.size = .medium
        cancel.sizeToFit()
        cancel.translatesAutoresizingMaskIntoConstraints = false

        keyboardPlaceholder = UIImageView()
        keyboardPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        keyboardPlaceholder.contentMode = .top
        
        pageActionView = PageActionView()
        pageActionView.delegate = self
        
        contextAreaHeightConstraint = textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: suggestionSpacer)
        suggestionHeightConstraint = suggestionTable.heightAnchor.constraint(equalToConstant: suggestionTable.rowHeight * 4)
        actionsHeight = pageActionView.heightAnchor.constraint(equalToConstant: 0)
        contentView.addSubview(suggestionTable, constraints: [
            suggestionHeightConstraint,
            contextAreaHeightConstraint,
            suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            suggestionTable.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -8),
        ])
        if isFakeTab {
            contextAreaHeight = UIScreen.main.bounds.size.height - keyboardHeight
        }
        
        contentView.addSubview(pageActionView, constraints: [
            actionsHeight,
            pageActionView.bottomAnchor.constraint(equalTo: textView.topAnchor),
//            pageActionView.topAnchor.constraint(equalTo: contentView.topAnchor ),
            pageActionView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            pageActionView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
        ])

        textView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor).isActive = true

        if (showingCancel) {
//            contentView.addSubview(cancel, constraints: [
//                cancel.bottomAnchor.constraint(equalTo: textView.bottomAnchor, constant: -12),
//                cancel.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor),
//                cancel.widthAnchor.constraint(equalToConstant: cancel.bounds.width),
//                cancel.heightAnchor.constraint(equalToConstant: cancel.bounds.height),
//            ])
        }
        
        kbHeightConstraint = keyboardPlaceholder.heightAnchor.constraint(equalToConstant: 0)
        contentView.addSubview(keyboardPlaceholder, constraints: [
            kbHeightConstraint,
            keyboardPlaceholder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            keyboardPlaceholder.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            keyboardPlaceholder.rightAnchor.constraint(equalTo: contentView.rightAnchor),
        ])

        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        toolbarBottomMargin = keyboardPlaceholder.topAnchor.constraint(equalTo: textView.bottomAnchor)

        NSLayoutConstraint.activate([
            toolbarBottomMargin,
            textHeightConstraint,
            textView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
        ])
        
        dragHandle = UIView(frame: .zero)
        dragHandle.radius = 2
        contentView.addSubview(dragHandle, constraints: [
            dragHandle.heightAnchor.constraint(equalToConstant: 4),
            dragHandle.widthAnchor.constraint(equalToConstant: 48),
            dragHandle.bottomAnchor.constraint(equalTo: keyboardPlaceholder.topAnchor, constant: -8),
            dragHandle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
        
        NotificationCenter.default.addObserver(self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil)

        setBackground(defaultBackground)
        updateTextViewSize()
        view.layoutIfNeeded()
    }
    
    func setBackground(_ newColor: UIColor) {
        guard isViewLoaded else {
            defaultBackground = newColor
            return
        }
        
        let darkContent = !newColor.isLight
        backgroundView.overlayColor = newColor
        view.tintColor = darkContent ? .darkText : .white
        contentView.tintColor = view.tintColor
        textView.textColor = view.tintColor
        dragHandle.backgroundColor = view.tintColor.withAlphaComponent(0.2)

//        textView.backgroundColor = darkContent ? UIColor.black.withAlphaComponent(0.1) : UIColor.white.withAlphaComponent(0.3)
        textView.placeholderColor = darkContent ? UIColor.black.withAlphaComponent(0.4) : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = darkContent ? .light : .dark
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { (ctx) in
            //
        }) { (ctx) in
            self.updateKeyboardSnapshot()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        // TODO: Why?
        view.frame = UIScreen.main.bounds
        
        if let browser = self.browser {
            textView.text = browser.editableLocation
            pageActionView.title = browser.webView.title
            pageActionView.isBookmarked = false
            pageActionView.isBookmarkEnabled = BookmarkProvider.shared.isLoggedIn
            
            BookmarkProvider.shared.isBookmarked(browser.webView.url) { isBookmarked in
                self.pageActionView.isBookmarked = isBookmarked
            }
            updateTextViewSize()
            updateSuggestion(for: textView.text)
        }
        
//        keybsoardPlaceholder.image = nil
    }
    
    func focusTextView() {
        textView.becomeFirstResponder()
        textView.selectAll(nil) // if not nil, will show actions
        keyboardPlaceholder.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        updateKeyboardSnapshot()
    }
    
    @objc
    func dismissSelf() {
        showFakeKeyboard()
        self.dismiss(animated: true)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    @objc func updateKeyboardHeight(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        
        if keyboardRectangle.height < 10 {
            // thats not what we meant by keyboard height
            return
        }
        
        keyboardHeight = keyboardRectangle.height
        
        if textView.isFirstResponder && !kbHeightConstraint.isPopAnimating && !isTransitioning {
            kbHeightConstraint.constant = keyboardHeight
        }
    }
}
    
extension SearchViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewSize()
        updateSuggestion(for: textView.text)
        updateBrowserOffset()
    }
    
    func updateSuggestion(for text: String) {
        if shouldShowActions || text == "" {
            suggestions = []
            self.renderSuggestions()
            return
        }
        
        let suggestionsForText = textView.text
        TypeaheadProvider.shared.suggestions(for: textView.text, maxCount: 4) { arr in
            // If text has changed since return, don't bother
            if self.textView.text != suggestionsForText { return }
            
            self.suggestions = arr.reversed()
            self.renderSuggestions()
        }
    }
    
    var shouldShowActions : Bool {
        return browser?.editableLocation == textView.text || (browser != nil && textView.text == "")
    }
    
    func renderSuggestions() {
        if isFakeTab {
            suggestionTable.reloadData()
            suggestionTable.layoutIfNeeded()
            return
        }
        if shouldShowActions  {
            contextAreaHeight = 0 // 100
            actionsHeight.constant = contextAreaHeight
            contextAreaHeightConstraint.constant = contextAreaHeight
        }
        else {
            actionsHeight.constant = 0
            var suggestionH : CGFloat = 0
            for index in 0..<suggestions.count {
                suggestionH += tableView(
                    suggestionTable,
                    heightForRowAt: IndexPath(row: index, section: 0))
            }
            contextAreaHeight = suggestionH + suggestionSpacer
            suggestionHeightConstraint.constant = suggestionH
        }
        UIView.animate(withDuration: 0.2) {
            self.scrim.backgroundColor = self.shouldShowActions ? .clear : UIColor.black.withAlphaComponent(0.2)
        }
        let anim = contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
        anim?.springBounciness = 2
        anim?.springSpeed = 12
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }
    
    func updateTextViewSize() {
        let fixedWidth = textView.frame.size.width
//        textView.textContainerInset = UIEdgeInsetsMake(10, 20, 22, showingCancel ? cancel.bounds.width : 0 )
        textView.textContainerInset = TEXTVIEW_PADDING
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        textHeight = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))
        textHeightConstraint.constant = textHeight
        
        textView.mask?.frame.size.width = textView.bounds.width
    }
    
    func updateBrowserOffset() {
        if let b = browser {
            var shiftedCenter = b.view.center
            shiftedCenter.y -= browserOffset
            b.cardView.center = shiftedCenter
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", let entry = textView.text {
            if entry.isProbablyURL {
                var url : URL?
                if (entry.hasPrefix("http://") || entry.hasPrefix("https://")) {
                    url = URL(string: entry)
                }
                else {
                    url = URL(string: "http://" + entry)
                }
                if let url = url {
                    navigateTo(url)
                    return false
                }
            }
            let url = TypeaheadProvider.shared.serpURLfor(entry)!
            navigateTo(url)
            return false
        }
        return true
    }
    
    func navigateTo(_ url: URL) {
        if let browser = self.browser {
            browser.navigateTo(url)
            setBackground(.white) // since navigate insta-hides
            dismissSelf()
            return
        }
        if let switcher = self.switcher {
            self.dismiss(animated: false, completion: {
                switcher.isDisplayingFakeTab = false
                switcher.addTab(startingFrom: url, animated: false)
            })
            return
        }
    }
}

extension SearchViewController : UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = suggestions[indexPath.item]
        if let url = row.url { navigateTo(url) }
    }
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let row = suggestions[indexPath.item]
        return row.url != nil
    }
}

extension SearchViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(MAX_ROWS, suggestions.count)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath) as! TypeaheadCell
        // Configure the cells
        
        let suggestion = suggestions[indexPath.item]
        let currentText = textView.text ?? ""

        cell.configure(title: suggestion.title, detail: suggestion.detail, highlight: currentText)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = suggestions[indexPath.item]
        var h : CGFloat = 48.0
        if item.title != nil { h += 16 }
        return h
    }
}

// MARK - Gesture

let SPACE_FOR_INDICATOR : CGFloat = 26

extension SearchViewController : UIGestureRecognizerDelegate {
    private func verticalPan(gesture: UIPanGestureRecognizer, isEntrance: Bool = false) {
        guard showingCancel else { return }

        var dist = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)
        
        if isEntrance {
            dist.y += keyboardHeight
        }

        if gesture.state == .began {
            showFakeKeyboard()
            isTransitioning = true
        }
        else if gesture.state == .changed {
            if dist.y < 0 { 
                kbHeightConstraint.constant = keyboardHeight
                let elastic = 0.4 * elasticLimit(-dist.y)
                textHeightConstraint.constant = textHeight + elastic
                
                if let b = browser {
                    b.cardView.center.y = b.view.center.y - elastic - browserOffset
                }
            }
            else {
                if dist.y < keyboardHeight - SPACE_FOR_INDICATOR {
                    kbHeightConstraint.constant = max(keyboardHeight - dist.y, SPACE_FOR_INDICATOR)
                    let progress = dist.y.progress(0, keyboardHeight).clip()
//                    let margin = progress.blend(0, SPACE_FOR_INDICATOR)
//                    toolbarBottomMargin.constant = margin
                    contextAreaHeightConstraint.constant = contextAreaHeight
                    if let b = browser {
                        b.cardView.center.y = b.view.center.y + dist.y - browserOffset
                    }
                }
                else {
                    let amtBeyondKeyboard = max(0, dist.y - keyboardHeight + SPACE_FOR_INDICATOR)
//                    kbHeightConstraint.constant = SPACE_FOR_INDICATOR - amtBeyondKeyboard
//                    toolbarBottomMargin.constant = min(SPACE_FOR_INDICATOR, amtBeyondKeyboard)

//                    contextAreaHeightConstraint.constant = contextAreaHeight - elasticLimit(amtBeyondKeyboard)
                }
//                suggestionTable.alpha = dist.y.progress(keyboardHeight - 40, keyboardHeight + 100).clip().reverse()
//                pageActionView.alpha = dist.y.progress(keyboardHeight - 40, keyboardHeight + 60).clip().reverse()
            }
        }
        else if gesture.state == .ended || gesture.state == .cancelled {
            isTransitioning = false
            if (vel.y > 100 || kbHeightConstraint.constant < 50) && showingCancel {
                dismissSelf()
            }
            else {
                func finish() {
                    self.showRealKeyboard()
                    self.updateTextViewSize() // maybe reenable scrolls
                }
                let fromBelow = kbHeightConstraint.constant < keyboardHeight
                kbHeightConstraint.springConstant(to: keyboardHeight) {_,_ in
                    if fromBelow { finish() }
                }
                
                var shiftedCenter = browser!.view.center
                shiftedCenter.y -= browserOffset
                browser?.cardView.springCenter(to: shiftedCenter)
                contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
                toolbarBottomMargin.springConstant(to: 0)
                suggestionTable.alpha = 1
                pageActionView.alpha = 1
                let ta = textHeightConstraint.springConstant(to: textHeight) {
                    _,_ in
                    if !fromBelow { finish() }
                }
                ta?.clampMode = POPAnimationClampFlags.both.rawValue // prevent flickering when textfield too small
            }
        }
    }
    
    @objc func handleDimissPan(_ gesture: UIPanGestureRecognizer) {
        verticalPan(gesture: gesture, isEntrance: false)
    }
    
    func handleEntrancePan(_ gesture: UIPanGestureRecognizer) {
        isTransitioning = true
        verticalPan(gesture: gesture, isEntrance: true)
    }
    
    func showFakeKeyboard() {
        updateKeyboardSnapshot()
        keyboardPlaceholder.isHidden = false
        keyboardPlaceholder.image = keyboardSnapshot
        UIView.setAnimationsEnabled(false)
        textView.resignFirstResponder()
        UIView.setAnimationsEnabled(true)
        
        // shrink height to snapshot (in case was showing emoji etc)
        if let snapH = keyboardPlaceholder.image?.size.height, snapH < kbHeightConstraint.constant {
            keyboardHeight = snapH
            kbHeightConstraint.constant = snapH
        }
    }
    
    func showRealKeyboard() {
        if isTransitioning { return }
        keyboardPlaceholder.isHidden = true
        UIView.setAnimationsEnabled(false)
        textView.becomeFirstResponder()
        UIView.setAnimationsEnabled(true)
    }
    
    @objc func updateKeyboardSnapshot() {
        if !textView.isFirstResponder
            || kbHeightConstraint.constant != keyboardHeight { return }
        
        let screen = UIScreen.main.bounds.size
        let kbSize = CGSize(width: screen.width, height: keyboardHeight)
        let bg = backgroundView.overlayColor
        if bg != lastKeyboardColor || kbSize != lastKeyboardSize {
            keyboardSnapshot = takeKeyboardSnapshot(size: kbSize)
            lastKeyboardSize = kbSize
            lastKeyboardColor = bg
        }
    }
    
    func takeKeyboardSnapshot(size: CGSize) -> UIImage? {
        let screen = UIScreen.main.bounds.size
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()
        ctx?.translateBy(x: 0, y: -(screen.height - keyboardHeight))
        
        for window in UIApplication.shared.windows {
            if (window.screen == UIScreen.main) {
                window.drawHierarchy(in: window.frame, afterScreenUpdates: false) // if true, weird flicker
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        return img
    }
}

// MARK - Actions
extension SearchViewController : PageActionHandler {
    func refresh() {
        browser?.webView.reload()
    }
    
    func bookmark() {
        //
        if !BookmarkProvider.shared.isLoggedIn {
            func success() {
                DispatchQueue.main.async {
                    self.pageActionView.isBookmarkEnabled = true
                }
            }
            func tryAgain() {
                DispatchQueue.main.async {
                    let prompt = PinboardLoginController(success: success, failure: tryAgain)
                    prompt.message = "⚠️ That didn't seem to work"
                    prompt.view.setNeedsDisplay()
                    self.present(prompt, animated: true)
                }
            }
            let prompt = PinboardLoginController(success: success, failure: tryAgain)
            DispatchQueue.main.async {
                self.present(prompt, animated: true)
            }
        }
        else if !pageActionView.isBookmarked {
            guard let url = browser?.webView.url, let title = browser?.webView.title else { return }
            BookmarkProvider.shared.addBookmark(url, title: title) { isBookmarked in
                if isBookmarked { self.pageActionView.isBookmarked = true }
            }
        }
        else if pageActionView.isBookmarked {
//            BookmarkProvider.shared.add(browser?.webView.url)
            let options = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            options.addAction(UIAlertAction(title: "Edit", style: .default, handler: nil))
            options.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in
                guard let url = self.browser?.webView.url else { return }
                BookmarkProvider.shared.removeBookmark(url) { isRemoved in
                    if isRemoved { self.pageActionView.isBookmarked = false }
                }
                self.showRealKeyboard()
            }))
            options.addAction(UIAlertAction(title: "Log Out", style: .default, handler: { _ in
                BookmarkProvider.shared.logOut()
                self.pageActionView.isBookmarkEnabled = false
                self.pageActionView.isBookmarked = false
                self.showRealKeyboard()
            }))
            options.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
                self.showRealKeyboard()
            }))
            DispatchQueue.main.async {
                self.showFakeKeyboard()
                self.present(options, animated: true)
            }
        }
    }
    
    func share() {
        browser?.makeShareSheet { avc in
            self.showFakeKeyboard()
            avc.completionWithItemsHandler = { _, _, _, _ in
                self.showRealKeyboard()
            }
            self.present(avc, animated: true, completion: nil)
        }
    }
    
    func copy() {
        let b = browser
        b?.copyURL()
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        self.showFakeKeyboard()
        present(alert, animated: true, completion: {
            alert.dismiss(animated: true, completion: {
                self.showRealKeyboard()
            })
        })
    }
}



// MARK - Animation

extension SearchViewController : UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .present
        return displaySearchTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        displaySearchTransition.direction = .dismiss
        return displaySearchTransition
    }
}
