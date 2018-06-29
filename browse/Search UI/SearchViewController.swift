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
let MAX_ROWS: Int = 4
let SEARCHVIEW_MAX_H: CGFloat = 240.0
let TEXTVIEW_PADDING = UIEdgeInsets(top: 20, left: 20, bottom: 40, right: 20)
let pageActionHeight: CGFloat = 100

// https://medium.com/@nguyenminhphuc/how-to-pass-ui-events-through-views-in-ios-c1be9ab1626b
class PassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}

class SearchViewController: UIViewController {

    var contentView: UIView!
    var backgroundView: PlainBlurView!
    var shadowView: UIView!
    var scrim: UIView!
    var textView: UITextView!
    var suggestionTable: UITableView!
    var keyboardPlaceholder: UIImageView!
    var dragHandle: UIView!
    var pageActionView: PageActionView!
    var keyboard = KeyboardManager()

    var isTransitioning = false
    var isSwiping = false

    var transition = SearchTransitionController()

    var kbHeightConstraint: NSLayoutConstraint!
    var suggestionHeightConstraint: NSLayoutConstraint!
    var contextAreaHeightConstraint: NSLayoutConstraint!
    var textHeightConstraint: NSLayoutConstraint!
    var toolbarBottomMargin: NSLayoutConstraint!
    var actionsHeight: NSLayoutConstraint!

    private var leftIconConstraint: NSLayoutConstraint!
    private var rightIconConstraint: NSLayoutConstraint!

    var textHeight: CGFloat = 12
    var suggestionSpacer: CGFloat = 24
    var contextAreaHeight: CGFloat = 120

    var iconEntranceProgress: CGFloat {
        get {
            return leftIconConstraint.constant.progress(8, -36)
        }
        set {
            let margin = newValue.lerp(8, -36)
            leftIconConstraint.constant = margin
            rightIconConstraint.constant = -margin
        }
    }

    var suggestions: [TypeaheadSuggestion] = []

    var isFakeTab = false
    var defaultBackground: UIColor = .white //.black

    var browserVC: BrowserViewController?

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = PassthroughView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // make sure fake kb is clipped when not aligned with screen
        view.radius = Const.cardRadius
        view.clipsToBounds = true

        scrim = PassthroughView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        view.addSubview(scrim, constraints: [
            scrim.topAnchor.constraint(equalTo: view.topAnchor),
            scrim.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Const.toolbarHeight),
            scrim.leftAnchor.constraint(equalTo: view.leftAnchor),
            scrim.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        scrim.addGestureRecognizer(tap)

        contentView = UIView(frame: view.bounds)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        contentView.clipsToBounds = true
        contentView.radius = 8
        view.addSubview(contentView)
        
        shadowView = UIView(frame: view.bounds)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        let path = UIBezierPath(roundedRect: view.bounds, cornerRadius: 8)
        shadowView.layer.shadowPath = path.cgPath
        shadowView.layer.shadowOpacity = 0.1
        shadowView.layer.shadowRadius = 0
        view.insertSubview(shadowView, belowSubview: contentView)
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowView.heightAnchor.constraint(equalToConstant: 100),
        ])
        
        backgroundView = PlainBlurView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.overlayAlpha = 0.9//isFakeTab ? 1 : 0.8
        contentView.addSubview(backgroundView)

        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        suggestionTable = createSuggestions()
        textView = createTextView()
        contentView.addSubview(textView)

        let maskView = UIView(frame: textView.bounds)
        maskView.backgroundColor = .red
        maskView.frame = textView.bounds
        maskView.radius = 24
        maskView.frame.size.height = 500 // TODO Large number because mask is scrollable :(
        textView.mask = maskView

        setupFakeKeyboard()
        setupActions()
        setupTextView()
        setupDrag()
        setupPlaceholderIcons()

        setBackground(defaultBackground)
        updateTextViewSize()
        view.layoutIfNeeded()
    }

    func setupActions() {
        pageActionView = PageActionView()
        pageActionView.delegate = self
        
        contextAreaHeightConstraint = textView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: suggestionSpacer)
        suggestionHeightConstraint = suggestionTable.heightAnchor.constraint(
            equalToConstant: suggestionTable.rowHeight * 4)
        actionsHeight = pageActionView.heightAnchor.constraint(equalToConstant: 0)
        contentView.addSubview(suggestionTable, constraints: [
            suggestionHeightConstraint,
            contextAreaHeightConstraint,
            suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            suggestionTable.bottomAnchor.constraint(equalTo: textView.topAnchor, constant: -8)
        ])

        contentView.addSubview(pageActionView, constraints: [
            actionsHeight,
            pageActionView.bottomAnchor.constraint(equalTo: textView.topAnchor),
            pageActionView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor),
            pageActionView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor)
        ])
    }

    func setupFakeKeyboard() {
        keyboardPlaceholder = UIImageView()
        keyboardPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        keyboardPlaceholder.contentMode = .top

        kbHeightConstraint = keyboardPlaceholder.heightAnchor.constraint(equalToConstant: 0)
        contentView.addSubview(keyboardPlaceholder, constraints: [
            kbHeightConstraint,
            keyboardPlaceholder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            keyboardPlaceholder.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            keyboardPlaceholder.rightAnchor.constraint(equalTo: contentView.rightAnchor)
            ])
        toolbarBottomMargin = keyboardPlaceholder.topAnchor.constraint(equalTo: textView.bottomAnchor)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillShow,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateKeyboardHeight),
            name: NSNotification.Name.UIKeyboardWillChangeFrame,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(maybeAutoHide),
            name: NSNotification.Name.UIKeyboardWillHide,
            object: nil)
    }

    @objc func maybeAutoHide() {
        if keyboardPlaceholder.isHidden {
            showFakeKeyboard()
            dismissSelf()
        }
    }

    func setupDrag() {
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(handleDimissPan(_:)))
        dismissPanner.cancelsTouchesInView = true
        dismissPanner.delaysTouchesBegan = false
        contentView.addGestureRecognizer(dismissPanner)

        dragHandle = UIView(frame: .zero)
        dragHandle.radius = 2
        contentView.addSubview(dragHandle, constraints: [
            dragHandle.heightAnchor.constraint(equalToConstant: 4),
            dragHandle.widthAnchor.constraint(equalToConstant: 48),
            dragHandle.bottomAnchor.constraint(equalTo: keyboardPlaceholder.topAnchor, constant: -8),
            dragHandle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    func setupPlaceholderIcons() {
        let backButton = ToolbarIconButton(icon: UIImage(named: "back"))
        let tabButton = ToolbarIconButton(icon: UIImage(named: "tab"))
        leftIconConstraint = backButton.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 8)
        rightIconConstraint = tabButton.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -8)
        contentView.addSubview(backButton, constraints: [
            leftIconConstraint,
            backButton.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
            ])
        contentView.addSubview(tabButton, constraints: [
            rightIconConstraint,
            tabButton.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8)
        ])
    }

    func setupTextView() {
        textView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor).isActive = true
        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        NSLayoutConstraint.activate([
            toolbarBottomMargin,
            textHeightConstraint,
            textView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor)
        ])
    }

    func createTextView() -> UITextView {
        let txt = UITextView()
        txt.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        txt.font = Const.textFieldFont
        txt.text = ""
        txt.placeholder = "Where to?"
        txt.delegate = self
        txt.isScrollEnabled = true
        txt.backgroundColor = .clear
        txt.textColor = .darkText
        txt.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        txt.keyboardAppearance = .light
        txt.enablesReturnKeyAutomatically = true
        txt.keyboardType = .webSearch
        txt.returnKeyType = .go
        txt.autocorrectionType = .no
        txt.translatesAutoresizingMaskIntoConstraints = false
        return txt
    }

    func createSuggestions() -> UITableView {
        let table = UITableView(frame: self.view.frame)
        table.rowHeight = 48.0
        table.register(TypeaheadCell.self, forCellReuseIdentifier: typeaheadReuseID)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.isScrollEnabled = false
        table.separatorStyle = .none
        table.backgroundColor = .clear
        table.backgroundView?.backgroundColor = .clear
        return table
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

        textView.placeholderColor = darkContent
            ? UIColor.black.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = darkContent ? .light : .dark
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            //
        }, completion: { _ in
            self.updateKeyboardSnapshot()
        })
    }

    override func viewWillAppear(_ animated: Bool) {
        // TODO: Why?
        view.frame = UIScreen.main.bounds

        if let browser = self.browserVC {
            textView.text = browser.editableLocation
            pageActionView.title = browser.webView.title
            pageActionView.isBookmarked = false
            pageActionView.isBookmarkEnabled = BookmarkProvider.shared.isLoggedIn

            BookmarkProvider.shared.isBookmarked(browser.webView.url) { isBookmarked in
                self.pageActionView.isBookmarked = isBookmarked
            }
            updateTextViewSize()
            updateHighlight(textView)
            updateSuggestion(for: textView.text)
        }
    }

    func focusTextView() {
        textView.becomeFirstResponder()
        textView.selectAll(nil) // if not nil, will show actions
        keyboardPlaceholder.isHidden = true
    }

//    override func viewDidAppear(_ animated: Bool) {
//        updateKeyboardSnapshot()
//    }

    @objc func dismissSelf() {
        if isTransitioning || view.superview == nil { return }
        showFakeKeyboard()
//        self.dismiss(animated: true)
        transition.direction = .dismiss
        transition.animateTransition(searchVC: self, browserVC: browserVC!, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func updateKeyboardHeight(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardInfo = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey)
        guard let keyboardFrame: NSValue = keyboardInfo as? NSValue else { return }
        let keyboardRectangle = keyboardFrame.cgRectValue

        if keyboardRectangle.height < 10 {
            // thats not what we meant by keyboard height
            return
        }

        keyboard.height = keyboardRectangle.height
        let isTabTransitioning = browserVC?.tabSwitcher.cardStackTransition.isTransitioning ?? false
        if textView.isFirstResponder
            && !kbHeightConstraint.isPopAnimating
            && !isSwiping
            && !isTransitioning
            && !isTabTransitioning {
            // only apply kbheight if textview focused and not animating
            kbHeightConstraint.constant = keyboard.height
        }
    }
}

extension SearchViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateHighlight(textView)
        updateTextViewSize()
        updateSuggestion(for: textView.text)
//        updateBrowserOffset()
    }

    func updateHighlight(_ textView: UITextView) {
        let txt = textView.text!
        if txt.isProbablyURL, let url = URL(string: txt),
            let highlightRange = txt.allNSRanges(of: url.displayHost).first {
            let attrTxt = NSMutableAttributedString(string: txt, attributes: [
                NSAttributedStringKey.foregroundColor: textView.textColor!.withSecondaryAlpha,
                NSAttributedStringKey.font: textView.font!
                ])
            let highlight = [ NSAttributedStringKey.foregroundColor: textView.textColor! ]
            attrTxt.addAttributes(highlight, range: highlightRange)
            textView.attributedText = attrTxt
        } else {
            setBackground(backgroundView.overlayColor!)
            textView.text = txt
        }
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

    var shouldShowActions: Bool {
        return browserVC?.editableLocation == textView.text || (browserVC != nil && textView.text == "")
    }

    func renderSuggestions() {
        if isFakeTab {
            suggestionTable.reloadData()
            suggestionTable.layoutIfNeeded()
            return
        }
        if shouldShowActions {
            contextAreaHeight = pageActionHeight
            actionsHeight.constant = contextAreaHeight
            contextAreaHeightConstraint.constant = contextAreaHeight
        } else {
            actionsHeight.constant = 0
            var suggestionH: CGFloat = 0
            for index in 0..<suggestions.count {
                suggestionH += tableView(
                    suggestionTable,
                    heightForRowAt: IndexPath(row: index, section: 0))
            }
            contextAreaHeight = suggestionH + suggestionSpacer
            suggestionHeightConstraint.constant = suggestionH
        }
//        UIView.animate(withDuration: 0.2) {
//            self.scrim.backgroundColor = self.shouldShowActions ? .clear : UIColor.black.withAlphaComponent(0.2)
//        }
        let anim = contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
        anim?.springBounciness = 2
        anim?.springSpeed = 12
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }

    func updateTextViewSize() {
        let fixedWidth = textView.bounds.size.width
        textView.textContainerInset = TEXTVIEW_PADDING
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        textHeight = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))
        textHeightConstraint.constant = textHeight
        textView.mask?.frame.size.width = textView.bounds.width
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n", let entry = textView.text {
            if entry.isProbablyURL {
                var url: URL?
                if entry.hasPrefix("http://") || entry.hasPrefix("https://") {
                    url = URL(string: entry)
                } else {
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
        if let browser = self.browserVC {
            browser.navigateTo(url)
            setBackground(.white) // since navigate insta-hides
            dismissSelf()
            return
        }
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = suggestions[indexPath.item]
        if let url = row.url { navigateTo(url) }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        let row = suggestions[indexPath.item]
        return row.url != nil
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(MAX_ROWS, suggestions.count)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = tableView.dequeueReusableCell(withIdentifier: typeaheadReuseID, for: indexPath)
        guard let cell = row as? TypeaheadCell else { return row }

        // Configure the cells
        let suggestion = suggestions[indexPath.item]
        let currentText = textView.text ?? ""

        cell.configure(title: suggestion.title, detail: suggestion.detail, highlight: currentText)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let item = suggestions[indexPath.item]
        var h: CGFloat = 48.0
        if let t = item.title, t.count > 60 { h += 20 }
        return h
    }
}

// MARK: - Gesture

let SPACE_FOR_INDICATOR: CGFloat = 26

extension SearchViewController: UIGestureRecognizerDelegate {
    private func verticalPan(gesture: UIPanGestureRecognizer, isEntrance: Bool = false) {

        var dist = gesture.translation(in: view)
        let vel = gesture.velocity(in: view)

        if isEntrance {
            dist.y += keyboard.height
        }
        if browserVC?.gestureController.isDismissing == true {
            dismissSelf()
            return
        }

        if gesture.state == .began {
            showFakeKeyboard()
            isSwiping = true
        } else if gesture.state == .changed {
//            self.iconProgress = (abs(dist.y) / keyboard.height).reverse().clip()
            if dist.y < 0 {
                kbHeightConstraint.constant = keyboard.height
                let elastic = 0.4 * elasticLimit(-dist.y)
                textHeightConstraint.constant = textHeight + elastic
            } else {
                kbHeightConstraint.constant = max(keyboard.height - dist.y, 0)
                contextAreaHeightConstraint.constant = contextAreaHeight
                textHeightConstraint.constant = textHeight
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            isSwiping = false
            if vel.y > 100 || kbHeightConstraint.constant < 50 {
                dismissSelf()
            } else {
                animateCancel()
            }
        }
    }

    func animateCancel() {
        isTransitioning = true
        func finish() {
            isTransitioning = false
            self.showRealKeyboard()
            self.updateTextViewSize() // maybe reenable scrolls
        }
        let fromBelow = kbHeightConstraint.constant < keyboard.height
        let anim = kbHeightConstraint.springConstant(to: keyboard.height) {_, _ in
            if fromBelow { finish() }
        }
        anim?.springBounciness = 2
        anim?.springSpeed = 9
        contextAreaHeightConstraint.springConstant(to: contextAreaHeight)
        suggestionTable.alpha = 1
        pageActionView.alpha = 1
        let ta = textHeightConstraint.springConstant(to: textHeight) { _, _ in
            if !fromBelow { finish() }
        }
        ta?.clampMode = POPAnimationClampFlags.both.rawValue // prevent flickering when textfield too small
    }

    @objc func handleDimissPan(_ gesture: UIPanGestureRecognizer) {
        verticalPan(gesture: gesture, isEntrance: false)
    }

    func handleEntrancePan(_ gesture: UIPanGestureRecognizer) {
        isSwiping = true
        verticalPan(gesture: gesture, isEntrance: true)
    }

    func showFakeKeyboard() {
        updateKeyboardSnapshot()
        keyboardPlaceholder.isHidden = false
        keyboardPlaceholder.image = keyboard.snapshot(for: backgroundView.overlayColor!)
        UIView.setAnimationsEnabled(false)
        textView.resignFirstResponder()
        UIView.setAnimationsEnabled(true)

        // shrink height to snapshot (in case was showing emoji etc)
        if let snapH = keyboardPlaceholder.image?.size.height, snapH < kbHeightConstraint.constant {
            keyboard.height = snapH
            kbHeightConstraint.constant = snapH
        }
    }

    func showRealKeyboard() {
        if isTransitioning || isSwiping { return }
        keyboardPlaceholder.isHidden = true
        UIView.setAnimationsEnabled(false)
        textView.becomeFirstResponder()
        UIView.setAnimationsEnabled(true)
    }

    @objc func updateKeyboardSnapshot() {
        if !textView.isFirstResponder
            || kbHeightConstraint.constant != keyboard.height
            || isTransitioning
            || isSwiping { return }
        keyboard.updateSnapshot(with: backgroundView.overlayColor)
    }
}

// MARK: - Actions
extension SearchViewController: PageActionHandler {
    func refresh() {
        browserVC?.webView.reload()
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
        } else if !pageActionView.isBookmarked {
            guard let url = browserVC?.webView.url, let title = browserVC?.webView.title else { return }
            BookmarkProvider.shared.addBookmark(url, title: title) { isBookmarked in
                if isBookmarked { self.pageActionView.isBookmarked = true }
            }
        } else if pageActionView.isBookmarked {
//            BookmarkProvider.shared.add(browser?.webView.url)
            let options = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            options.addAction(UIAlertAction(title: "Edit", style: .default, handler: nil))
            options.addAction(UIAlertAction(title: "Remove", style: .destructive, handler: { _ in
                guard let url = self.browserVC?.webView.url else { return }
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
        browserVC?.makeShareSheet { avc in
            self.showFakeKeyboard()
            avc.completionWithItemsHandler = { _, _, _, _ in
                self.showRealKeyboard()
            }
            self.present(avc, animated: true, completion: nil)
        }
    }

    func copy() {
        let b = browserVC
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
