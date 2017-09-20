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
    
    var gradientView: UIView!
    var gradientView2: UIView!
    var gradientView3: UIView!
    
    var gradientHolder: UIView!
    
    var isColorChanging: Bool = false
    var lastColor: UIColor = UIColor.clear
    
    var isLight : Bool {
        return lastColor.isLight
    }
    
    override var frame : CGRect {
        didSet {
            gradientLayer.frame = self.bounds
        }
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        gradientHolder = UIView(frame: self.bounds)
        gradientHolder.autoresizingMask = [ .flexibleWidth, .flexibleHeight ]
        addSubview(gradientHolder)
        sendSubview(toBack: gradientHolder)
        
        for layer in [gradientLayer, gradientLayer2, gradientLayer3] {
            layer.frame = self.bounds
            layer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        }
        
        gradientView = UIView(frame: self.bounds)
        gradientView2 = UIView(frame: self.bounds)
        gradientView3 = UIView(frame: self.bounds)
        gradientView.layer.addSublayer(gradientLayer)
        gradientView2.layer.addSublayer(gradientLayer2)
        gradientView3.layer.addSublayer(gradientLayer3)
        
        for view in [gradientView, gradientView2, gradientView3] {
            view?.isHidden = true
            view?.autoresizingMask  = [ .flexibleWidth, .flexibleHeight ]
            gradientHolder.addSubview(view!)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func animateGradient(
        toColor: UIColor,
        duration: CFTimeInterval,
        direction: GradientColorChangeDirection ) -> Bool {
        
        guard !isColorChanging else {
            return false
        }
        guard !toColor.isEqual(lastColor) else {
            return false
        }
        
        var gLayer : CAGradientLayer
        var gView : UIView
        if gradientView.isHidden {
            print("using v1")
            gLayer = gradientLayer
            gView = gradientView!
        }
        else if gradientView2.isHidden {
            print("using v2")
            gLayer = gradientLayer2
            gView = gradientView2!
        }
        else if gradientView3.isHidden {
            print("using v3")
            gLayer = gradientLayer3
            gView = gradientView3!
        }
        else {
            print("all grads in use")
            return false
        }
        
        
        var endLoc: [NSNumber]
        if direction == .fromTop {
            gLayer.colors = [
                toColor.cgColor,
                toColor.withAlphaComponent(0.5).cgColor,
                toColor.withAlphaComponent(0).cgColor
            ]
            gLayer.locations = [0, 0.02, 0.05]
            endLoc = [0.2, 5, 20]
        } else {
            gLayer.colors = [
                toColor.withAlphaComponent(0).cgColor,
                toColor.withAlphaComponent(0.5).cgColor,
                toColor.cgColor
            ]
            gLayer.locations = [0.95, 0.98, 1]
            endLoc = [-20, -5, 0.8]
        }
        
        lastColor = toColor
        
        CATransaction.begin()
        CATransaction.setCompletionBlock({
            self.backgroundColor = self.lastColor
            gView.isHidden = true
            gLayer.removeAnimation(forKey: "boundsChange")
        })
        
        let colorChangeAnimation = CABasicAnimation(keyPath: "locations")
        colorChangeAnimation.duration = duration
        colorChangeAnimation.toValue = endLoc
        colorChangeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        colorChangeAnimation.fillMode = kCAFillModeForwards
        colorChangeAnimation.isRemovedOnCompletion = false
//        colorChangeAnimation.delegate = self
        
        gradientHolder.bringSubview(toFront: gView)
        gView.isHidden = false
        
        gLayer.add(colorChangeAnimation, forKey: "boundsChange")
        CATransaction.commit()
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
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
