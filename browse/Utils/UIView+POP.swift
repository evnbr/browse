//
//  UIView+POP.swift
//  browse
//
//  Created by Evan Brooks on 12/29/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import pop

let kSpringCenter = "springCenter"
let kSpringCenterX = "springCenterX"
let kSpringScale = "springScale"
let kSpringBounds = "springBounds"
let kSpringContentOffset = "springContentOffset"

extension UIView {
    
    var isPopAnimating : Bool {
        let anims = self.pop_animationKeys()
        return anims != nil && anims!.count > 0
    }
    
    @discardableResult
    func springCenter(
        to newCenter: CGPoint,
        at velocity: CGPoint = .zero,
        after delay: CFTimeInterval = 0,
        then completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) -> POPSpringAnimation? {
        
        if let anim = self.pop_animation(forKey: kSpringCenter) as? POPSpringAnimation {
            anim.toValue = newCenter
            return anim
        }
        else if let anim = POPSpringAnimation(propertyNamed: kPOPViewCenter) {
            anim.toValue = newCenter
            anim.velocity = velocity
            anim.beginTime = CACurrentMediaTime() + delay
            
            anim.completionBlock = completion
            self.pop_add(anim, forKey: kSpringCenter)
            return anim
        }
        return nil
    }
    
    func springBounds(
        to newBounds: CGRect,
        at velocity: CGRect = .zero,
        then completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) {
        
        if let anim = self.pop_animation(forKey: kSpringBounds) as? POPSpringAnimation {
            anim.toValue = newBounds
        }
        else if let anim = POPSpringAnimation(propertyNamed: kPOPViewBounds) {
            anim.toValue = newBounds
            anim.velocity = velocity
            
            anim.completionBlock = completion
            self.pop_add(anim, forKey: kSpringBounds)
        }
    }

    func springScale(
        to newScale: CGFloat,
        at velocity: CGPoint = .zero,
        then completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) {

        let newScalePoint = CGPoint(x: newScale, y: newScale)
        
        if let anim = self.pop_animation(forKey: kSpringScale) as? POPSpringAnimation {
            anim.toValue = newScalePoint
        }
        else if let anim = POPSpringAnimation(propertyNamed: kPOPViewScaleXY) {
            anim.toValue = newScalePoint
            anim.velocity = velocity
            anim.completionBlock = completion
            self.pop_add(anim, forKey: kSpringScale)
        }
    }
}

extension UIScrollView {
    func springBottomInset(
        to newBottomInset: CGFloat) {
        
        if let anim = POPSpringAnimation(propertyNamed: kPOPScrollViewContentInset ) {
            var insets = self.contentInset
            insets.bottom = newBottomInset
            anim.toValue = insets
            self.pop_add(anim, forKey: "springBottomInset")
        }
    }
    func springContentOffset(
        to newOffset: CGPoint) {
        
        if let anim = POPSpringAnimation(propertyNamed: kPOPScrollViewContentOffset ) {
            anim.toValue = newOffset
            self.pop_add(anim, forKey: kSpringContentOffset)
        }
    }
}

extension NSLayoutConstraint {
    func springConstant(to newConstant: CGFloat) {
        if let anim = POPSpringAnimation(propertyNamed: kPOPLayoutConstraintConstant ) {
            anim.toValue = newConstant
            anim.clampMode = POPAnimationClampFlags.end.rawValue
            self.pop_add(anim, forKey: "springConstant")
        }
    }
}
