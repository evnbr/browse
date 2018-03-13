//
//  PointSpringSwitch.swift
//  browse
//
//  Created by Evan Brooks on 3/12/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

fileprivate let kPositionAnimation = "kPositionAnimation"
fileprivate let kPositionProgress = "kPositionProgress"

typealias PositionSpringUpdateBlock = (CGPoint) -> ()

class PointSpringSwitch : NSObject, SpringTransition {
    typealias ValueType = CGPoint
    
    let updateBlock : PositionSpringUpdateBlock
    private var progress : CGFloat = 1
    var start : CGPoint = .zero
    var end : CGPoint = .zero
    
    init(_ block : @escaping PositionSpringUpdateBlock) {
        updateBlock = block
        super.init()
    }
    
    // Internal
    private var derivedCenter : CGPoint {
        return CGPoint(
            x: progress.blend(from: start.x, to: end.x),
            y: progress.blend(from: start.y, to: end.y)
        )
    }
    
    private var progressPropery: POPAnimatableProperty? {
        return POPAnimatableProperty.property(withName: kPositionProgress, initializer: { prop in
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

        if let anim = self.pop_animation(forKey: kPositionAnimation) as? POPSpringAnimation {
            anim.toValue = newVal
            return anim
        }
        else if let anim = POPSpringAnimation(propertyNamed: kPositionProgress) {
            anim.toValue = newVal
            anim.property = progressPropery
            anim.springBounciness = 3
            anim.springSpeed = 10
            self.pop_add(anim, forKey: kPositionAnimation)
            return anim
        }
        return nil
    }
    
    func setState(_ newState : SpringTransitionState) {
        progress = newState.rawValue
        update()
    }
    
    func update() {
        updateBlock(derivedCenter)
    }
    
    func setValue(of newState: SpringTransitionState, to newValue: CGPoint) {
        if newState == .start { start = newValue }
        else if newState == .end { end = newValue }
    }
}
