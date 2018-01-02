//
//  UIView+POP.swift
//  browse
//
//  Created by Evan Brooks on 12/29/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import pop


struct POPtions {
    var mass, friction, tension: CGFloat?
    
    init(mass: CGFloat? = nil, friction: CGFloat? = nil, tension: CGFloat? = nil) {
        self.mass = mass
        self.friction = friction
        self.tension = tension
    }
}


let kSpringCenter = "springCenter"
let kSpringCenterX = "springCenterX"
let kSpringScale = "springScale"

extension UIView {
    func springCenter(
        to newCenter: CGPoint,
        at velocity: CGPoint = .zero,
        with options: POPtions? = nil,
        then completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) {
        
        if let anim = self.pop_animation(forKey: kSpringCenter) as? POPSpringAnimation {
            anim.toValue = newCenter
        }
        else if let anim = POPSpringAnimation(propertyNamed: kPOPViewCenter) {
            anim.toValue = newCenter
            anim.velocity = velocity
            
            if let m = options?.mass { anim.dynamicsMass = m }
            if let f = options?.friction { anim.dynamicsFriction = f }
            if let t = options?.tension { anim.dynamicsTension = t }
            
            anim.completionBlock = completion
            self.pop_add(anim, forKey: kSpringCenter)
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

}
