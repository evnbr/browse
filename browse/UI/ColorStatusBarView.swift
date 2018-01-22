//
//  ColorStatusBar.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class PlainBlurView : UIVisualEffectView {
    convenience init(frame: CGRect) {
        
        self.init(effect: UIBlurEffect(style: .light))
        self.frame = frame
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // TODO: gross workaround to not have lightening effect.
        // could be more robust, make sure if v is _UIVisualEffectFilterView
        for v in subviews {
            if v.backgroundColor != nil {
                v.backgroundColor = nil
            }
        }
    }
}

class ColorStatusBarView : GradientColorChangeView {
    var blurView : UIVisualEffectView!
    var label : UILabel!
    
    init() {
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height: Const.statusHeight)
        )

        super.init(frame: rect)
        
//        self.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        self.translatesAutoresizingMaskIntoConstraints = false
        
        let blur = PlainBlurView(frame: bounds)
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        sendSubview(toBack: blur)

//        label = UILabel(frame: CGRect(
//            x: 24 ,
//            y: 12,
//            width: frame.width - 24,
//            height: 16.0
//        ))
//        label.text = "Blank"
//        label.alpha = 0
//        label.font = Const.shared.thumbTitle
//        label.textColor = .darkText
//        self.addSubview(label)
    }
    
//    convenience init(color: UIColor) {
//        self.init()
//        self.backgroundColor = color
//    }
    
//    override func tintColorDidChange() {
//        super.tintColorDidChange()
//        label.textColor = tintColor
//    }

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}