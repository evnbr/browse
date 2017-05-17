//
//  ColorStatusBar.swift
//  browse
//
//  Created by Evan Brooks on 5/17/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import UIKit

class ColorStatusBar : UIView {
    var inner : UIView!
    var back : UIView!
    
    init() {
        let rect = CGRect(
            origin: CGPoint(x: 0, y: 0),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:20)
        )

        super.init(frame: rect)
        
        self.autoresizingMask = [.flexibleWidth]
        self.backgroundColor = UIColor.black
        
        back = UIView.init(frame: rect)
        back.autoresizingMask = [.flexibleWidth]
        back.backgroundColor = UIColor.black
        self.addSubview(back)
        
        //        statusBar.backgroundColor = UIColor.clear
        //        statusBack.alpha = 0.8
        //        webView.scrollView.layer.masksToBounds = false
        //        let blurEffect = UIBlurEffect(style: UIBlurEffectStyle.light)
        //        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        //        blurEffectView.frame = statusBack.bounds
        //        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        //        statusBar.addSubview(blurEffectView)
        
        inner = UIView()
        inner.frame = back.bounds
        inner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inner.backgroundColor = .red
        back.addSubview(inner)
        back.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
