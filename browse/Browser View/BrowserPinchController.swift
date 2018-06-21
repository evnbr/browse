//
//  BrowserPinchController.swift
//  browse
//
//  Created by Evan Brooks on 6/19/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class BrowserPinchController: NSObject, UIGestureRecognizerDelegate {
    var vc: BrowserViewController!

    var isPinchDismissing = false
    var pinchStartScale: CGFloat = 1
    var pinchStartScroll: CGPoint = .zero

    @objc func pinch(gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            considerPinchDismissing(gesture: gesture)
        } else if gesture.state == .changed {
            updatePinchDismiss(gesture: gesture)
        } else if gesture.state == .ended || gesture.state == .cancelled {
            endPinchGesture(gesture: gesture)
        }
    }

    func updatePinchDismiss(gesture: UIPinchGestureRecognizer) {
        if isPinchDismissing {
            let adjustedScale = 1 - (pinchStartScale - gesture.scale)
            if adjustedScale > 1 {
                cancelPinchDismissing(gesture: gesture)
            } else {
                vc.view.scale = 0.5 + adjustedScale * 0.5
            }
        } else {
            considerPinchDismissing(gesture: gesture)
        }
    }
    func beginPinchDismissing(gesture: UIPinchGestureRecognizer) {
        isPinchDismissing = true
        pinchStartScale = gesture.scale
        pinchStartScroll = vc.webView.scrollView.contentOffset
        vc.contentView.radius = Const.cardRadius
    }
    func endPinchGesture(gesture: UIPinchGestureRecognizer) {
        if vc.view.scale < 0.8 {
            commitPinchDismissing(gesture: gesture)
        } else {
            cancelPinchDismissing(gesture: gesture)
        }
    }
    func commitPinchDismissing(gesture: UIPinchGestureRecognizer) {
        isPinchDismissing = false
        vc.displayHistory()
    }
    func cancelPinchDismissing(gesture: UIPinchGestureRecognizer) {
        isPinchDismissing = false
        vc.view.springScale(to: 1)
    }
    func considerPinchDismissing(gesture: UIPinchGestureRecognizer) {
        let scrollView = vc.webView.scrollView
        if scrollView.zoomScale < scrollView.minimumZoomScale {
            beginPinchDismissing(gesture: gesture)
        }
    }
}
