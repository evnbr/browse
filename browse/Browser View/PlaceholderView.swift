//
//  PlaceholderView.swift
//  browse
//
//  Created by Evan Brooks on 12/29/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class PlaceholderView: UIView {
    var contentView: UIView!
    var statusBar: ColorStatusBarView!
    var toolbarView: BrowserToolbarView!
    var overlay: UIView!
    var imageView: UIImageView!
    var aspectConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .black
        clipsToBounds = false

        radius = Const.cardRadius
        layer.shadowRadius = Const.shadowRadius
        layer.shadowOpacity = 0.16
        
        contentView = UIView(frame: bounds)
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.clipsToBounds = true
        contentView.layer.cornerRadius = Const.cardRadius
        addSubview(contentView)

        setupToolbar()
        setupStatusbar()

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

        overlay = UIView(frame: bounds.insetBy(dx: -20, dy: -20) ) // inset since the exact same size flickers
        overlay.backgroundColor = .black
        overlay.alpha = 0
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(overlay)
    }

    func setupStatusbar() {
        statusBar = ColorStatusBarView()
        statusBar.backgroundColor = .red
        contentView.addSubview(statusBar, constraints: [
            statusBar.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            statusBar.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            statusBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: Const.statusHeight)
        ])
    }

    func setupToolbar() {
        toolbarView = BrowserToolbarView(frame: bounds)
        toolbarView.backgroundColor = .red
        toolbarView.backButton.isHidden = true
        toolbarView.tabButton.isHidden = true
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarView, constraints: [
            toolbarView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            toolbarView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func setVisit(_ page: Visit) {
        layer.shadowOpacity = 0.16

        setSnapshot(page.snapshot)
        if let color = page.topColor { statusBar.backgroundColor = color }
        if let color = page.bottomColor { toolbarView.backgroundColor = color }
        statusBar.label.text = page.title
        toolbarView.text = page.url?.displayHost
    }

    func setSnapshot(_ image: UIImage?) {
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
