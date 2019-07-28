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
//        addSubview(blur)
//        sendSubview(toBack: blur)
    }

    override func tintColorDidChange() {
        super.tintColorDidChange()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
