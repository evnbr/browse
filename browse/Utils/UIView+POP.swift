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

extension UIView {
    func springCenter(
        to newCenter: CGPoint,
        at velocity: CGPoint = .zero,
        options: POPtions? = nil,
        completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) {
        
        if let anim = POPSpringAnimation(propertyNamed: kPOPViewCenter) {
            anim.toValue = newCenter
            anim.velocity = velocity
            
            if let m = options?.mass { anim.dynamicsMass = m }
            if let f = options?.friction { anim.dynamicsFriction = f }
            if let t = options?.tension { anim.dynamicsTension = t }
            
            anim.completionBlock = completion
            self.pop_add(anim, forKey: "commitAnim")
        }
    }
    
    func springScale(
        to newScale: CGFloat,
        at velocity: CGPoint = .zero,
        completion: @escaping (POPAnimation?, Bool) -> Void = {_,_ in } ) {

        if let anim = POPSpringAnimation(propertyNamed: kPOPViewScaleXY) {
            anim.toValue = CGPoint(x: newScale, y: newScale)
            anim.velocity = velocity
            anim.completionBlock = completion
            self.pop_add(anim, forKey: "resetScale")
        }
    }
}
