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

class SpringSwitch<T : Blendable> : NSObject {
    var progress : CGFloat = 1
    var start : T = T.initialValue
    var end : T = T.initialValue

    typealias SpringUpdateBlock = (T) -> ()
    let updateBlock : SpringUpdateBlock

    init(update block : @escaping SpringUpdateBlock) {
        updateBlock = block
        super.init()
    }
    
    func setState(_ newState : SpringTransitionState) {
        progress = newState.rawValue
        update()
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
        
        if let anim = self.pop_animation(forKey: kProgressAnimation) as? POPSpringAnimation {
            anim.toValue = newVal
            return anim
        }
        else if let anim = POPSpringAnimation(propertyNamed: kProgressProperty) {
            anim.toValue = newVal
            anim.property = progressPropery
            anim.springBounciness = 1
            anim.springSpeed = 10
            self.pop_add(anim, forKey: kProgressAnimation)
            return anim
        }
        return nil
    }
    
    private func update() {
        let newVal : T = T.blend(from: start, to: end, by: progress)
        updateBlock(newVal)
    }
    
    func setValue(of: SpringTransitionState, to newValue: T) {
        if of == .start { start = newValue }
        else if of == .end { end = newValue }
    }
}

