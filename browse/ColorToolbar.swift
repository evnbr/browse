//
//  ColorToolbar.swift
//  browse
//
//  Created by Evan Brooks on 6/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ColorToolbar: UIToolbar {
    var inner : UIView!
    var back : UIView!
    var blurView : UIVisualEffectView!

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

    override init(frame: CGRect) {
        super.init(frame: frame)
        //        navigationController?.isToolbarHidden = false
        isTranslucent = true
        
        barTintColor = .black
        tintColor = .white
        clipsToBounds = true

        setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
        
        autoresizingMask = [.flexibleTopMargin, .flexibleWidth]

        
        inner = UIView()
        inner.frame = self.bounds
        inner.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inner.backgroundColor = .black
        
        //        toolbar.addSubview(toolbarInner)
        //        toolbar.sendSubview(toBack: toolbarInner)
        
        back = UIView()
        back.frame = self.bounds
        back.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        back.backgroundColor = .black
        
        //        toolbarBack.alpha = 0.7
        
        addSubview(back)
        sendSubview(toBack: back)
        
        blurView = UIVisualEffectView(frame: self.bounds, isTransparent: true)
        addSubview(blurView)
        sendSubview(toBack: blurView)
        

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
