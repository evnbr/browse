//
//  GradientColorChangeView.swift
//  browse
//
//  Created by Evan Brooks on 8/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

enum GradientColorChangeDirection {
    case fromTop
    case fromBottom
}


class GradientColorChangeView: UIView, CAAnimationDelegate {
    
    let gradientLayer: CAGradientLayer = CAGradientLayer()
    let gradientLayer2: CAGradientLayer = CAGradientLayer()
    let gradientLayer3: CAGradientLayer = CAGradientLayer()
    
    let duration : CFTimeInterval = 1.2

    var gradientHolder: UIView!
    
    var lastColor: UIColor = UIColor.clear
    
    var isLight : Bool {
        return lastColor.isLight
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        gradientLayer2.frame = bounds
        gradientLayer3.frame = bounds
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        gradientHolder = UIView(frame: bounds)
//        gradientHolder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gradientHolder)
        sendSubview(toBack: gradientHolder)
        
        gradientHolder.translatesAutoresizingMaskIntoConstraints = false
        gradientHolder.topAnchor.constraint(equalTo: topAnchor).isActive = true
        gradientHolder.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        gradientHolder.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        gradientHolder.rightAnchor.constraint(equalTo: rightAnchor).isActive = true

        for layer in [gradientLayer, gradientLayer2, gradientLayer3] {
            layer.frame = bounds
            layer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cancelColorChange() {
        gradientLayer.removeAllAnimations()
        gradientLayer2.removeAllAnimations()
        gradientLayer3.removeAllAnimations()
    }
    
    func getGradientLayer() -> CAGradientLayer? {
        if gradientLayer.superlayer == nil {
            return gradientLayer
        }
        else if gradientLayer2.superlayer == nil  {
            return gradientLayer2
        }
        else if gradientLayer3.superlayer == nil  {
            return gradientLayer3
        }
        else {
            let newLayer = CAGradientLayer()
            newLayer.frame = bounds
            return newLayer
        }
    }
    
    func animateGradient(toColor: UIColor, direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }

        UIView.animate(withDuration: 1.5, delay: 0, options: .beginFromCurrentState, animations: {
            self.gradientHolder.backgroundColor = toColor
            self.tintColor = toColor.isLight ? .white : .darkText
        })
        
        return true
    }

    
    func animateGradientOld(toColor: UIColor, direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }
        
        guard let gLayer : CAGradientLayer = getGradientLayer() else {
            print("all grads in use")
            return false
        }
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var endLoc: [NSNumber]
        var beginLoc: [NSNumber]
        if direction == .fromTop {
            gLayer.colors = [
                toColor.cgColor,
                toColor.withAlphaComponent(0).cgColor
            ]
            beginLoc = [-2, 0]
            endLoc = [1, 3]
//            beginLoc = [0, 0.05]
//            endLoc = [1, 1.05]
        } else {
            gLayer.colors = [
                toColor.withAlphaComponent(0).cgColor,
                toColor.cgColor
            ]
            beginLoc = [1, 3]
            endLoc = [-2, 0]
//            beginLoc = [0.95, 1]
//            endLoc = [-0.05, 0]
        }
        gLayer.locations = beginLoc
        lastColor = toColor

        
        let colorChangeAnimation = CABasicAnimation(keyPath: "locations")
        colorChangeAnimation.duration = duration
        colorChangeAnimation.fromValue = beginLoc
        colorChangeAnimation.toValue = endLoc
        colorChangeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        colorChangeAnimation.fillMode = kCAFillModeForwards
        colorChangeAnimation.isRemovedOnCompletion = false
//        colorChangeAnimation.delegate = self
        
        
        CATransaction.setCompletionBlock({
            self.gradientHolder.backgroundColor = toColor
            gLayer.removeAnimation(forKey: "gradientChange")
            gLayer.removeFromSuperlayer()
        })
        gLayer.add(colorChangeAnimation, forKey: "gradientChange")
        gradientHolder.layer.addSublayer(gLayer)

        CATransaction.commit()
        
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseInOut, animations: {
//            self.backgroundColor = toColor
            self.tintColor = toColor.isLight ? .white : .darkText
        }, completion: nil)
        
        return true
    }
    

}
