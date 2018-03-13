//
//  NumberSpringSwitch.swift
//  browse
//
//  Created by Evan Brooks on 3/12/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

fileprivate let kScaleAnimation = "kScaleAnimation"
fileprivate let kScaleProgress = "kScaleProgress"

typealias NumberSpringUpdateBlock = (CGFloat) -> ()

class NumberSpringSwitch: NSObject, SpringTransition {
    typealias ValueType = CGFloat
    
    let updateBlock : NumberSpringUpdateBlock
    private var progress : CGFloat = 1
    
    private var start : CGFloat = 1
    private var end : CGFloat = 1
    
    init(_ block : @escaping NumberSpringUpdateBlock) {
        updateBlock = block
        super.init()
    }
    
    // Internal
    private var derivedScale : CGFloat {
        return progress.blend(from: start, to: end)
    }
    
    private var progressPropery: POPAnimatableProperty? {
        return POPAnimatableProperty.property(withName: kScaleProgress, initializer: { prop in
            guard let prop = prop else { return }
            prop.readBlock = { obj, values in
                guard let values = values else { return }
                values[0] = self.progress
            }
            prop.writeBlock = { obj, values in
                guard let values = values else { return }
                self.progress = values[0]
                self.update()
            }
            prop.threshold = 0.01
        }) as? POPAnimatableProperty
    }
    
    // External
    @discardableResult
    func springState(_ newState : SpringTransitionState) -> POPSpringAnimation? {
        let newVal : CGFloat = newState.rawValue
        guard newVal != progress else {
            update()
            return nil
        }
        
        if let anim = self.pop_animation(forKey: kScaleAnimation) as? POPSpringAnimation {
            anim.toValue = newVal
            return anim
        }
        else if let anim = POPSpringAnimation(propertyNamed: kScaleProgress) {
            anim.toValue = newVal
            anim.property = progressPropery
            anim.springBounciness = 3
            anim.springSpeed = 10
            self.pop_add(anim, forKey: kScaleAnimation)
            return anim
        }
        return nil
    }
    
    func setState(_ newState : SpringTransitionState) {
        progress = newState.rawValue
        update()
    }
    
    private func update() {
        updateBlock(derivedScale)
    }

    func setValue(of: SpringTransitionState, to newValue: CGFloat) {
        if of == .start { start = newValue }
        else if of == .end { end = newValue }
    }
}
