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
        imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Const.toolbarHeight).isActive = true
        imageView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true

        overlay = UIView(frame: bounds)
        overlay.backgroundColor = .black
        overlay.alpha = 0
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(overlay)
    }
    
    func setPage(_ page: HistoryItem) {
        imageView.image = page.snapshot
        statusView.backgroundColor = page.topColor
        toolbarView.backgroundColor = page.bottomColor
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
