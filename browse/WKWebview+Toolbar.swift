//
//  WKWebview+Toolbar.swift
//  browse
//
//  Created by Evan Brooks on 8/20/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
// https://robopress.robotsandpencils.com/swift-swizzling-wkwebview-168d7e657106

import Foundation
import WebKit

private var toolbarHandle: UInt8 = 0

extension WKWebView {
    func addInputAccessory(toolbar: UIView) {
        objc_setAssociatedObject(self, &toolbarHandle, toolbar, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        var candidateView: UIView? = nil
        for view in self.scrollView.subviews {
            if String(describing: type(of: view)).hasPrefix("WKContent") {
                candidateView = view
            }
        }
        guard let targetView = candidateView else { return }
        let newClass: AnyClass? = classWithCustomAccessoryView(targetView)
        object_setClass(targetView, newClass!)
    }
    
    private func classWithCustomAccessoryView(_ targetView: UIView) -> AnyClass? {
        guard let targetSuperClass = targetView.superclass else { return nil }
        let customInputAccessoryViewClassName = "\(targetSuperClass)_CustomInputAccessoryView"
        
        var newClass: AnyClass? = NSClassFromString(customInputAccessoryViewClassName)
        if newClass == nil {
            newClass = objc_allocateClassPair(object_getClass(targetView), customInputAccessoryViewClassName, 0)
        } else {
            return newClass
        }
        
        let newMethod = class_getInstanceMethod(WKWebView.self, #selector(WKWebView.getCustomInputAccessoryView))
        class_addMethod(newClass.self, Selector("inputAccessoryView"), method_getImplementation(newMethod!), method_getTypeEncoding(newMethod!))
        
        objc_registerClassPair(newClass!)
        
        return newClass
    }
    
    @objc func getCustomInputAccessoryView() -> UIView? {
        var superWebView: UIView? = self
        while superWebView != nil && !(superWebView is WKWebView) {
            superWebView = superWebView?.superview
        }
        let customInputAccessory = objc_getAssociatedObject(superWebView!, &toolbarHandle)
        return customInputAccessory as? UIView
    }
}
