//
//  VisitCell.swift
//  browse
//
//  Created by Evan Brooks on 4/15/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class VisitCell: UICollectionViewCell {
    var label : UILabel!
    var shadowView : UIView!
    var overlay : UIView!
    var closeTabCallback : CloseTabCallback!
    var toolbarView: BrowserToolbarView!
    var snapView : UIImageView!

    var snapTopOffsetConstraint : NSLayoutConstraint!
    var snapAspectConstraint : NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        radius = Const.shared.thumbRadius
        backgroundColor = .clear
                
        snapView = UIImageView(frame: bounds)
        snapView.contentMode = .scaleAspectFill
        snapView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(snapView)
        snapTopOffsetConstraint = snapView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: THUMB_OFFSET_COLLAPSED)
        snapTopOffsetConstraint.isActive = true
        snapView.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        snapView.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
        snapAspectConstraint = snapView.heightAnchor.constraint(equalTo: snapView.widthAnchor, multiplier: 1, constant: 0)
        snapAspectConstraint.isActive = true
        
        label = UILabel(frame: CGRect(x: 24, y: 12, width: frame.width - 48, height: 24))
        label.text = "Blank"
        label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        label.font = Const.shared.thumbTitle
        label.textColor = .darkText
        label.alpha = 1
        contentView.addSubview(label)
        
        toolbarView = BrowserToolbarView(frame: bounds)
        toolbarView.backButton.isHidden = true
        toolbarView.tabButton.isHidden = true
        toolbarView.backgroundColor = .red
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(toolbarView, constraints: [
            toolbarView.leftAnchor.constraint(equalTo: contentView.leftAnchor),
            toolbarView.rightAnchor.constraint(equalTo: contentView.rightAnchor),
            toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        
        overlay = UIView(frame: bounds.insetBy(dx: -60, dy: -60) )
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0
        contentView.addSubview(overlay)
        //        constrain4(contentView, overlay)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                
        shadowView = UIView(frame: bounds)
        shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shadowView.layer.shadowRadius = Const.shared.shadowRadius
        shadowView.layer.shadowOpacity = shadowAlpha
        shadowView.layer.shouldRasterize = true
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: Const.shared.thumbRadius)
        shadowView.layer.shadowPath = path.cgPath
        
        insertSubview(shadowView, belowSubview: contentView)
        
        contentView.backgroundColor = .black
        contentView.radius = Const.shared.thumbRadius
        contentView.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setVisit(_ visit : Visit) {
        if let img = visit.snapshot { setSnapshot(img) }
        if let color = visit.topColor {
            contentView.backgroundColor = color
            label.textColor = color.isLight ? .white : .darkText
        }
        toolbarView.backgroundColor = visit.bottomColor ?? .white

        if let title = visit.title, title != "" { label.text = "\(title)" }
        if let url = visit.url { toolbarView.text = url.displayHost }
    }
    
    func setSnapshot(_ newImage : UIImage) {
        let newAspect = newImage.size.height / newImage.size.width
        if newAspect != snapAspectConstraint.multiplier {
            snapView.removeConstraint(snapAspectConstraint)
            snapAspectConstraint = snapView.heightAnchor.constraint(equalTo: snapView.widthAnchor, multiplier: newAspect, constant: 0)
            snapAspectConstraint.isActive = true
        }
        snapView.image = newImage
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.15, delay: 0.0, animations: {
            self.select()
        })
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        unSelect()
    }
    
    func select() {
        self.contentView.scale = 0.96
    }
    
    func unSelect(animated : Bool = true) {
        if animated { UIView.animate(withDuration: 0.2) { self.reset() } }
        else { reset() }
    }
    
    func reset() {
        self.contentView.transform = .identity
        self.shadowView.scale = 1
        self.shadowView.layer.shadowRadius = Const.shared.shadowRadius
        self.shadowView.layer.shadowOpacity = shadowAlpha
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        alpha = 1
        overlay.alpha = 1 - layoutAttributes.alpha
        layer.zPosition = CGFloat(layoutAttributes.zIndex)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        snapView.image = nil
        contentView.backgroundColor = .white
        label.text = "Blank"
    }
}