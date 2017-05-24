//
//  SearchView.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class SearchView: UIView, UITextViewDelegate {
    
    var webViewController : WebViewController!
    var textView : SearchTextView!
    var cancel   : UIButton!
    
    var isEnabled : Bool {
        get {
            return self.isUserInteractionEnabled
        }
        set {
            self.alpha = newValue ? 1 : 0
            self.isUserInteractionEnabled = newValue
        }
    }
    
    init(for vc: WebViewController) {
        super.init(frame: CGRect(
            x: 0,
            y: 300,
            width: UIScreen.main.bounds.width,
            height: 600
        ))
        
        webViewController = vc
        
        self.backgroundColor = UIColor.white
        self.isEnabled = false

        textView = SearchTextView()
        textView.frame = CGRect(x: 4, y: 4, width: UIScreen.main.bounds.width - 8, height: 100)
        textView.placeholder = "Where to?"
        
        textView.backgroundColor = UIColor.clear
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = "Test"
        
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.inputAccessoryView = self
        textView.autocorrectionType = .no

        textView.delegate = self
        textView.isScrollEnabled = false
//        textView.layer.cornerRadius = 5.0
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(textView)

        cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(hide), for: .primaryActionTriggered)
        cancel.sizeToFit()
        let cancelOrigin = CGPoint(
            x: self.frame.size.width - cancel.frame.size.width - 12,
            y: self.frame.size.height - cancel.frame.size.height - 8
        )
        cancel.frame = CGRect(origin: cancelOrigin, size: cancel.frame.size)
        self.addSubview(cancel)
        cancel.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin]
        
        self.autoresizingMask = UIViewAutoresizing.flexibleHeight
        let margin = Int(cancel.frame.size.width) + 28
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-8-[text]-\(margin)-|", options: [], metrics: nil, views: ["text": self.textView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-8-[text]-8-|", options: [], metrics: nil, views: ["text": self.textView]))

        updateSize()
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width
        
        textView.textContainerInset = UIEdgeInsetsMake(5, 6, 5, 6)
        textView.contentInset = .zero

        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        textView.frame = newFrame;
        
        var frame = self.frame
        frame.size.height = textView.frame.size.height + 16
        self.frame = frame
        
        textView.invalidateIntrinsicContentSize()
    }
    
    override public var intrinsicContentSize: CGSize {
        get { return frame.size }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.isEnabled = true
        
        textView.transform = CGAffineTransform(translationX: 20, y: 0)
        textView.alpha = 0
        cancel.transform = CGAffineTransform(translationX: 60, y: 0)

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = .identity
            textView.alpha = 1
            self.cancel.transform = .identity
        }, completion: { completed in
            textView.selectAll(nil) // if not nil, will show actions
        })
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.transform = .identity
        textView.alpha = 1
        cancel.transform = .identity

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = CGAffineTransform(translationX: 20, y: 0)
            textView.alpha = 0
            self.cancel.transform = CGAffineTransform(translationX: 60, y: 0)
        }, completion: { completed in
            self.isEnabled = false
            textView.selectedTextRange = nil
        })
        
        hide()
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updateSize()
    }
    
    func hide() {
        webViewController.hideSearch()
    }
    
    
    func prepareToShow() {
        textView.text = webViewController.editableURL
        
        self.backgroundColor = webViewController.webViewColor.bottom
        self.tintColor = webViewController.toolbar.tintColor
        textView.textColor = webViewController.toolbar.tintColor
        
        textView.keyboardAppearance = webViewController.webViewColor.bottom.isLight ? .dark : .light
        textView.placeholderColor = webViewController.webViewColor.bottom.isLight
            ? UIColor.white.withAlphaComponent(0.4)
            : UIColor.black.withAlphaComponent(0.2)

//        textView.backgroundColor = siteController.colorAtBottom.isLight()
//            ? UIColor.white.withAlphaComponent(0.1)
//            : UIColor.black.withAlphaComponent(0.08)

        updateSize()
    }
    
    
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            hide()
            webViewController.navigateToText(textView.text!)
            return false
        }
        return true
    }
    
}
