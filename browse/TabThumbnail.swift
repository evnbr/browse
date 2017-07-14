//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

typealias CloseTabCallback = (UICollectionViewCell) -> Void
let THUMB_OFFSET_COLLAPSED : CGFloat = 0.0 // 28.0

class TabThumbnail: UICollectionViewCell, UIGestureRecognizerDelegate {
    
    var label : UILabel!
    var snap : UIView!
    var overlay : UIView!
    var webVC : WebViewController!
    var closeTabCallback : CloseTabCallback!
    
    var unTransformedFrame : CGRect!
    
    private var _isExpanded : Bool = false
    var isExpanded : Bool {
        get {
            return snap.frame.origin.y != 0
        }
        set {
            _isExpanded = newValue
//            snap?.frame.origin.y = newValue ? 0 : -STATUS_H
//            snap?.frame.origin.y = newValue ? STATUS_H : 0
            label?.alpha = newValue ? 0 : 1
            snap?.frame = frameForSnap(snap)
            layer.borderWidth = newValue ? 0.0 : 1.0
        }
    }
    
    
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
                snap?.frame = frameForSnap(snap)
                unTransformedFrame = frame
            }
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // there should be a way to do this with autolayout but couldn't figure it out
        snap?.frame = frameForSnap(snap)
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
        
        layer.cornerRadius = THUMB_RADIUS
        backgroundColor = .clear
        clipsToBounds = true
        
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
        isExpanded = false
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
//        dismissPanner.cancelsTouchesInView = true
        addGestureRecognizer(dismissPanner)
        
        overlay = UIView(frame: frame)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = .red
        overlay.alpha = 0
        
        contentView.addSubview(overlay)
        
        label = UILabel(frame: CGRect(
            x: 12,
            y: 10,
            width: frame.width - 24,
            height: 16.0
        ))
        label.text = "Blank"
        label.alpha = 0.5
//        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 15.0)
        label.textColor = .darkText
        contentView.addSubview(label)
        contentView.backgroundColor = .darkGray
    }
        
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setWeb(_ newWebVC : WebViewController) {
        webVC = newWebVC
        
        if let snap : UIView = webVC.webSnapshot {
            label.isHidden = true
            setSnapshot(snap)
        }
        
        contentView.backgroundColor = webVC.topColor
        label.textColor = webVC.topColor.isLight ? .white : .darkText
        
        if let title : String = webVC.restorableTitle {
            label.text = "\(title)"
        }
    }
    
    
    
//    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true
//    }
    
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
            UIView.animate(withDuration: 1.4, delay: 0, usingSpringWithDamping: 0.3, initialSpringVelocity: 0, options: .curveLinear, animations: {
                self.transform = CGAffineTransform(scaleX: TAP_SCALE, y: TAP_SCALE)
            }, completion: nil)
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        // unSelect()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        unSelect()
    }
    
    func unSelect(animated : Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
                self.transform = .identity
                self.alpha = 1.0
            })
        }
        else {
            self.transform = .identity
            self.alpha = 1.0
        }
    }
    
    func setSnapshot(_ newSnapshot : UIView) {
        snap?.removeFromSuperview()
        
        snap = newSnapshot
        snap.frame = frameForSnap(snap)
        
        contentView.addSubview(snap)
        contentView.sendSubview(toBack: snap)
        
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
                
                if ( vel.x > 800 || gesturePos.x > frame.width * 0.8 ) {
                    endFrame.origin.x = startFrame.origin.x + startFrame.width
                    endAlpha = 0
                    closeTabCallback(self)
                }
                else if ( vel.x < -800 || gesturePos.x < -frame.width * 0.8 ) {
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
        snap?.removeFromSuperview()
        contentView.backgroundColor = .darkGray
    }
    
    func frameForSnap(_ snap : UIView) -> CGRect {
        let aspect = snap.frame.size.height / snap.frame.size.width
        let W = self.frame.size.width
        return CGRect(
            x: 0,
            y: _isExpanded ? STATUS_H : THUMB_OFFSET_COLLAPSED,
//            y: STATUS_H,
            width: W,
            height: aspect * W
        )
    }

}


