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
    var progressView: UIProgressView!

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
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
        
//        addSubview(back)
        sendSubview(toBack: back)
        
        blurView = UIVisualEffectView(frame: self.bounds, isTransparent: true)
        addSubview(blurView)
        sendSubview(toBack: blurView)
        
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.lightOverlay
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        addSubview(progressView)

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
