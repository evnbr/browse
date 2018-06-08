//
//  GradientView.swift
//  browse
//
//  Created by Evan Brooks on 1/21/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//


// TODO: look into this implementation instead
// https://medium.com/@marcosantadev/calayer-and-auto-layout-with-swift-21b2d2b8b9d1


import UIKit

class GradientView: UIView {
    private let gradientLayer = CAGradientLayer()
    
    override var frame: CGRect {
        didSet { resizeGradient() }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        resizeGradient()
    }
    
    func resizeGradient() {
//        CATransaction.begin()
//        CATransaction.disableActions()
        gradientLayer.frame = bounds
        gradientLayer.frame.size.width *= 1.3 // TODO: Why does this not track correctly?
//        gradientLayer.frame.size.height = THUMB_H * 1.5
//        CATransaction.commit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [ UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.4).cgColor ]
        gradientLayer.locations = [ 0.0, 1.0 ]
        resizeGradient()
        layer.addSublayer(gradientLayer)
        translatesAutoresizingMaskIntoConstraints = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
