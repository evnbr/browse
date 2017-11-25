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
    var overlay : UIView!
    var browserTab : BrowserTab!
    var closeTabCallback : CloseTabCallback!
    
    var snapTopOffsetConstraint : NSLayoutConstraint!
    var snapAspectConstraint : NSLayoutConstraint!
    
    var snapView : UIImageView!
    
    var unTransformedFrame : CGRect!
    
    var darkness : CGFloat {
        get {
            return overlay.alpha
        }
        set {
            overlay.alpha = newValue
        }
    }
    
    override var frame : CGRect {
        didSet {
            if !isDismissing {
//                snap?.frame = frameForSnap(snap)
                overlay?.frame = bounds
                unTransformedFrame = frame
            }
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // there should be a way to do this with autolayout but couldn't figure it out
//        snap?.frame = frameForSnap(snap)
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
        
        layer.cornerRadius = Const.shared.thumbRadius 
        backgroundColor = .clear
        
//        layer.anchorPoint.y = 0
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
//        dismissPanner.cancelsTouchesInView = true
        addGestureRecognizer(dismissPanner)
        
        snapView = UIImageView(frame: bounds)
        snapView.contentMode = .scaleAspectFit
        snapView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(snapView)
        snapTopOffsetConstraint = snapView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: THUMB_OFFSET_COLLAPSED)
        snapTopOffsetConstraint.isActive = true
        snapView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
        snapView.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
        snapAspectConstraint = snapView.heightAnchor.constraint(equalTo: snapView.widthAnchor, multiplier: 1, constant: 0)
        snapAspectConstraint.isActive = true

        overlay = UIView(frame: bounds)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        overlay.alpha = 0
        contentView.addSubview(overlay)

        contentView.layer.cornerRadius = Const.shared.thumbRadius
        contentView.clipsToBounds = true

        
        label = UILabel(frame: CGRect(
            x: 16,
            y: 10,
            width: frame.width - 24,
            height: 16.0
        ))
        label.text = "Blank"
//        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: THUMB_TITLE)
        label.textColor = .darkText
        contentView.addSubview(label)
        contentView.backgroundColor = .white
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTab(_ newTab : BrowserTab) {
        browserTab = newTab
        
        if let img : UIImage = browserTab.history.current?.snapshot {
            setSnapshot(img)
        }
        
        if let color : UIColor = browserTab.topColorSample {
            contentView.backgroundColor = color
            overlay.backgroundColor = color.isLight ? .lightTouch : .darkTouch
            label.textColor = color.isLight ? .white : .darkText
        }
        
        if let title : String = browserTab.restorableTitle {
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
        unTransformedFrame = frame
        
        if touches.first != nil {
            self.overlay.alpha = 0.7
            UIView.animate(withDuration: 0.15, delay: 0.0, animations: {
                self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            })
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        unSelect()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        unSelect()
    }
    
    func unSelect(animated : Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
                self.transform = .identity
                self.overlay.alpha = 0
            })
        }
        else {            
            self.transform = .identity
            self.overlay.alpha = 0
        }
    }
    
//    func setSnapshot(_ newSnapshot : UIView) {
//        snap?.removeFromSuperview()
//
//        snap = newSnapshot
//        snap.frame = frameForSnap(snap)
//
//        contentView.addSubview(snap)
//        contentView.sendSubview(toBack: snap)
//    }
    
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
    var startFrame : CGRect = .zero
    
    @objc func panGestureChange(gesture: UIPanGestureRecognizer) {
        let gesturePos = gesture.translation(in: self)

        if gesture.state == .began {
            isDismissing = true
            startFrame = unTransformedFrame
        }
        else if gesture.state == .changed {
            if isDismissing {
                let pct = abs(gesturePos.x) / startFrame.width
                if pct > 0.7 {
                    alpha = 1 - (pct - 0.7) * 2
                }
                
                frame.origin.x = startFrame.origin.x + gesturePos.x
            }
        }
        else if gesture.state == .ended {

            if isDismissing {
                isDismissing = false
                
                let vel = gesture.velocity(in: superview)
                
                var endFrame : CGRect = startFrame
                var endAlpha : CGFloat = 1
                
                if ( vel.x > 800 || gesturePos.x > frame.width * 0.5 ) {
                    endFrame.origin.x = startFrame.origin.x + startFrame.width
                    endAlpha = 0
                    closeTabCallback(self)
                }
                else if ( vel.x < -800 || gesturePos.x < -frame.width * 0.5 ) {
                    endFrame.origin.x = startFrame.origin.x - frame.width
                    endAlpha = 0
                    closeTabCallback(self)
                }
                
                UIView.animate(withDuration: 0.6, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
                    self.frame = endFrame
                    self.alpha = endAlpha
                }, completion: nil)
            }
            
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        snapView.image = nil
        contentView.backgroundColor = .darkGray
        label.text = "Blank"
    }
    
    override func apply(_ layoutAttributes: UICollectionViewLayoutAttributes) {
        super.apply(layoutAttributes)
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


