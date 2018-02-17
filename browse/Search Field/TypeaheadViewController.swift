//
//  TypeaheadViewController.swift
//  browse
//
//  Created by Evan Brooks on 2/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class TypeaheadViewController: UIViewController {

    var contentView: UIView!
    var scrim: UIView!
    var textView : SearchTextView!
    var cancel   : ToolbarTextButton!

    var kbHeightConstraint : NSLayoutConstraint!
    var fullWidthConstraint : NSLayoutConstraint!
    var roomForCancelConstraint : NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        
        scrim = UIView(frame: view.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        scrim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        scrim.addGestureRecognizer(tap)
        
        view.addSubview(scrim)
        
        contentView = UIView(frame: view.bounds)
        contentView.layer.cornerRadius = 12
        contentView.backgroundColor = .white
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.tintColor = .darkText
        view.addSubview(contentView)
        
        contentView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        contentView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        contentView.heightAnchor.constraint(equalToConstant: 200).isActive = true
        kbHeightConstraint = contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        kbHeightConstraint.isActive = true

        textView = SearchTextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 48)
        textView.placeholder = "Where to?"
        
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = ""
        
        textView.delegate = self
        textView.isScrollEnabled = true
        
        textView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        textView.layer.cornerRadius = SEARCH_RADIUS
        textView.textColor = .darkText
        textView.placeholderColor = UIColor.white.withAlphaComponent(0.4)
        
        textView.keyboardAppearance = .light
        textView.enablesReturnKeyAutomatically = true
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.autocorrectionType = .no
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        cancel = ToolbarTextButton(title: "Cancel", withIcon: nil, onTap: dismissSelf)
        cancel.size = .medium
        cancel.sizeToFit()
        cancel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancel)
        cancel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16).isActive = true
        cancel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -8).isActive = true
        cancel.widthAnchor.constraint(equalToConstant: cancel.bounds.width).isActive = true
        cancel.heightAnchor.constraint(equalToConstant: cancel.bounds.height).isActive = true

        textView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 16).isActive = true
        textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16).isActive = true
        
        fullWidthConstraint = textView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -16)
        roomForCancelConstraint = textView.widthAnchor.constraint(equalTo: contentView.widthAnchor, constant: -cancel.frame.width - 16)
        fullWidthConstraint.isActive = false
        roomForCancelConstraint.isActive = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: NSNotification.Name.UIKeyboardDidChangeFrame, object: nil)
        
        setMode(darkContent: true)
    }
    
    func setMode(darkContent: Bool) {
        view.tintColor = darkContent ? .darkText : .white
        textView.textColor = view.tintColor
        textView.backgroundColor = darkContent ? UIColor.black.withAlphaComponent(0.1) : UIColor.white.withAlphaComponent(0.3)
        textView.placeholderColor = darkContent ? UIColor.black.withAlphaComponent(0.4) : UIColor.white.withAlphaComponent(0.4)
        textView.keyboardAppearance = darkContent ? .light : .dark
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let browser = self.presentingViewController as? BrowserViewController {
            textView.text = browser.editableLocation
            updateTextViewSize()
        }
        
        textView.becomeFirstResponder()
        textView.selectAll(nil) // if not nil, will show actions
    }
    
    @objc
    func dismissSelf() {
        self.dismiss(animated: true)
        textView.resignFirstResponder()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateTextViewSize() {
        let fixedWidth = textView.frame.size.width
        
        textView.textContainerInset = UIEdgeInsetsMake(9, 12, 9, 12)
        
        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        
        let newHeight: CGFloat = max(20, min(fullTextSize.height, SEARCHVIEW_MAX_H))  // 80.0
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        
        newFrame.size = CGSize(width: max(fullTextSize.width, fixedWidth), height: newHeight)
        textView.frame = newFrame;
    }
    
    var keyboardHeight : CGFloat = 250
    @objc func keyboardWillShow(notification: NSNotification) {
        let userInfo: NSDictionary = notification.userInfo! as NSDictionary
        let keyboardFrame: NSValue = userInfo.value(forKey: UIKeyboardFrameEndUserInfoKey) as! NSValue
        let keyboardRectangle = keyboardFrame.cgRectValue
        keyboardHeight = keyboardRectangle.height
//        kbHeightConstraint.constant = -keyboardHeight
        // update
    }
}
    
extension TypeaheadViewController : UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateTextViewSize()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            if let browser = self.presentingViewController as? BrowserViewController {
                browser.navigateToText(textView.text)
            }
            dismissSelf()
            return false
        }
        return true
    }

}
