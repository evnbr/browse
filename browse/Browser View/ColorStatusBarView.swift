//
//  ColorStatusBar.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class ColorStatusBarView: GradientColorChangeView {
    var blurView: UIVisualEffectView!
    var label: UILabel!

    init() {
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size: CGSize(width: UIScreen.main.bounds.size.width, height: Const.statusHeight)
        )

        super.init(frame: rect)
        initialHeight = Const.statusHeight
//        self.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        self.translatesAutoresizingMaskIntoConstraints = false

        let blur = PlainBlurView(frame: bounds)
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blur)
        sendSubview(toBack: blur)

        label = UILabel(frame: CGRect(
            x: 24 ,
            y: 12,
            width: frame.width - 48,
            height: 24
        ))
        label.text = "Blank"
        label.alpha = 0
        label.font = Const.thumbTitleFont
        label.textColor = .darkText
        label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        self.addSubview(label)
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
        label.textColor = tintColor
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
