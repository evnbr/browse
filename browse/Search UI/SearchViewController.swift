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
let maxTypeaheadSuggestions: Int = 8
let maxTextFieldHeight: CGFloat = 240.0
let textFieldInsets = UIEdgeInsets(top: 11, left: 16, bottom: 12, right: 16)
let pageActionHeight: CGFloat = 20 //100

let baseSheetHeight: CGFloat = 500

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
    var dragHandle: UIView!
    var pageActionView: PageActionView!
    var keyboard = KeyboardManager()

    var isTransitioning = false
    var isSwiping = false
    
    var hasDraft = false

    var transition = SearchTransitionController()

    var kbHeightConstraint: NSLayoutConstraint!
    var sheetHeight: NSLayoutConstraint!
    var textHeightConstraint: NSLayoutConstraint!
    var toolbarBottomMargin: NSLayoutConstraint!

    private var leftIconConstraint: NSLayoutConstraint!
    private var rightIconConstraint: NSLayoutConstraint!

    var textHeight: CGFloat = 40

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

        scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
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
        contentView.radius = 16
        view.addSubview(contentView)
        
        shadowView = UIView(frame: view.bounds)
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        let path = UIBezierPath(roundedRect: contentView.bounds, cornerRadius: 12)
        shadowView.layer.shadowPath = path.cgPath
        shadowView.layer.shadowOpacity = 0.1
        shadowView.layer.shadowRadius = 24
        view.insertSubview(shadowView, belowSubview: contentView)
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: contentView.topAnchor),
            shadowView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            shadowView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            shadowView.heightAnchor.constraint(equalToConstant: 100),
        ])
        
        backgroundView = PlainBlurView(frame: contentView.bounds)
        backgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundView.overlayAlpha = 0.9
        contentView.addSubview(backgroundView)

        sheetHeight = contentView.heightAnchor.constraint(equalToConstant: baseSheetHeight)
        NSLayoutConstraint.activate([
            contentView.leftAnchor.constraint(equalTo: view.leftAnchor),
            contentView.rightAnchor.constraint(equalTo: view.rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetHeight
        ])
        
        kbHeightConstraint = contentView.heightAnchor.constraint(equalToConstant: 400)


        suggestionTable = createSuggestions()
        textView = createTextView()
        contentView.addSubview(textView)

        let maskView = UIView(frame: textView.bounds)
        maskView.backgroundColor = .red
        maskView.frame = textView.bounds
        maskView.radius = 24
        maskView.frame.size.height = 500 // TODO Large number because mask is scrollable :(
        textView.mask = maskView

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
        
        let suggestionHeightConstraint = suggestionTable.heightAnchor.constraint(
            equalToConstant: 500)
        contentView.addSubview(suggestionTable, constraints: [
            suggestionHeightConstraint,
            suggestionTable.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            suggestionTable.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            suggestionTable.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8)
        ])
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
            dragHandle.topAnchor.constraint(equalTo: textView.topAnchor, constant: -8),
            dragHandle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    func setupPlaceholderIcons() {
        let backButton = ToolbarIconButton(icon: UIImage(named: "back"))
        let tabButton = ToolbarIconButton(icon: UIImage(named: "action"))
        leftIconConstraint = backButton.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 8)
        rightIconConstraint = tabButton.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -8)
        contentView.addSubview(backButton, constraints: [
            leftIconConstraint,
            backButton.topAnchor.constraint(equalTo: textView.topAnchor, constant: -4)
            ])
        contentView.addSubview(tabButton, constraints: [
            rightIconConstraint,
            tabButton.topAnchor.constraint(equalTo: textView.topAnchor, constant: -4)
        ])
    }

    func setupTextView() {
        textHeightConstraint = textView.heightAnchor.constraint(equalToConstant: 36)
        NSLayoutConstraint.activate([
            textHeightConstraint,
            textView.topAnchor.constraint(
                equalTo: contentView.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            textView.trailingAnchor.constraint(
                equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -12)
        ])
    }

    func createTextView() -> UITextView {
        let txt = UITextView()
        txt.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        txt.translatesAutoresizingMaskIntoConstraints = false
        
        txt.font = Const.textFieldFont
        txt.text = ""
        txt.placeholder = "Where to?"
        
        txt.delegate = self
        txt.isScrollEnabled = true
        
        txt.backgroundColor = .darkTouch
        txt.textColor = .darkText
        txt.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        txt.keyboardAppearance = .light
        
        txt.enablesReturnKeyAutomatically = true
        txt.keyboardType = .webSearch
        txt.returnKeyType = .go
        txt.autocorrectionType = .no
        
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

        let isBackgroundLight = !newColor.isLight
        backgroundView.overlayColor = newColor
        view.tintColor = isBackgroundLight ? .darkText : .white
        contentView.tintColor = view.tintColor
        textView.textColor = view.tintColor
        dragHandle.backgroundColor = view.tintColor.withAlphaComponent(0.2)

        textView.placeholderColor = isBackgroundLight
            ? UIColor.black.withAlphaComponent(0.4)
            : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = isBackgroundLight ? .light : .dark
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: { _ in
            //
        }, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        // TODO: Why?
        view.frame = UIScreen.main.bounds

        if let browser = browserVC, !hasDraft {
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
    }


    @objc func dismissSelf() {
        if isTransitioning || view.superview == nil { return }
//        showFakeKeyboard()
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
        TypeaheadProvider.shared.suggestions(
            for: textView.text,
            maxCount: maxTypeaheadSuggestions
        ) { newList in
            // If text has changed since return, bail early
            if self.textView.text != suggestionsForText { return }
            self.suggestions = newList
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
        suggestionTable.reloadData()
        suggestionTable.layoutIfNeeded()
    }

    func updateTextViewSize() {
        let fixedWidth = textView.bounds.size.width
        textView.textContainerInset = textFieldInsets
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        textView.isScrollEnabled = fullTextSize.height > maxTextFieldHeight
        textHeight = max(20, min(fullTextSize.height, maxTextFieldHeight))
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
            setBackground(.black) // since navigate insta-hides
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
        return min(maxTypeaheadSuggestions, suggestions.count)
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
        var h: CGFloat = 60.0
//        if let t = item.title, t.count > 60 { h += 20 }
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
            dist.y += baseSheetHeight - Const.toolbarHeight
        }
        if browserVC?.gestureController.isDismissing == true {
            dismissSelf()
            return
        }

        if gesture.state == .began {
            isSwiping = true
            textView.resignFirstResponder()
        } else if gesture.state == .changed {
//            self.iconProgress = (abs(dist.y) / keyboard.height).reverse().clip()
            if dist.y < 0 {
                let elastic = 1 * elasticLimit(-dist.y)
                sheetHeight.constant = baseSheetHeight + elastic
            } else {
                sheetHeight.constant = max(baseSheetHeight - dist.y, 0)
            }
        } else if gesture.state == .ended || gesture.state == .cancelled {
            isSwiping = false
            if vel.y > 100 || kbHeightConstraint.constant < 50 {
                dismissSelf()
            } else {
                animateCancel(at: gesture.velocity(in: view))
            }
        }
    }

    func animateCancel(at velocity: CGPoint) {
        isTransitioning = true
//        textView.becomeFirstResponder()
        
        let anim = sheetHeight.springConstant(to: baseSheetHeight, at: -velocity.y) {_, _ in
            self.isTransitioning = false
        }
        anim?.springBounciness = 1
        anim?.springSpeed = 8
    }

    @objc func handleDimissPan(_ gesture: UIPanGestureRecognizer) {
        verticalPan(gesture: gesture, isEntrance: false)
    }

    func handleEntrancePan(_ gesture: UIPanGestureRecognizer) {
        isSwiping = true
        verticalPan(gesture: gesture, isEntrance: true)
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
            }))
            options.addAction(UIAlertAction(title: "Log Out", style: .default, handler: { _ in
                BookmarkProvider.shared.logOut()
                self.pageActionView.isBookmarkEnabled = false
                self.pageActionView.isBookmarked = false
            }))
            options.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            }))
            DispatchQueue.main.async {
                self.present(options, animated: true)
            }
        }
    }

    func share() {
        browserVC?.makeShareSheet { avc in
            self.present(avc, animated: true, completion: nil)
        }
    }

    func copy() {
        let b = browserVC
        b?.copyURL()
        let alert = UIAlertController(title: "Copied", message: nil, preferredStyle: .alert)
        present(alert, animated: true, completion: {
            alert.dismiss(animated: true)
        })
    }
}
