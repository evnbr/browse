//
//  ProgressToolbar.swift
//  browse
//
//  Created by Evan Brooks on 7/12/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ProgressToolbar: ColorToolbarView {
    
    let progressView: UIProgressView = UIProgressView(progressViewStyle: .default)
    
    var progress : Float {
        get {
            return progressView.progress
        }
        set {
            progressView.alpha = 1.0
            let isIncreasing = progressView.progress < newValue
            
            progressView.setProgress(Float(newValue), animated: isIncreasing)
            if (newValue >= 1.0) {
                UIView.animate(withDuration: 0.3, delay: 0.3, options: .curveEaseOut, animations: {
                    self.progressView.progress = 1.0
                    self.progressView.alpha = 0
                }, completion: { (finished) in
                    self.progressView.setProgress(0.0, animated: false)
                })
            }
            
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: Const.toolbarHeight - 2),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.darkText
        progressView.autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
//        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        addSubview(progressView)
        sendSubview(toBack: progressView)
        
//        let blur = PlainBlurView(frame: bounds)
//        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        addSubview(blur)
//        sendSubview(toBack: blur)
        
    }
        
    override func tintColorDidChange() {
        super.tintColorDidChange()
        subviews.forEach { (v) in
            v.tintColor = tintColor
        }
//        progressView.progressTintColor = tintColor.isLight ? UIColor.black.withAlphaComponent(0.5) : UIColor.white
        progressView.progressTintColor = tintColor
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
