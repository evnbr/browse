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

    var snap : UIView!
    var webVC : WebViewController!
    var closeTabCallback : CloseTabCallback!
    
    var isExpanded : Bool {
        get {
            return snap.frame.origin.y == 0
        }
        set {
            snap?.frame.origin.y = newValue ? 0 : -STATUS_H
            layer.borderWidth = newValue ? 0.0 : 1.0
        }
    }
    
    override var frame : CGRect {
        didSet {
            snap?.frame = sizeForSnapshot(snap)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = CORNER_RADIUS
        backgroundColor = .clear
        clipsToBounds = true
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        isExpanded = false
        
        let dismissPanner = UIPanGestureRecognizer()
        dismissPanner.delegate = self
        dismissPanner.addTarget(self, action: #selector(panGestureChange(gesture:)))
//        dismissPanner.cancelsTouchesInView = true
        addGestureRecognizer(dismissPanner)
        
        setPlaceholderSnap()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if touches.first != nil {
            UIView.animate(withDuration: 0.15, animations: {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                self.alpha = 0.8
            })
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

    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)

        if touches.first != nil {
            unSelect()
        }
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
        snap.frame = sizeForSnapshot(snap)
        
        contentView.addSubview(snap)
    }
    
    func updateSnapshot() {
        guard let newSnap : UIView = webVC.cardView.snapshotView(afterScreenUpdates: true) else { return }
        setSnapshot(newSnap)
    }
    
    var isDismissing = false
    var startOrigin : CGPoint = .zero
    
    func panGestureChange(gesture: UIPanGestureRecognizer) {
        let gesturePos = gesture.translation(in: self)

        if gesture.state == .began {
            isDismissing = true
            startOrigin = frame.origin
        }
        else if gesture.state == .changed {
            if isDismissing {
                self.frame.origin.x = startOrigin.x + gesturePos.x
            }
        }
        else if gesture.state == .ended {

            if isDismissing {
                isDismissing = false
                
                var endPos : CGFloat = startOrigin.x
                if ( gesturePos.x > frame.width / 2 ) {
                    endPos = startOrigin.x + frame.width
                    closeTabCallback(self)
                }
                else if ( gesturePos.x < -frame.width / 2 ) {
                    endPos = startOrigin.x - frame.width
                    closeTabCallback(self)
                }
                
                UIView.animate(withDuration: 0.6, delay: 0.0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.0, options: .curveLinear, animations: {
                    self.frame.origin.x = endPos
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

    func sizeForSnapshot(_ snap : UIView) -> CGRect {
        let aspect = snap.frame.size.height / snap.frame.size.width
        let W = self.frame.size.width
        return CGRect(
            x: 0,
            y: isExpanded ? 0 : -STATUS_H,
            width: W,
            height: aspect * W
        )
    }

}


