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
    
    override var frame : CGRect {
        didSet {
            if !isDismissing {
//                snap?.frame = frameForSnap(snap)
                overlay?.frame = bounds
            }
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
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black
        overlay.alpha = 0

        contentView.layer.cornerRadius = Const.shared.thumbRadius
        contentView.clipsToBounds = true

        layer.shadowRadius = 24
        layer.shadowOpacity = 0.16
        
        label = UILabel(frame: CGRect(
            x: 24,
            y: 12,
            width: frame.width - 24,
            height: 16.0
        ))
        label.text = "Blank"
        label.font = Const.shared.thumbTitle
        label.textColor = .darkText
        
        contentView.addSubview(label)
        contentView.addSubview(overlay)
        contentView.backgroundColor = .white
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setTab(_ newTab : BrowserTab) {
        browserTab = newTab
        
        if let img : UIImage = browserTab.history.current?.snapshot {
            setSnapshot(img)
            label.isHidden = true
        }
        else {
            label.isHidden = false
        }
        
        if let color : UIColor = browserTab.topColorSample {
            contentView.backgroundColor = color
//            overlay.backgroundColor = color.isLight ? .lightTouch : .darkTouch
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
        
        if touches.first != nil {
//            self.overlay.alpha = 0.3
            UIView.animate(withDuration: 0.15, delay: 0.0, animations: {
                self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            })
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
//        unSelect()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        unSelect()
    }
    
    func unSelect(animated : Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
                self.transform = .identity
//                self.overlay.alpha = 0
            })
        }
        else {            
            self.transform = .identity
            self.overlay.alpha = 0
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
            overlay.backgroundColor = .red
        }
        else if gesture.state == .changed {
            if isDismissing {
                let pct = abs(gesturePos.x) / bounds.width
                if pct > 0.4 {
                    overlay.alpha = (pct - 0.4) * 2
                }
                
                let s = 1 - pct * 0.5
                transform = CGAffineTransform(scaleX: s, y: s)
                center.x = startCenter.x + elasticLimit(gesturePos.x)
                center.y = startCenter.y + blend(from: elasticLimit(gesturePos.y), to: gesturePos.y, by: pct * 0.5) * 0.6 - ((1 - s) * bounds.height * 0.3)
            }
        }
        else if gesture.state == .ended {

            if isDismissing {
                isDismissing = false
                
                let vel = gesture.velocity(in: superview)
                
                var endCenter : CGPoint = startCenter
                var endAlpha : CGFloat = startAlpha
                var endTransform : CGAffineTransform = .identity
                
                if ( vel.x > 1200 || gesturePos.x > bounds.width * 0.7 ) {
                    endCenter.x = startCenter.x + bounds.width
//                    endCenter.y = startCenter.y + bounds.height
                    endAlpha = 1
                    endTransform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    closeTabCallback(self)
                }
                else if ( vel.x < -1200 || gesturePos.x < -bounds.width * 0.7 ) {
                    endCenter.x = startCenter.x - bounds.width
//                    endCenter.y = startCenter.y + bounds.height
                    endAlpha = 1
                    endTransform = CGAffineTransform(scaleX: 0.1, y: 0.1)
                    closeTabCallback(self)
                }
                
                UIView.animate(withDuration: 0.6, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
                    self.center = endCenter
                    self.overlay.alpha = endAlpha
                    self.transform = endTransform
                    self.overlay.backgroundColor = .black
                }, completion: nil)
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


