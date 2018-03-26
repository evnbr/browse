//
//  SpringSwitch.swift
//  browse
//
//  Created by Evan Brooks on 3/12/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import Foundation
import pop

enum SpringTransitionState : CGFloat {
    case start = 0
    case end = 1
}

fileprivate let kProgressAnimation = "kProgressAnimation"
fileprivate let kProgressProperty = "kProgressProperty"

typealias SpringProgress = CGFloat
typealias SpringUpdateBlock = (SpringProgress) -> ()

class SpringSwitch : NSObject {
    private var progress : SpringProgress = 0

    let updateBlock : SpringUpdateBlock

    init(update block : @escaping SpringUpdateBlock) {
        updateBlock = block
        super.init()
    }
    
    func setState(_ newState : SpringTransitionState) {
        progress = newState.rawValue
        self.updateBlock(progress)
    }
    
    private var progressPropery: POPAnimatableProperty? {
        return POPAnimatableProperty.property(withName: kProgressProperty, initializer: { prop in
            guard let prop = prop else { return }
            prop.readBlock = { obj, values in
                guard let values = values else { return }
                values[0] = self.progress
            }
            prop.writeBlock = { obj, values in
                guard let values = values else { return }
                self.progress = values[0]
                self.updateBlock(self.progress)
            }
            prop.threshold = 0.001
        }) as? POPAnimatableProperty
    }
    
    // External
    @discardableResult
    func springState(_ newState : SpringTransitionState, completion: SpringCompletionBlock? = nil) -> POPSpringAnimation? {
        let newVal : CGFloat = newState.rawValue
        guard newVal != progress else {
            updateBlock(progress)
            return nil
        }
        
        if let anim = self.pop_animation(forKey: kProgressAnimation) as? POPSpringAnimation {
            anim.toValue = newVal
            if let c = completion { anim.completionBlock = c }
            return anim
        }
        else if let anim = POPSpringAnimation(propertyNamed: kProgressProperty) {
            anim.toValue = newVal
            anim.property = progressPropery
            anim.springBounciness = 1
            anim.springSpeed = 5
            if let c = completion { anim.completionBlock = c }
            self.pop_add(anim, forKey: kProgressAnimation)
            return anim
        }
        return nil
    }
    
    func cancel() {
        self.pop_removeAnimation(forKey: kProgressAnimation)
    }
}

