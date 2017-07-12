//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

typealias CloseTabCallback = (UICollectionViewCell) -> Void
let THUMB_OFFSET_COLLAPSED : CGFloat = 0

class TabThumbnail: UICollectionViewCell, UIGestureRecognizerDelegate {

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
        
        layer.cornerRadius = CORNER_RADIUS
        backgroundColor = .clear
        clipsToBounds = true
        
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
        
//        layer.shadowColor = UIColor.black.cgColor
//        layer.shadowOpacity = 0.4
//        layer.shadowOffset = CGSize.zero
//        layer.shadowRadius = 4
        
        
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
        
//        contentView.translatesAutoresizingMaskIntoConstraints = false
//        contentView.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
//        contentView.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
//        contentView.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
//        contentView.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
            UIView.animate(withDuration: 0.3, animations: {
                self.transform = CGAffineTransform(scaleX: TAP_SCALE, y: TAP_SCALE)
                self.alpha = 0.9
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
    
    func unSelect() {
        UIView.animate(withDuration: 0.2, delay: 0.0, animations: {
            self.transform = .identity
            self.alpha = 1.0
        })
    }
    
    func setSnapshot(_ newSnapshot : UIView) {
        snap?.removeFromSuperview()
        
        snap = newSnapshot
        snap.frame = frameForSnap(snap)
//        snap.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
        
        contentView.addSubview(snap)
        contentView.sendSubview(toBack: snap)
        
//        snap.translatesAutoresizingMaskIntoConstraints = false
        
//        let aspect = snap.frame.size.height / snap.frame.size.width
//        snap.topAnchor.constraint(equalTo: contentView.topAnchor, constant: STATUS_H).isActive = true
//        snap.centerXAnchor.constraint(equalTo: contentView.centerXAnchor).isActive = true
//        snap.widthAnchor.constraint(equalTo: contentView.widthAnchor).isActive = true
//        snap.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: aspect).isActive = true
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
//                    endFrame.size.width = 0
                    endAlpha = 0
                    closeTabCallback(self)
                }
                else if ( vel.x < -800 || gesturePos.x < -frame.width * 0.8 ) {
                    endFrame.origin.x = startFrame.origin.x - frame.width
//                    endFrame.size.width = 0
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
        setPlaceholderSnap()
    }
    
    func setPlaceholderSnap() {
        let snapPlaceholder = UIView(frame: UIScreen.main.bounds)
        snapPlaceholder.backgroundColor = .darkGray
        setSnapshot(snapPlaceholder)
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


