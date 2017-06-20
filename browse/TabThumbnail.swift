//
//  TabThumbnail.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

typealias tabTapType = (_ tab: WebViewController) -> Void

class TabThumbnail: UIView {

    var snap : UIView!
    var tab : WebViewController!
    var onTap: tabTapType!
    
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
    
    init(frame: CGRect, tab: WebViewController?, onTap: tabTapType?) {
        self.tab = tab
        self.onTap = onTap
    
        super.init(frame: frame)
        autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]


        let thumbTap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        self.addGestureRecognizer(thumbTap)

        
        layer.cornerRadius = CORNER_RADIUS
        backgroundColor = .clear
        clipsToBounds = true
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor
        
        isExpanded = false
    }
    
    func tapped() {
        onTap?(tab)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            UIView.animate(withDuration: 0.15, animations: {
                self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
                self.alpha = 0.8
            })
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            // do something with your currentPoint
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if touches.first != nil {
            unSelect()
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        
        self.addSubview(snap)
    }
    
    func updateSnapshot() {
        guard let newSnap : UIView = tab.cardView.snapshotView(afterScreenUpdates: true) else { return }
        setSnapshot(newSnap)
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
