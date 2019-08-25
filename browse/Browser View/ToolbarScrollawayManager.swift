//
//  ToolbarScrollawayManager.swift
//  browse
//
//  Created by Evan Brooks on 7/7/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

extension UIScrollView {
    func setContentOffsetWithoutDelegate(_ newContentOffset: CGPoint) {
//        print("set without delegate: \(newContentOffset)")

        let lastDelegate = delegate;
        delegate = nil;
        setContentOffset(newContentOffset, animated: false);
        delegate = lastDelegate;
//        var rect = bounds;
//        rect.origin = newContentOffset;
//        bounds = rect;
    }
}

class ToolbarScrollawayManager: NSObject, UIScrollViewDelegate {
    var vc: BrowserViewController

    init(for vc: BrowserViewController) {
        self.vc = vc
        super.init()
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        showToolbar()
    }
    var prevScrollY: CGFloat = 0
    var scrollDelta: CGFloat = 0
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateToolbar(scrollView)
        
        let topBlockerH = max(0, Const.statusHeight - scrollView.contentOffset.y)
        vc.topOverscrollCoverHeightConstraint.constant = topBlockerH
        
        let amountOverBottom = scrollView.contentOffset.y - scrollView.maxScrollY
        let bottomBlockerH = max(0, Const.toolbarHeight + amountOverBottom)
        vc.bottomOverscrollCoverHeightConstraint.constant = bottomBlockerH

    }
    
    var shouldUpdateToolbar: Bool {
        let scrollView = vc.webView.scrollView
        return scrollView.isDragging
            && scrollView.isTracking
            && scrollView.isScrollableY
            && !scrollView.isOverScrolledTop
//            && !vc.webView.isLoading
            && !vc.isDisplayingSearch
    }
    
    func hideToolbar(animated: Bool = true) {
        //        return
        
        if !vc.webView.scrollView.isScrollableY {
            return
        }
        if vc.webView.isLoading {
            return
        }
        if vc.colorSampler.lastFixedResult?.hasBottomNav == true {
            return
        }
        if vc.toolbar.heightConstraint.constant == 0 {
            return
        }
        
        vc.toolbar.heightConstraint.constant = 0
        //        webviewBottomConstraint.constant = 0
        
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseInOut,
            animations: {
                self.vc.cardView.layoutIfNeeded()
                self.vc.webView.scrollView.horizontalScrollIndicatorInsets.bottom = -Const.toolbarHeight
                self.vc.toolbar.contentsAlpha = 0
        }
        )
        
        //        webView.scrollView.springBottomInset(to: Const.toolbarHeight)
    }
    
    func showToolbar(animated: Bool = true, adjustScroll: Bool = false) {
        //        return
        
        let dist = Const.toolbarHeight - vc.toolbar.heightConstraint.constant
        
        vc.toolbar.heightConstraint.constant = Const.toolbarHeight
        
        vc.topConstraint.constant = -Const.toolbarHeight

        if animated {
            UIView.animate(
                withDuration: animated ? 0.2 : 0,
                delay: 0,
                options: [.curveEaseInOut, .allowAnimatedContent],
                animations: {
                    self.vc.cardView.layoutIfNeeded()
                    self.vc.webView.scrollView.horizontalScrollIndicatorInsets.bottom = 0
                    self.vc.toolbar.contentsAlpha = 1
                    self.vc.additionalSafeAreaInsets.top = Const.toolbarHeight

            }, completion: { _ in

            })
            if adjustScroll {
                let scroll = vc.webView.scrollView
                var newOffset = scroll.contentOffset
                newOffset.y = min(scroll.maxScrollY, scroll.contentOffset.y + dist)
                scroll.setContentOffset(newOffset, animated: true)
            }
        } else {
            vc.toolbar.contentsAlpha = 1
        }
    }

    var isUpdating = false;
    func updateToolbar(_ scrollView: UIScrollView) {
//        return
        
//        print("delegate called: \(scrollView.contentOffset)")

        
        // Navigated to page that is not scrollable
        if scrollView.contentOffset.y == 0
            && !scrollView.isScrollableY
            && !vc.isShowingToolbar {
            showToolbar(animated: false)
            return
        }
        
        // don't leave a gap below bottom nav
        if vc.colorSampler.lastFixedResult?.hasBottomNav == true
            && !vc.isShowingToolbar {
            showToolbar(animated: false)
            return
        }
        
        if vc.isDisplayingSearch {
            scrollDelta = 0
            prevScrollY = scrollView.contentOffset.y
            if !vc.isShowingToolbar { showToolbar(animated: false) }
            return
        }
        
        scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y
        
        // only reshow toolbar after swipe up
        if vc.toolbar.heightConstraint.constant == 0 {
//            return
        }
        
        if self.shouldUpdateToolbar {
            var newH: CGFloat
            if scrollView.isOverScrolledBottomWithInset {
                // Scroll toolbar into view 'naturally' in same direction of scroll
                let amtOver = scrollView.maxScrollY - scrollView.contentOffset.y
                newH = Const.toolbarHeight - amtOver
            } else {
                // Hide on scroll down / show on scroll up
                newH = vc.toolbar.bounds.height - scrollDelta * 1.7
                if scrollView.contentOffset.y + Const.toolbarHeight > scrollView.maxScrollY {
                    // print("wouldn't be able to hide in time")
                }
            }
            
            let currentH = vc.toolbar.heightConstraint.constant
            let toolbarH = newH.limit(min: 0, max: Const.toolbarHeight)
            let pct = toolbarH / Const.toolbarHeight
            vc.toolbar.heightConstraint.constant = toolbarH
//            vc.webviewBottomConstraint.constant = max(0, toolbarH)
            let inset = -Const.toolbarHeight + toolbarH
            vc.topConstraint.constant = -toolbarH
            vc.additionalSafeAreaInsets.top = 0 + toolbarH
            
            let hDelta = currentH - toolbarH
            
            scrollView.setContentOffsetWithoutDelegate(
                CGPoint(
                    x: scrollView.contentOffset.x,
                    y: scrollView.contentOffset.y + hDelta
                )
            )
            prevScrollY += hDelta
//            scrollView.contentInset.bottom = inset + 100
//            print(scrollView.contentInset.bottom)
//            scrollView.verticalScrollIndicatorInsets.bottom = inset
            scrollView.horizontalScrollIndicatorInsets.bottom = inset

            let alpha = pct * 3 - 2
            vc.toolbar.contentsAlpha = alpha
        }
    }
    
    var dragStartScrollY: CGFloat = 0
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartScrollY = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !scrollView.isOverScrolledTop else { return }
        
//        return
        
        if scrollView.isOverScrolledBottom || scrollView.contentOffset.y == scrollView.maxScrollYWithInset {
            showToolbar(animated: true, adjustScroll: true)
            return
        }
        
        if vc.isDisplayingSearch {
            showToolbar(animated: false, adjustScroll: false)
            return
        }
        
        let dragAmount = scrollView.contentOffset.y - dragStartScrollY
        
        if scrollDelta > 1 {
            hideToolbar()
        } else if scrollDelta < -1 {
            showToolbar()
        } else if dragAmount > 1 {
            hideToolbar()
        } else if dragAmount < -1 {
            showToolbar()
        }
    }
}

