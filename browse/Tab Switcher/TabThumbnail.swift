//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

typealias CloseTabCallback = (UICollectionViewCell) -> Void

class TabThumbnail: UICollectionViewCell, UIGestureRecognizerDelegate {
    
    var label : UILabel!
//    var snap : UIView!
    var shadowView : UIView!
    var overlay : UIView!
    var gradientOverlay : GradientView!
    var browserTab : BrowserTab!
    var closeTabCallback : CloseTabCallback!
    
    var snapTopOffsetConstraint : NSLayoutConstraint!
    var snapAspectConstraint : NSLayoutConstraint!
    
    var snapView : UIImageView!
    
    override var bounds: CGRect {
        didSet {
            overlay?.frame = contentView.bounds
            gradientOverlay?.frame = contentView.bounds
        }
    }
    
    var clipSnapFromBottom : Bool {
        get {
            return snapTopOffsetConstraint.constant < 0
        }
        set {
            snapTopOffsetConstraint.constant = newValue ? -400 : THUMB_OFFSET_COLLAPSED
        }
    }
    
    
    @available(iOS 11.0, *)
    override func dragStateDidChange(_ dragState: UICollectionViewCellDragState) {
        if dragState == .dragging {
            layer.borderColor = UIColor.red.cgColor
        }
        else if dragState == .none {
            layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        radius = Const.shared.thumbRadius 
        backgroundColor = .clear
        
//        contentView.translatesAutoresizingMaskIntoConstraints = false
        
//        layer.anchorPoint.y = 0
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
//        dismissPanner.cancelsTouchesInView = true
        addGestureRecognizer(dismissPanner)
        
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

        label = UILabel(frame: CGRect(
            x: 24,
            y: 15,
            width: frame.width - 48,
            height: 16.0
        ))
        label.text = "Blank"
        label.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        label.font = Const.shared.thumbTitle
        label.textColor = .darkText
        contentView.addSubview(label)
        
        overlay = UIView(frame: bounds)
        overlay.bounds.size.height += 20 // ????
        overlay.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0
        contentView.addSubview(overlay)

        gradientOverlay = GradientView(frame: bounds)
        gradientOverlay.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
//        contentView.addSubview(gradientOverlay)

        shadowView = UIView(frame: bounds)
        shadowView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shadowView.layer.shadowRadius = 32
        shadowView.layer.shadowOpacity = 0.2
        shadowView.layer.shouldRasterize = true
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: Const.shared.thumbRadius)
        shadowView.layer.shadowPath = path.cgPath
        
        insertSubview(shadowView, belowSubview: contentView)
        
        contentView.backgroundColor = .white
        contentView.radius = Const.shared.thumbRadius
        contentView.clipsToBounds = true
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTab(_ newTab : BrowserTab) {
        browserTab = newTab
        
        if let img : UIImage = browserTab.history.current?.snapshot {
            setSnapshot(img)
        }
        
        if let color : UIColor = browserTab.history.current?.topColor {
            contentView.backgroundColor = color
            label.textColor = color.isLight ? .white : .darkText
        }
        else if let color : UIColor = browserTab.restoredTopColor {
            contentView.backgroundColor = color
            label.textColor = color.isLight ? .white : .darkText
        }

        if let title : String = browserTab.restorableTitle, title != "" {
            label.text = "\(title)"
        }
        else if let title : String = browserTab.restoredTitle {
            label.text = "\(title)"
        }
    }
    
    
    // only recognize horizontals
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let translation = panGestureRecognizer.translation(in: superview!)
            if fabs(translation.x) > fabs(translation.y) {
                return true
            }
            return false
        }
        return false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if touches.first != nil {
            UIView.animate(withDuration: 0.15, delay: 0.0, animations: {
                self.contentView.scale = 0.97
                self.shadowView.scale = 0.97
            })
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        unSelect()
    }
    
    func unSelect(animated : Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
                self.contentView.scale = 1
                self.shadowView.scale = 1
            })
        }
        else {            
            self.contentView.scale = 1
            self.shadowView.scale = 1
        }
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
    
    var isDismissing = false
    var startCenter : CGPoint = .zero
    var startAlpha : CGFloat = 0
    
    @objc func panGestureChange(gesture: UIPanGestureRecognizer) {
        let gesturePos = gesture.translation(in: self.superview)

        if gesture.state == .began {
            isDismissing = true
            startCenter = center
            startAlpha = overlay.alpha
        }
        else if gesture.state == .changed {
            if isDismissing {
                let pct = abs(gesturePos.x) / bounds.width
                if pct > 0.4 {
                    overlay.alpha = (pct - 0.4) * 2
                }
                center.x = startCenter.x + elasticLimit(gesturePos.x)
            }
        }
        else if gesture.state == .ended {

            if isDismissing {
                isDismissing = false
                
                let vel = gesture.velocity(in: superview)
                
                var endCenter : CGPoint = startCenter
                var endAlpha : CGFloat = startAlpha
                
                if ( vel.x > 400 || gesturePos.x > bounds.width * 0.5 ) {
                    endCenter.x = startCenter.x + bounds.width
                    endAlpha = 1
                    closeTabCallback(self)
                }
                else if ( vel.x < -400 || gesturePos.x < -bounds.width * 0.5 ) {
                    endCenter.x = startCenter.x - bounds.width
                    endAlpha = 1
                    closeTabCallback(self)
                }
                
                springCenter(to: endCenter, at: vel)
                UIView.animate(withDuration: 0.4) {
                    self.overlay.alpha = endAlpha
                    self.overlay.backgroundColor = .black
                }
            }
            
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        snapView.image = nil
        contentView.backgroundColor = .white
        label.text = "Blank"
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
        alpha = 1
        overlay.alpha = 1 - layoutAttributes.alpha
        overlay.bounds = layoutAttributes.bounds
        layer.zPosition = CGFloat(layoutAttributes.zIndex)
    }
    
    func frameForSnap(_ snap : UIView) -> CGRect {
        let aspect = snap.frame.height / snap.frame.width
        return CGRect(
            x: 0,
            y: THUMB_OFFSET_COLLAPSED,
            width: frame.width,
            height: aspect * frame.width
        )
    }

}


