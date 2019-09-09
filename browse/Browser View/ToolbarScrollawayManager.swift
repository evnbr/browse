//
//  ToolbarScrollawayManager.swift
//  browse
//
//  Created by Evan Brooks on 7/7/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

let SCROLLAWAY_ENABLED = true

/*
This has an unintuitive implementation to work around limitations
of WKWebview. The standard way to implement a hideable toolbar
would be with a bottom content inset. However, WKWebview only seems to respect
safeAreaInsets, and only top safeAreaInsets at that.

 We don't want to resize the frame of the webview like the Firefox or Brave
iOS implementations, because the web site may by using the height of the
screen to size elements. Changing the size of those elements during
a scroll interaction is janky and undesireable.

Therefore, the webview is a constant height, and is constrained to the
bottom of the toolbar. As the user scrolls, we shift the webview downward
to hide the toolbar, but reduce the safe area inset at the top to keep fixed
navigation elements in a constant position.
 
 See chrome inset: https://github.com/chromium/chromium/blob/211bf84eb2d998410bcb2625c890117f2e16f282/ios/chrome/browser/ui/browser_view/browser_view_controller.mm#L3919
 and frame alignment: https://github.com/chromium/chromium/blob/211bf84eb2d998410bcb2625c890117f2e16f282/ios/chrome/browser/ui/browser_view/browser_view_controller.mm#L3899

We compensate for that shift by adjusting the contentoffset in parallel,
so the webview scroll position still tracks the user's touch.

TODO:
Because this implementation is so involved, animating
the remanining distance when the toolbar is partially visible
doesns't work correctly, so we just leave it partically visible.
*/

extension UIScrollView {
    func setContentOffsetWithoutDelegate(_ newContentOffset: CGPoint) {
        let lastDelegate = delegate;
        delegate = nil;
        setContentOffset(newContentOffset, animated: false);
        delegate = lastDelegate;
    }
}

let toolbarHideRatio: CGFloat = 1.2

class ToolbarScrollawayManager: NSObject, UIScrollViewDelegate {
    var vc: BrowserViewController

    init(for vc: BrowserViewController) {
        self.vc = vc
        super.init()
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        showToolbar()
        return true
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
//        showToolbar()
        if !scrollView.isDragging && !scrollView.isDecelerating {
            updateStatusBarColor()
        }
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
            && !vc.isDisplayingSearch
    }
    
    var isShowingToolbar: Bool {
        return vc.toolbar.heightConstraint.constant > 0
    }
    
    func hideToolbar(animated: Bool = false) {
        guard SCROLLAWAY_ENABLED else { return }
        
        if !vc.webView.scrollView.isScrollableY {
            return
        }
        if vc.webView.isLoading {
            return
        }
        if vc.colorSampler.lastFixedResult?.hasBottomNav == true {
            return
        }
        if !isShowingToolbar {
            return
        }
        
        vc.toolbar.heightConstraint.constant = 0
        vc.topConstraint.constant = 0
        vc.additionalSafeAreaInsets.top = 0
//        vc.webView.scrollView.contentInset.top = 0

//        UIView.animate(
//            withDuration: 0.2,
//            delay: 0,
//            options: .curveEaseInOut,
//            animations: {
                self.vc.cardView.layoutIfNeeded()
                self.vc.webView.scrollView.horizontalScrollIndicatorInsets.bottom = -Const.toolbarHeight
                self.vc.toolbar.contentsAlpha = 0
//        }, completion: { _ in
//            self.vc.additionalSafeAreaInsets.top = 0
//        })
        
        //        webView.scrollView.springBottomInset(to: Const.toolbarHeight)
    }
    
    func showToolbar(animated: Bool = false, adjustScroll: Bool = false) {
        guard SCROLLAWAY_ENABLED else { return }

        let dist = Const.toolbarHeight - vc.toolbar.heightConstraint.constant
        
        vc.toolbar.heightConstraint.constant = Const.toolbarHeight
        vc.topConstraint.constant = -Const.toolbarHeight
        vc.additionalSafeAreaInsets.top = Const.toolbarHeight
//        vc.webView.scrollView.contentInset.top = Const.toolbarHeight

//        if animated {
//            UIView.animate(
//                withDuration: animated ? 0.2 : 0,
//                delay: 0,
//                options: [.curveEaseInOut, .allowAnimatedContent],
//                animations: {

                    self.vc.cardView.layoutIfNeeded()
                    self.vc.webView.scrollView.horizontalScrollIndicatorInsets.bottom = 0
                    self.vc.toolbar.contentsAlpha = 1

//            }, completion: { _ in
//                self.vc.additionalSafeAreaInsets.top = Const.toolbarHeight
//            })
            if adjustScroll {
                let scroll = vc.webView.scrollView
                var newOffset = scroll.contentOffset
                newOffset.y = min(scroll.maxScrollY, scroll.contentOffset.y + dist)
                scroll.setContentOffset(newOffset, animated: true)
            }
//        } else {
//            vc.toolbar.contentsAlpha = 1
//        }
    }

    var isUpdating = false;
    
    func setAdjustmentsFor(toolbarHeight: CGFloat) {
        
    }
    
    func updateToolbar(_ scrollView: UIScrollView) {
        guard SCROLLAWAY_ENABLED else { return }

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
                newH = vc.toolbar.bounds.height - scrollDelta * toolbarHideRatio
                if scrollView.contentOffset.y + Const.toolbarHeight > scrollView.maxScrollY {
                    // print("wouldn't be able to hide in time")
                }
            }
            
            let currentH = vc.toolbar.heightConstraint.constant
            let toolbarH = newH.limit(min: 0, max: Const.toolbarHeight)
            let pct = toolbarH / Const.toolbarHeight
            vc.toolbar.heightConstraint.constant = toolbarH
            let inset = -Const.toolbarHeight + toolbarH
            vc.topConstraint.constant = -toolbarH
            vc.additionalSafeAreaInsets.top = 0 + toolbarH
//            scrollView.contentInset.top = toolbarH
            
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
    
    func updateStatusBarColor() {
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState], animations: {
            self.vc.setNeedsStatusBarAppearanceUpdate()
        })
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateStatusBarColor()
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
        
//        if scrollDelta > 1 {
//            hideToolbar()
//        } else if scrollDelta < -1 {
//            showToolbar()
//        } else if dragAmount > 1 {
//            hideToolbar()
//        } else if dragAmount < -1 {
//            showToolbar()
//        }
        
        if !decelerate {
            updateStatusBarColor()
        }
    }
}

