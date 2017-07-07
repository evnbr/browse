//
//  ColorToolbar.swift
//  browse
//
//  Created by Evan Brooks on 6/13/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class ColorToolbar: UIView {
    let progressView: UIProgressView = UIProgressView(progressViewStyle: .default)
    let stackView   = UIStackView()
    
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
        
        backgroundColor = .clear
        tintColor = .white
        clipsToBounds = true
        
        autoresizingMask = [.flexibleTopMargin, .flexibleWidth]
//        translatesAutoresizingMaskIntoConstraints = false
        
        
        
        progressView.frame = CGRect(
            origin: CGPoint(x: 0, y: 21),
            size:CGSize(width: UIScreen.main.bounds.size.width, height:4)
        )
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0)
        progressView.progressTintColor = UIColor.lightOverlay
        progressView.transform = progressView.transform.scaledBy(x: 1, y: 22)
        addSubview(progressView)
        
        stackView.axis  = .horizontal
        stackView.distribution  = .fill
        stackView.alignment = .center
        stackView.spacing   = 6.0
        
//        stackView.addArrangedSubview(spinner)
//        stackView.addArrangedSubview(lock)
//        stackView.addArrangedSubview(magnify)
//        stackView.addArrangedSubview(label)
        stackView.translatesAutoresizingMaskIntoConstraints = false;
        
        addSubview(stackView)
        stackView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
//        stackView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: self.topAnchor).isActive = true
        stackView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
    }
    
    func setItems(_ items : [UIView]) {
        for item in items {
            stackView.addArrangedSubview(item)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
