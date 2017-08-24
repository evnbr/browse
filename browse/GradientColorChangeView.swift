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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        gradientLayer.frame = self.bounds
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        
        let gradientView = UIView(frame: self.bounds)
        gradientView.layer.addSublayer(gradientLayer)
        self.addSubview(gradientView)
        sendSubview(toBack: gradientView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var isColorChanging: Bool = false
    var lastColor: UIColor = UIColor.clear
    
    func animateNewColor(
        toColor: UIColor,
        duration: CFTimeInterval,
        direction: GradientColorChangeDirection ) {
        
        guard !isColorChanging else {
            print("still changing")
            return
        }
        guard !toColor.isEqual(lastColor) else {
            print("color is the same")
            return
        }
        
        isColorChanging = true
        
        var endLoc: [NSNumber]
        if direction == .fromTop {
            gradientLayer.colors = [toColor.cgColor, toColor.withAlphaComponent(0).cgColor]
            gradientLayer.locations = [0, 0.05]
            endLoc = [0.2, 10]
        } else {
            gradientLayer.colors = [toColor.withAlphaComponent(0).cgColor, toColor.cgColor]
            gradientLayer.locations = [0.95, 1]
            endLoc = [-10, 0.8]
        }
        
        lastColor = toColor
        
        
        let colorChangeAnimation = CABasicAnimation(keyPath: "locations")
        colorChangeAnimation.duration = duration
        colorChangeAnimation.toValue = endLoc
        colorChangeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        colorChangeAnimation.fillMode = kCAFillModeForwards
        colorChangeAnimation.isRemovedOnCompletion = false
        colorChangeAnimation.delegate = self
        
        gradientLayer.isHidden = false
        gradientLayer.add(colorChangeAnimation, forKey: "boundsChange")
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseInOut, animations: {
            self.tintColor = toColor.isLight ? .white : .darkText
        }, completion: nil)
        
    }
    
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        if !flag {
            print("never completed")
        }
        backgroundColor = lastColor
        gradientLayer.removeAnimation(forKey: "boundsChange")
        gradientLayer.isHidden = true
        isColorChanging = false
    }
    

}
