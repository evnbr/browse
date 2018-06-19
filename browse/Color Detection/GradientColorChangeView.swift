//
//  GradientColorChangeView.swift
//  browse
//
//  Created by Evan Brooks on 8/23/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

enum GradientColorChangeDirection {
    case topToBottom
    case bottomToTop
}

class GradientColorChangeView: UIView, CAAnimationDelegate {
    let gradientLayer: CAGradientLayer = CAGradientLayer()
    let gradientLayer2: CAGradientLayer = CAGradientLayer()
    let gradientLayer3: CAGradientLayer = CAGradientLayer()

    let duration: CFTimeInterval = 0.2//0.3

    var backgroundView: UIView!

    private var lastColor: UIColor = UIColor.clear

    override var backgroundColor: UIColor! {
        get { return lastColor }
        set {
            if let color = newValue {
                setBackground(to: color)
            } else {
                lastColor = .clear
            }
        }
    }

    var isLight: Bool {
        return lastColor.isLight
    }

    var initialHeight = Const.toolbarHeight

    override func layoutSubviews() {
        super.layoutSubviews()

        var newFrame = bounds
        newFrame.size.height = initialHeight

        gradientLayer.frame = newFrame
        gradientLayer2.frame = newFrame
        gradientLayer3.frame = newFrame
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundView = UIView(frame: bounds)
        backgroundView.clipsToBounds = true
//        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundView)
        sendSubview(toBack: backgroundView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.topAnchor.constraint(equalTo: topAnchor).isActive = true
        backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        backgroundView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        backgroundView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true

        for layer in [gradientLayer, gradientLayer2, gradientLayer3] {
            layer.frame = bounds
            layer.colors = [UIColor.clear.cgColor, UIColor.clear.cgColor]
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func cancelColorChange() {
        backgroundView.layer.sublayers?.forEach {
            $0.removeFromSuperlayer()
            $0.removeAllAnimations()
        }
        backgroundView.backgroundColor = lastColor
    }

    func getGradientLayer() -> CAGradientLayer {
        if gradientLayer.superlayer == nil {
            return gradientLayer
        } else if gradientLayer2.superlayer == nil {
            return gradientLayer2
        } else if gradientLayer3.superlayer == nil {
            return gradientLayer3
        } else {
            let newLayer = CAGradientLayer()
            newLayer.frame = bounds
            newLayer.frame.size.height = initialHeight
            return newLayer
        }
    }

    func animateGradientNew(toColor: UIColor, direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }

        UIView.animate(withDuration: 0.5, delay: 0, options: .beginFromCurrentState, animations: {
            self.backgroundView.backgroundColor = toColor
            self.tintColor = toColor.isLight ? .white : .darkText
        })
        lastColor = toColor
        return true
    }

    private func setBackground(to newColor: UIColor) {
        cancelColorChange()
        self.backgroundView.backgroundColor = newColor
        self.tintColor = newColor.isLight ? .white : .darkText
        lastColor = newColor
    }

    @discardableResult
    func transitionBackground(to toColor: UIColor, from direction: GradientColorChangeDirection ) -> Bool {
        if toColor.isEqual(lastColor) { return false }

        let gLayer = getGradientLayer()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        var endLoc: [NSNumber]
        var beginLoc: [NSNumber]
        if direction == .topToBottom {
            gLayer.colors = [
                toColor.cgColor,
                toColor.withAlphaComponent(0).cgColor
            ]
            beginLoc = [-2, 0]
            endLoc = [1, 5]
//            beginLoc = [0, 0.05]
//            endLoc = [1, 1.05]
        } else {
            gLayer.colors = [
                toColor.withAlphaComponent(0).cgColor,
                toColor.cgColor
            ]
            beginLoc = [1, 3]
            endLoc = [-4, 0]
//            beginLoc = [0.95, 1]
//            endLoc = [-0.05, 0]
        }
        gLayer.locations = beginLoc
        lastColor = toColor

        let colorChangeAnimation = CABasicAnimation(keyPath: "locations")
        colorChangeAnimation.duration = duration
        colorChangeAnimation.fromValue = beginLoc
        colorChangeAnimation.toValue = endLoc
//        colorChangeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        colorChangeAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
        colorChangeAnimation.fillMode = kCAFillModeForwards
        colorChangeAnimation.isRemovedOnCompletion = false
//        colorChangeAnimation.delegate = self

        CATransaction.setCompletionBlock({ [weak self] in
            self?.backgroundView.backgroundColor = toColor
            gLayer.removeAnimation(forKey: "gradientChange")
            gLayer.removeFromSuperlayer()
        })
        gLayer.add(colorChangeAnimation, forKey: "gradientChange")
        backgroundView.layer.addSublayer(gLayer)
        CATransaction.commit()

        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseInOut, animations: {
            self.tintColor = toColor.isLight ? .white : .darkText
        }, completion: nil)

        return true
    }

}
