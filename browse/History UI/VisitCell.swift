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
    var toolbarView: BrowserToolbarView!
    var snapView : UIImageView!
    
    var connector: UIView!
    let connectorLayer = CAShapeLayer()

    var snapTopOffsetConstraint : NSLayoutConstraint!
    var snapAspectConstraint : NSLayoutConstraint!
    var connecterWidth: NSLayoutConstraint!
    var connectorHeight: NSLayoutConstraint!

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
        label.font = Const.shared.thumbTitleFont
        label.textColor = .darkText
        label.alpha = 1
        contentView.addSubview(label)
        
        toolbarView = BrowserToolbarView(frame: bounds)
        toolbarView.backButton.isHidden = true
        toolbarView.tabButton.isHidden = true
        toolbarView.backgroundColor = .red
        toolbarView.isUserInteractionEnabled = false
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
//        shadowView.layer.shouldRasterize = true
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: Const.shared.thumbRadius)
        shadowView.layer.shadowPath = path.cgPath
        
        insertSubview(shadowView, belowSubview: contentView)
        
        contentView.backgroundColor = .white
        contentView.radius = Const.shared.thumbRadius
        contentView.clipsToBounds = true
        
        
        connector = UIView()
        connector.translatesAutoresizingMaskIntoConstraints = false
        
        connectorLayer.lineWidth = 4
        connectorLayer.strokeColor = UIColor.white.cgColor
        connectorLayer.fillColor = nil
        connector.layer.addSublayer(connectorLayer)

        insertSubview(connector, belowSubview: contentView)
        connector.rightAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
        connector.bottomAnchor.constraint(equalTo: contentView.centerYAnchor, constant: 4).isActive = true
        
        connecterWidth = connector.widthAnchor.constraint(equalToConstant: 20)
        connectorHeight = connector.heightAnchor.constraint(equalToConstant: 20)
        connecterWidth.isActive = true
        connectorHeight.isActive = true
    }
    
    func setConnector(size: CGSize) {
        guard size != .zero else { return }
        let absSize = CGSize(width: abs(size.width), height: abs(size.height))
        
        let connectorPath = UIBezierPath()
        connectorPath.move(to: CGPoint(x:0, y: 0))
//        connectorPath.addLine(to: CGPoint(x: size.width, y: absSize.height))
        if absSize.width > 140 {
            connectorPath.addCurve(
                to: CGPoint(x: size.width, y: absSize.height),
                controlPoint1: CGPoint(x: size.width * 0.2, y: 0),
                controlPoint2: CGPoint(x: size.width * 0.8, y: -size.width / 2)
            )
        } else {
            connectorPath.addLine(to: CGPoint(x: size.width, y: absSize.height))
        }
//        connectorPath.addCurve(
//            to: CGPoint(x: size.width, y: absSize.height),
//            controlPoint1: CGPoint(x: size.width * 0.7, y: 0),
//            controlPoint2: CGPoint(x: size.width * 0.3, y: absSize.height)
//        )

        if size.height > 0 {
            connector.transform = .identity
        }
        else {
            connector.transform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -absSize.height)
        }
        
        connectorLayer.frame.origin = .zero
        connectorLayer.frame.size = absSize
        connectorLayer.path = connectorPath.cgPath

        connecterWidth.constant = absSize.width
        connectorHeight.constant = absSize.height
        connector.layoutIfNeeded()
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
        
        isTappable = !(visit.tab?.isClosed ?? false)
    }
    
    func setSnapshot(_ newImage : UIImage) {
        let newAspect = newImage.size.height / newImage.size.width
        if (abs(newAspect - snapAspectConstraint.multiplier) > 0.001) {
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
    
    var hasBorder : Bool {
        get {
            return contentView.layer.borderWidth > 0
        }
        set {
            contentView.layer.borderColor = newValue ? UIColor.yellow.cgColor : nil
            contentView.layer.borderWidth = newValue ? 8 : 0
        }
    }
    
    var isTappable : Bool {
        get {
            return contentView.alpha == 1
        }
        set {
            contentView.alpha = newValue ? 1 : 0.5
            connector.alpha = newValue ? 1 : 0.5
        }
    }

    
    func reset() {
        self.contentView.transform = .identity
        self.shadowView.scale = 1
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        alpha = 1
        overlay.alpha = 1 - layoutAttributes.alpha
//        layer.zPosition = CGFloat(layoutAttributes.zIndex)
        
        if let treeAttrs = layoutAttributes as? TreeConnectorAttributes,
            let connectorOffset = treeAttrs.connectorOffset {
            connector.isHidden = false
            connectorLayer.strokeColor = UIColor.white.cgColor
            setConnector(size: connectorOffset)
        } else {
            connector.isHidden = true
        }
        
        let s = layoutAttributes.transform.xScale * 0.9
        var tf = CATransform3DIdentity
        tf.m34 = 1.0 / -4000.0
        let rotated = CATransform3DRotate(tf, CGFloat.pi * -0.3, 1.0, 0.0, 0.0)
        let scaled = CATransform3DScale(rotated, s, s, s)
//        layer.transform = scaled
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        reset()
        snapView.image = nil
        contentView.backgroundColor = .white
        label.text = ""
    }
}
