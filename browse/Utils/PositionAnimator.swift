//
//  PositionAnimator.swift
//  browse
//
//  Created by Evan Brooks on 3/12/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import pop

fileprivate let kPositionAnimation = "kPositionAnimation"
fileprivate let kPositionProgress = "kPositionProgress"

enum PositionAnimatorState : CGFloat {
    case start = 0
    case end = 1
}

class PositionAnimator : NSObject {
    
    var view : UIView!
    private var progress : CGFloat = 1
    
    var startCenter : CGPoint = .zero
    var endCenter : CGPoint = .zero
    
    convenience init(view: UIView) {
        self.init()
        self.view = view
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
    
    @discardableResult
    func springState(_ newState : PositionAnimatorState) -> POPSpringAnimation? {
        let newVal : CGFloat = newState.rawValue
        guard newVal != progress else { return nil }
        
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
    
    func setState(_ newState : PositionAnimatorState) {
        progress = newState.rawValue
    }
    
    private var derivedCenter : CGPoint {
        return CGPoint(
            x: progress.blend(from: startCenter.x, to: endCenter.x),
            y: progress.blend(from: startCenter.y, to: endCenter.y)
        )
    }
    func update() {
        view.center = derivedCenter
    }
}

