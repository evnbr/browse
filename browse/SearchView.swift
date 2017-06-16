//
//  SearchView.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

let SEARCHVIEW_MAX_H : CGFloat = 160.0

class SearchView: UIView, UITextViewDelegate {
    
    var webViewController : WebViewController!
    var textView : SearchTextView!
    var cancel   : UIButton!
    
    var isEnabled : Bool {
        get {
            return self.isUserInteractionEnabled
        }
        set {
            if !newValue {
                UIView.animate(withDuration: 0.3, animations: {
                    self.alpha = 0
                })
            }
            else {
                self.alpha = 1
            }
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
        textView.text = ""
        
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.inputAccessoryView = self
        textView.autocorrectionType = .no

        textView.delegate = self
        textView.isScrollEnabled = true
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
        
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[text]-0-|", options: [], metrics: nil, views: ["text": self.textView]))
        self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[text]-0-|", options: [], metrics: nil, views: ["text": self.textView]))
        let maxH = self.heightAnchor.constraint(lessThanOrEqualToConstant: SEARCHVIEW_MAX_H)
        self.addConstraints([maxH])
        
        updateSize()
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width
        
        let leftMargin = cancel.frame.size.width + 28

        textView.textContainerInset = UIEdgeInsetsMake(13, 14, 13, leftMargin)

        let fullTextSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: .greatestFiniteMagnitude))
        var newFrame = textView.frame
        
        let newHeight: CGFloat = min(fullTextSize.height, SEARCHVIEW_MAX_H)  // 80.0
        textView.isScrollEnabled = fullTextSize.height > SEARCHVIEW_MAX_H
        
        newFrame.size = CGSize(width: max(fullTextSize.width, fixedWidth), height: newHeight)
        textView.frame = newFrame;

        var frame = self.frame
        frame.size.height = newFrame.size.height
        self.frame = frame
        
//        textView.invalidateIntrinsicContentSize()
        self.invalidateIntrinsicContentSize()
    }
    
    override public var intrinsicContentSize: CGSize {
        get {
            return frame.size
        }
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

        self.hide()

        UIView.animate(withDuration: 0.3, animations: {
            textView.transform = CGAffineTransform(translationX: 30, y: 0)
            textView.alpha = 0
            self.cancel.transform = CGAffineTransform(translationX: 60, y: 0)
            
            var frame = self.frame
            frame.origin.y = frame.size.height - 36
            frame.size.height = TOOLBAR_H
            self.frame = frame
            
        }, completion: { completed in
            self.isEnabled = false
            textView.selectedTextRange = nil
        })
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updateSize()
    }
    
    func hide() {
        webViewController.hideSearch()
    }
    
    
    func prepareToShow() {
        textView.text = webViewController.editableURL
        
        self.backgroundColor = webViewController.toolbar.back.backgroundColor
        self.tintColor = webViewController.toolbar.tintColor
        textView.textColor = webViewController.toolbar.tintColor
        
        textView.keyboardAppearance = self.backgroundColor!.isLight ? .dark : .light
        textView.placeholderColor = self.backgroundColor!.isLight
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
