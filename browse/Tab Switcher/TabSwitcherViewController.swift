//
//  TabSwitcherViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class TabSwitcherViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {

    var tabs : [BrowserTab] = []
    var browserVC : BrowserViewController!
    
    var fabConstraint : NSLayoutConstraint!
    var fab : FloatButton!
    
    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 120.0, left: THUMB_INSET, bottom: 8.0, right: THUMB_INSET)
    let itemsPerRow : CGFloat = 2
    
    let thumbAnimationController = PresentTabAnimationController()
    
    var isFirstLoad = true
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if browserVC?.view.window != nil && !browserVC.isBeingDismissed {
            return browserVC.preferredStatusBarStyle
        }
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.isHidden = true
        
        browserVC = BrowserViewController(home: self)
        
        collectionView?.collectionViewLayout = StackingCollectionViewLayout()
//        collectionView?.collectionViewLayout = BlobCollectionViewLayout()

        collectionView?.delaysContentTouches = false
        
        collectionView?.alwaysBounceVertical = true
//        collectionView?.scrollIndicatorInsets.bottom = Const.toolbarHeight
        collectionView?.scrollIndicatorInsets.top = Const.statusHeight
        collectionView?.indicatorStyle = .white
        collectionView?.showsVerticalScrollIndicator = false
        
        collectionView?.register(TabThumbnail.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        title = ""
        view.backgroundColor = .black
        
        collectionView?.backgroundColor = .black
        
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .black
        
        
        
        fab = FloatButton(
            frame: CGRect(
                x: view.bounds.width - 80,
                y: view.bounds.height - Const.toolbarHeight,
                width: 64,
                height: 64),
            icon: UIImage(named: "add"),
            onTap: self.showSearch //self.addTab
        )
        view.addSubview(fab)
        
        fabConstraint = view.bottomAnchor.constraint(equalTo: fab.bottomAnchor, constant: 32.0)
        fabConstraint.isActive = true
        fab.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        fab.widthAnchor.constraint(equalToConstant: 64).isActive = true
        fab.heightAnchor.constraint(equalToConstant: 64).isActive = true

        collectionView?.contentInset = UIEdgeInsets(
            top: Const.statusHeight,
            left: 0,
            bottom: Const.toolbarHeight,
            right: 0
        )
        
        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(notification:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
        
        Blocker.shared.getList({ ruleList in
            if let list = ruleList {
                print("rules ready")
                for tab in self.tabs {
                    tab.webView.configuration.userContentController.add(list)
                }
            }
        })
        
        self.restoreTabs()
    }
    
    func restoreTabs() {
        collectionView?.performBatchUpdates({
            let tabsToRestore = TabSessionPersister.shared.restore()
            for info in tabsToRestore {
                let newTab = BrowserTab(
                    restoreInfo: info
                )
                self.tabs.append(newTab)
                let ip = IndexPath(item: self.tabs.index(of: newTab)!, section: 0)
                self.collectionView?.insertItems(at: [ ip ])
            }
        }, completion: { _ in
            //
            if let lastIndex = TabSessionPersister.shared.restoreIndex(), lastIndex < self.tabs.count {
                    self.showTab(self.tabs[lastIndex], animated: false, completion: {
                        self.view.isHidden = false
                    })
            } else {
                self.view.isHidden = false
            }
        })
    }
    
    @objc func applicationWillResignActive(notification: NSNotification) {
        var presentedIndex = -1
        if browserVC.isViewLoaded && (browserVC.view.window != nil) {
            if let tab = browserVC.browserTab, let index = tabs.index(of: tab) {
                presentedIndex = index
            }
        }
        TabSessionPersister.shared.save(tabs, presentedIndex: presentedIndex)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateCollectionViewLayout(with: size)
    }
    
    private func updateCollectionViewLayout(with size: CGSize) {
        if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
//            layout.itemSize = (size.width < size.height) ? itemSizeForPortraitMode : itemSizeForLandscapeMode
            layout.invalidateLayout()
        }
    }
    
    func showSearch() {
        let search = SearchViewController()
        if tabs.count < 1 { search.showingCancel = false }
        present(search, animated: true, completion: nil)
    }

    func addTab(startingFrom text: String? = nil, animated: Bool = true) {
        let newTab = BrowserTab()
        showTab(newTab, animated: animated, completion: {
            if let t = text { self.browserVC.navigateToText(t) }
        })
    }
    
    func closeTab(fromCell cell: UICollectionViewCell) {
        if let path = collectionView?.indexPath(for: cell) {
            collectionView?.performBatchUpdates({
                self.tabs.remove(at: path.row)
                self.collectionView?.deleteItems(at: [path])
            }, completion: { _ in
                if self.tabs.count < 1 { self.showSearch() }
            })
        }
    }
    
    func clearTabs() {
        collectionView?.performBatchUpdates({
            for tab in self.tabs {
                let ip = IndexPath(row: self.tabs.index(of: tab)!, section: 0)
                self.collectionView?.deleteItems(at: [ip])
            }
            self.tabs = []
        })
    }
    
    
    // todo: less copypasta with addTab()
    func openInNewTab(withConfig config: WKWebViewConfiguration) -> WKWebView {
        
        let newTab = BrowserTab(withNewTabConfig: config)
        let prevTab = browserVC.browserTab!
        newTab.parentTab = prevTab

        self.collectionView?.performBatchUpdates({
            self.tabs.append(newTab)
            let ip = IndexPath(item: self.tabs.count - 1, section: 0)
            self.collectionView?.insertItems(at: [ ip ])
            self.collectionViewLayout.invalidateLayout()
        }, completion: { _ in
            self.browserVC.gestureController.swapTo(childTab: newTab)
        })
        
        return newTab.webView
    }
    
    func thumb(forTab tab: BrowserTab) -> TabThumbnail! {
        return collectionView?.visibleCells.first(where: { (cell) -> Bool in
            let thumb = cell as! TabThumbnail
            return thumb.browserTab == tab
        }) as! TabThumbnail!
    }
    
    var currentIndexPath : IndexPath? {
        guard let thumb = currentThumb else { return nil }
        guard let cv = collectionView else { return nil }
        return cv.indexPath(for: thumb)
    }
    
    var currentThumb : TabThumbnail? {
        guard let tab = browserVC.browserTab else { return nil }
        return thumb(forTab: tab)
    }


    var visibleCells: [TabThumbnail] {
        guard let cv = collectionView else { return [] }
        return cv.visibleCells as! [TabThumbnail]
    }
    
    var visibleCellsAbove: [TabThumbnail] {
        guard let cv = collectionView else { return [] }
        guard let selIndexPath = currentIndexPath else { return [] }

        return visibleCells.filter{ cell in
            let index : Int = cv.indexPath(for: cell)!.item
            return index < selIndexPath.item
        }
    }
    var visibleCellsBelow: [TabThumbnail] {
        guard let cv = collectionView else { return [] }
        guard let selIndexPath = currentIndexPath else { return [] }

        return visibleCells.filter{ cell in
            let index : Int = cv.indexPath(for: cell)!.item
            return index > selIndexPath.item
        }
    }
    
    func boundsForThumb(forTab maybeTab: BrowserTab? ) -> CGRect? {
        guard let tab : BrowserTab = maybeTab,
            let cv = collectionView,
            let thumb = thumb(forTab: tab)
        else { return nil }
        guard let ip = cv.indexPath(for: thumb) else { return nil }
        
        return cv.layoutAttributesForItem(at: ip)!.bounds
    }
    
    func BLOBadjustedCenterFor(_ thumb: TabThumbnail, cardOffset: CGPoint = .zero, switcherProgress: CGFloat, offsetByScroll: Bool = false, isSwitcherMode: Bool = false) -> CGPoint {
        
        let cv = collectionView!
        let ip = cv.indexPath(for: thumb)!
        let currentIndex = currentIndexPath?.item ?? tabs.count
        let attrs = cv.layoutAttributesForItem(at: ip)!
        var center = attrs.center
        if ip.item == currentIndex { return center }

        let switchingY = center.y
        var collapsedY = center.y
    
        let distFromTop = switchingY - cv.contentOffset.y + attrs.bounds.size.height / 2
        
        if ip.item > currentIndex {
            collapsedY -= distFromTop // leave room
            collapsedY += view.bounds.height + Const.statusHeight // shift to bottom
            collapsedY += attrs.bounds.size.height / 2 // shift to bottom
//            if offsetByScroll {
//                collapsedY -= cv.contentOffset.y
//            }
        }
        else {
            collapsedY -= cardOffset.y // track card
            collapsedY -= distFromTop // leave room
        }
        
        center.y = !isSwitcherMode ? collapsedY : switchingY
//        center.x = center.x - (cardOffset.x * (1 - distFromFront * 0.1))
        
        return center
    }

    
    func adjustedCenterFor(_ ip: IndexPath, cardOffset: CGPoint = .zero, switcherProgress: CGFloat, offsetByScroll: Bool = false, isSwitcherMode: Bool = false) -> CGPoint {
        let cv = collectionView!
        let currentIndex = currentIndexPath?.item ?? tabs.count
        let attrs = cv.layoutAttributesForItem(at: ip)!
        var center = attrs.center
        if ip.item == currentIndex { return center }
        
        let switchingY = center.y
        var collapsedY = center.y
        
        let distFromFront : CGFloat = CGFloat(tabs.count - ip.item - 1)
        
//        collapsedY = Const.statusHeight + cv.contentOffset.y + attrs.bounds.height / 2
        collapsedY = cv.contentOffset.y + attrs.bounds.height / 2
        if ip.item > currentIndex {
            collapsedY += view.bounds.height + Const.statusHeight
            if offsetByScroll {
                collapsedY -= cv.contentOffset.y
            }
        }
        else {
            collapsedY -= cardOffset.y // track card
            collapsedY -= 160 * switcherProgress * distFromFront // spread
        }
        
        center.y = !isSwitcherMode ? collapsedY : switchingY
        center.x = center.x - (cardOffset.x * (1 - distFromFront * 0.1))
        
        return center
    }
    
    func setThumbPosition(switcherProgress: CGFloat, cardOffset: CGPoint = .zero, scale: CGFloat = 1, offsetForContainer: Bool = false, isSwitcherMode: Bool = false, isToParent: Bool = false) {
        for cell in visibleCells {
            let ip = collectionView!.indexPath(for: cell)!
            cell.center = adjustedCenterFor(ip, cardOffset: cardOffset, switcherProgress: switcherProgress, offsetByScroll: offsetForContainer, isSwitcherMode: isSwitcherMode)
            cell.scale = scale
            cell.isHidden = false
        }
        if !isSwitcherMode { currentThumb?.isHidden = true }
        if isToParent {
            thumb(forTab: tabs[currentIndexPath!.item - 1]).isHidden = true
        }
    }
    
    func springCards(expanded: Bool, at velocity: CGPoint = .zero) {
        for cell in visibleCells {
//            let ip = collectionView!.indexPath(for: cell)!
            let delay : CFTimeInterval = 0//expanded ? 0 : Double(tabs.count - ip.item) * 0.02
            let ip = collectionView!.indexPath(for: cell)!
            let center = adjustedCenterFor(ip, switcherProgress: expanded ? 0 : 1, isSwitcherMode: !expanded)
            
            var vel = velocity
            vel.x = 0
            let anim = cell.springCenter(to: center, at: vel, after: delay)
            anim?.springSpeed = 10
            anim?.springBounciness = 2
            cell.springScale(to: 1)
        }
    }
    
    func moveTabToEnd(_ tab: BrowserTab) {
        if let cv = self.collectionView {
            // Move this item to end of tabs array
            if let index = self.tabs.index(of: tab) {
                self.tabs.remove(at: index)
            }
            self.tabs.append(tab)
            cv.reloadData()
            
            self.scrollToBottom()
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                self.setThumbPosition(switcherProgress: 0)
            }
        }
    }
    
    func showTab(_ tab: BrowserTab, animated: Bool = true, completion: (() -> Void)? = nil) {
        browserVC.modalPresentationStyle = .custom
        browserVC.transitioningDelegate = self
        
        // TODO: settab is too expensive, noticable delay. only
        // need to set screenshot, not rearrange webview
        self.browserVC.setTab(tab)
        
        present(browserVC, animated: animated, completion: {
            if let thumb = self.thumb(forTab: tab) {
                thumb.unSelect(animated: false)
                thumb.setTab(tab)
            }
            self.moveTabToEnd(tab)
            if let c = completion { c() }
        })
    }
    
    func scrollToBottom() {
        if let cv = self.collectionView {
            if cv.isScrollable {
                cv.contentOffset.y = cv.contentSize.height - cv.bounds.size.height
            }
        }
    }
    
    func updateThumbs() {
        for tab in tabs {
            if let thumb = thumb(forTab: tab), let image = tab.history.current?.snapshot {
                thumb.setSnapshot(image)
            }
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
        
        isFirstLoad = false
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    // MARK - Animation
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        thumbAnimationController.direction = .present
        return thumbAnimationController
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        thumbAnimationController.direction = .dismiss
        return thumbAnimationController
    }

}

// MARK: - UICollectionViewDataSource
extension TabSwitcherViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath) as! TabThumbnail
        // Configure the cells
        
        let tab : BrowserTab = tabs[indexPath.row]
        cell.setTab(tab)
        cell.closeTabCallback = closeTab
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        showTab(tabs[indexPath.row])
    }
    
    
    var thumbSize : CGSize {
        if view.frame.width > 400 {
            let ratio = view.frame.width / (view.frame.height - Const.toolbarHeight - Const.statusHeight )
            let w = view.frame.width / 2 - 16
            return CGSize(width: w, height: w / ratio )
        }
        return CGSize(width: view.frame.width - sectionInsets.left - sectionInsets.right, height: THUMB_H)
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout
extension TabSwitcherViewController : UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return thumbSize
    }


    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForItem section: Int) -> UIEdgeInsets {
        return sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
}

