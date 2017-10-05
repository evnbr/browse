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
    
    var gradientHolder: UIView!
    
    var lastColor: UIColor = UIColor.clear
    
    var isLight : Bool {
        return lastColor.isLight
    }
    
    override var frame : CGRect {
        didSet {
            gradientLayer.frame = self.bounds
            gradientLayer2.frame = self.bounds
            gradientLayer3.frame = self.bounds
        }
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        gradientHolder = UIView(frame: self.bounds)
        gradientHolder.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
        addSubview(gradientHolder)
        sendSubview(toBack: gradientHolder)
        
        gradientHolder.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        gradientHolder.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        gradientHolder.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        
        
        for layer in [gradientLayer, gradientLayer2, gradientLayer3] {
            layer.frame = self.bounds
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
    
    func animateGradient(
        toColor: UIColor,
        duration: CFTimeInterval,
        direction: GradientColorChangeDirection ) -> Bool {
        
        guard !toColor.isEqual(lastColor) else {
            return false
        }
        
        var gLayer : CAGradientLayer
        if gradientLayer.superlayer == nil {
            gLayer = gradientLayer
        }
        else if gradientLayer2.superlayer == nil  {
            gLayer = gradientLayer2
        }
        else if gradientLayer3.superlayer == nil  {
            gLayer = gradientLayer3
        }
        else {
            print("all grads in use")
            return false
        }
//        let gLayer = CAGradientLayer()
//        gLayer.frame = self.bounds
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var endLoc: [NSNumber]
        var beginLoc: [NSNumber]
        if direction == .fromTop {
            gLayer.colors = [
                toColor.cgColor,
                toColor.withAlphaComponent(0).cgColor
            ]
            beginLoc = [0, 0.05]
            endLoc = [1, 5]
        } else {
            gLayer.colors = [
                toColor.withAlphaComponent(0).cgColor,
                toColor.cgColor
            ]
            beginLoc = [0.95, 1]
            endLoc = [-5, 0]
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
            self.backgroundColor = toColor
            gLayer.removeAnimation(forKey: "gradientChange")
            gLayer.removeFromSuperlayer()
        })
//        gLayer.add(colorChangeAnimation, forKey: "gradientChange")
//        gradientHolder.layer.addSublayer(gLayer)

        CATransaction.commit()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
            self.backgroundColor = toColor
            self.tintColor = toColor.isLight ? .white : .darkText
        }, completion: nil)
        
        return true
    }
    
//    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
//        if !flag {
//            print("never completed")
//        }
//        backgroundColor = lastColor
//
//        gradientLayer.removeAnimation(forKey: "boundsChange")
//        gradientLayer.isHidden = true
//
//        isColorChanging = false
//    }
    

}
