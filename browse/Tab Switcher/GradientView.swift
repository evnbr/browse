//
//  GradientView.swift
//  browse
//
//  Created by Evan Brooks on 1/21/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

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
        gradientLayer.frame = bounds
        gradientLayer.frame.size.height = THUMB_H * 1.5
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        gradientLayer.colors = [ UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.cgColor ]
        gradientLayer.locations = [ 0.0, 1.0 ]
        resizeGradient()
        layer.addSublayer(gradientLayer)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
