//
//  SearchViewController.swift
//  browse
//
//  Created by Evan Brooks on 5/18/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class SearchViewController: UIViewController, UITextViewDelegate, UIGestureRecognizerDelegate {

    var senderVC : SiteViewController!
    var textView : UITextView!
    var scrim : UIView!
    var panel : UIView!

    static let PANEL_TAG = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()

//        view.frame = CGRect(
//            x: 0,
//            y: UIScreen.main.bounds.height - 200,
//            width: UIScreen.main.bounds.width,
//            height: 200
//        )
        view.backgroundColor = UIColor.clear
        view.isOpaque = false
        
        let panner = UIPanGestureRecognizer()
        panner.delegate = self
        panner.addTarget(self, action: #selector(didPanDown))
        self.view.addGestureRecognizer(panner)

        
        scrim = UIView(frame: UIScreen.main.bounds)
        scrim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(scrim)
        
        panel = UIView(frame: CGRect(
            x: 0,
            y: 300,
            width: UIScreen.main.bounds.width,
            height: 600
        ))
        panel.backgroundColor = UIColor.white
        panel.tag = SearchViewController.PANEL_TAG
        view.addSubview(panel)
        
        textView = UITextView()
        textView.frame = CGRect(x: 4, y: 40, width: UIScreen.main.bounds.width - 8, height: 100)
        
        textView.backgroundColor = UIColor.black.withAlphaComponent(0.04)
        textView.font = UIFont(descriptor: .preferredFontDescriptor(withTextStyle: .body), size: 17)
        textView.text = "Test"
        textView.keyboardType = UIKeyboardType.webSearch
        textView.returnKeyType = .go
        textView.delegate = self
        textView.isScrollEnabled = false

        panel.addSubview(textView)
        updateSize()
        
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(dismissSelf), for: .primaryActionTriggered)
        cancel.frame = CGRect(x: 12, y: 12, width: 80, height: 80)
        cancel.sizeToFit()
        panel.addSubview(cancel)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updateSize()
    }
    
    func updateSize() {
        let fixedWidth = textView.frame.size.width
        textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        let newSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        var newFrame = textView.frame
        newFrame.size = CGSize(width: max(newSize.width, fixedWidth), height: newSize.height)
        textView.frame = newFrame;
        
        textView.textContainerInset = UIEdgeInsetsMake(12, 12, 12, 12)
        textView.contentInset = .zero
        
//        var frame = panel.frame
//        frame.size.height = textView.frame.size.height + 100
//        panel.frame = frame
        //        textView.scrollRangeToVisible(NSMakeRange(0, 0))
    }
    
    func dismissSelf() {
        self.dismiss(animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        textView.text = senderVC.webView.url?.absoluteString
        panel.backgroundColor = senderVC.colorAtBottom
        panel.tintColor = senderVC.toolbar.tintColor
        textView.textColor = senderVC.toolbar.tintColor
        
        textView.keyboardAppearance = senderVC.colorAtBottom.isLight() ? .dark : .light
        
        updateSize()
        if !textView.isFirstResponder {
            textView.becomeFirstResponder()
        }
        textView.selectAll(nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        textView.resignFirstResponder()
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if(text == "\n") {
            dismissSelf()
            senderVC.navigateToText(textView.text!)
            return false
        }
        return true
    }

//    func didPanDown(sender: UIPanGestureRecognizer) {
//        let progress = ( sender.translation(in: self.view).y/(self.view.frame.size.height - 200) )
//        let y = sender.translation(in: self.view).y
//        
//        switch sender.state {
//        case .began:
//            self.panel.transform = CGAffineTransform.identity.translatedBy(x: 0, y: y)
//            self.textView.resignFirstResponder()
//        case .changed:
//            self.panel.transform = CGAffineTransform.identity.translatedBy(x: 0, y: y)
//        case .ended:
//            let vel = sender.velocity(in: self.view).y
//            if vel > 300 || progress > 0.5 {
//                dismissSelf()
//            } else {
//                cancelPan(atVelocity: vel)
//            }
//        default:
//            cancelPan(atVelocity: 0)
//        }
//    }
//    
//    func cancelPan(atVelocity vel: CGFloat) {
//        UIView.animate(
//            withDuration: 0.8,
//            delay: 0,
//            usingSpringWithDamping: 1.0,
//            initialSpringVelocity: vel / (self.panel.transform.ty),
//            options: .allowUserInteraction, animations: {
//                self.panel.transform = CGAffineTransform.identity
//        })
//    }

    func didPanDown(sender: UIPanGestureRecognizer) {
        let progress = ( sender.translation(in: self.view.superview).y/((self.view.superview?.frame.size.height)! - 200) )
//        let progress = sender.translation(in: self.view.superview).y/(self.view.superview?.frame.size.height)!
        
        switch sender.state {
        case .began:
            self.senderVC.interactionController = UIPercentDrivenInteractiveTransition()
            self.dismiss(animated: true, completion: nil)
        case .changed:
            print(self.panel.transform.ty)
            if (progress < 0) {
                let y = sender.translation(in: self.view).y + UIScreen.main.bounds.height - 60
                self.panel.transform = CGAffineTransform.identity.translatedBy(x: 0, y: y)
            }
            else {
                self.senderVC.interactionController?.update(progress)
            }
        case .ended:
            let vel = sender.velocity(in: self.view).y
            if vel > 300 || progress > 0.5 {
                self.senderVC.interactionController?.finish()
            } else {
                self.senderVC.interactionController?.cancel()
            }
            
            self.senderVC.interactionController = nil
        default:
            self.senderVC.interactionController?.cancel()
            self.senderVC.interactionController = nil
        }
    }
}
