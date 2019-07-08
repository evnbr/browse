//
//  ToolbarManager.swift
//  browse
//
//  Created by Evan Brooks on 7/7/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

class ToolbarManager: NSObject, UIScrollViewDelegate {
    var vc: BrowserViewController

    init(for vc: BrowserViewController) {
        self.vc = vc
        super.init()
    }
    
    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        vc.showToolbar()
    }
    var prevScrollY: CGFloat = 0
    var scrollDelta: CGFloat = 0
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateToolbar(scrollView)
        
        let blockerH = max(0, Const.statusHeight - scrollView.contentOffset.y)
        vc.overscrollCoverHeightConstraint.constant = blockerH
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
    
    func updateToolbar(_ scrollView: UIScrollView) {
//        return
        
        // Navigated to page that is not scrollable
        if scrollView.contentOffset.y == 0
            && !scrollView.isScrollableY
            && !vc.isShowingToolbar {
            vc.showToolbar(animated: false)
            return
        }
        
        // don't leave a gap below bottom nav
        if vc.colorSampler.lastFixedResult?.hasBottomNav == true
            && !vc.isShowingToolbar{
            vc.showToolbar(animated: false)
            return
        }
        
        if vc.isDisplayingSearch {
            scrollDelta = 0
            prevScrollY = scrollView.contentOffset.y
            if !vc.isShowingToolbar { vc.showToolbar(animated: false) }
            return
        }
        
        scrollDelta = scrollView.contentOffset.y - prevScrollY
        prevScrollY = scrollView.contentOffset.y
        
        // only reshow toolbar after swipe up
//        if vc.toolbar.heightConstraint.constant == 0 {
//            return
//        }
        
        if self.shouldUpdateToolbar {
            var newH: CGFloat
            if scrollView.isOverScrolledBottomWithInset {
                // Scroll toolbar into view 'naturally' in same direction of scroll
                let amtOver = scrollView.maxScrollY - scrollView.contentOffset.y
                newH = Const.toolbarHeight - amtOver
            } else {
                // Hide on scroll down / show on scroll up
                newH = vc.toolbar.bounds.height - scrollDelta * 2
                if scrollView.contentOffset.y + Const.toolbarHeight > scrollView.maxScrollY {
                    // print("wouldn't be able to hide in time")
                }
            }
            
            let toolbarH = newH.limit(min: 0, max: Const.toolbarHeight)
            let pct = toolbarH / Const.toolbarHeight
            vc.toolbar.heightConstraint.constant = toolbarH
//            let inset = -Const.toolbarHeight + toolbarH
//            scrollView.contentInset.bottom = inset + 100
//            print(scrollView.contentInset.bottom)
//            scrollView.verticalScrollIndicatorInsets.bottom = inset
            
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
        
        if scrollView.isOverScrolledBottom || scrollView.contentOffset.y == scrollView.maxScrollYWithInset {
            vc.showToolbar(animated: true, adjustScroll: true)
            return
        }
        
        if vc.isDisplayingSearch {
            vc.showToolbar(animated: false, adjustScroll: false)
            return
        }
        
        let dragAmount = scrollView.contentOffset.y - dragStartScrollY
        
        if scrollDelta > 1 {
            vc.hideToolbar()
        } else if scrollDelta < -1 {
            vc.showToolbar()
        } else if dragAmount > 1 {
            vc.hideToolbar()
        } else if dragAmount < -1 {
            vc.showToolbar()
        }
    }
}

