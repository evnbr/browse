//
//  PlaceholderView.swift
//  browse
//
//  Created by Evan Brooks on 12/29/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class PlaceholderView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var contentView: UIView!
    var statusView: UIView!
    var toolbarView: UIView!
    var overlay: UIView!
    var imageView: UIImageView!
    var aspectConstraint : NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .white
        clipsToBounds = false

        radius = Const.shared.cardRadius
        layer.shadowRadius = 32
        layer.shadowOpacity = 0.16
        
        contentView = UIView(frame: bounds)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = Const.shared.cardRadius
        addSubview(contentView)
        
        statusView = UIView(frame: CGRect(x: 0, y: 0, width: bounds.width, height: Const.statusHeight))
        statusView.backgroundColor = .red
        contentView.addSubview(statusView)
        
        toolbarView = UIView(frame: CGRect(x: 0, y: bounds.height - Const.toolbarHeight, width: bounds.width, height: Const.toolbarHeight))
        toolbarView.backgroundColor = .red
        toolbarView.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        contentView.addSubview(toolbarView)

        
        imageView = UIImageView(frame: bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)
        
        imageView.topAnchor.constraint(equalTo: topAnchor, constant: Const.statusHeight).isActive = true
        imageView.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
        imageView.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
        
        aspectConstraint = imageView.heightAnchor.constraint(
            equalTo: imageView.widthAnchor,
            multiplier: 1,
            constant: 0)
        aspectConstraint.isActive = true
        
        overlay = UIView(frame: bounds)
        overlay.backgroundColor = .black
        overlay.alpha = 0
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(overlay)
    }
    
    func setPage(_ page: HistoryItem) {
        setSnapshot(page.snapshot)
        statusView.backgroundColor = page.topColor
        toolbarView.backgroundColor = page.bottomColor
    }
    
    func setSnapshot(_ image : UIImage?) {
        guard let image = image else { return }
        imageView.image = image
        
        let newAspect = image.size.height / image.size.width
        if newAspect != self.aspectConstraint.multiplier {
            imageView.removeConstraint(aspectConstraint)
            aspectConstraint = imageView.heightAnchor.constraint(
                equalTo: imageView.widthAnchor,
                multiplier: newAspect,
                constant: 0)
            aspectConstraint.isActive = true
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
