//
//  HomeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit

class HomeViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {

    var tabs : [BrowserTab] = []
    var browserVC : BrowserViewController!
    
    var toolbar : ColorToolbarView!
    
    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 8.0, left: THUMB_INSET, bottom: 8.0, right: THUMB_INSET)
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
        collectionView?.delaysContentTouches = false
        
        collectionView?.alwaysBounceVertical = true
        collectionView?.scrollIndicatorInsets.bottom = Const.shared.toolbarHeight
        collectionView?.scrollIndicatorInsets.top = Const.shared.statusHeight
        collectionView?.indicatorStyle = .white
        
        collectionView?.register(TabThumbnail.self, forCellWithReuseIdentifier: reuseIdentifier)
        
        title = ""
        view.backgroundColor = .black
        view.layer.cornerRadius = CORNER_RADIUS
        view.layer.masksToBounds = true
        
        collectionView?.backgroundColor = .black
        
        navigationController?.navigationBar.tintColor = .white
        navigationController?.navigationBar.barStyle = .black
        
        toolbar = ColorToolbarView(frame: CGRect(
            x: view.frame.width - 80,
            y: Const.shared.statusHeight, //view.frame.height - Const.shared.toolbarHeight,
            width: 80,
            height: 48
        ))
        toolbar.backgroundColor = .black
        toolbar.autoresizingMask = [ .flexibleBottomMargin, .flexibleLeftMargin ]
        toolbar.layer.zPosition = 100
        
        let addButton = ToolbarIconButton(
            icon: UIImage(named: "add"),
            onTap: self.addTab
        )
        
        let clearButton = ToolbarTextButton(
            title: "Clear",
            withIcon: nil, //UIImage(named: "add"),
            onTap: self.clearTabs
        )
        clearButton.size = .small
        
        toolbar.items = [addButton]
//        toolbar.isHidden = true
        view.addSubview(toolbar)
        
        collectionView?.contentInset = UIEdgeInsets(
            top: Const.shared.statusHeight,
            left: 0,
            bottom: Const.shared.toolbarHeight,
            right: 0
        )
        
        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(notification:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
        
        Blocker.shared.onRulesReady({
            print("rules ready")
            if let ruleList = Blocker.shared.ruleList {
                for tab in self.tabs {
                    tab.webView.configuration.userContentController.add(ruleList)
                }
            }
        })
        
        self.restoreTabs()
    }
    
    func restoreTabs() {
        collectionView?.performBatchUpdates({
            let tabsToRestore = self.getPreviousOpenTabs()
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
            if let lastIndex : Int = UserDefaults.standard.value(forKey: "presentedTabIndex") as? Int {
                if lastIndex > -1 && lastIndex < self.tabs.count {
                    self.showTab(self.tabs[lastIndex], animated: false, completion: {
                        self.view.isHidden = false
                    })
                } else {
                    self.view.isHidden = false
                }
            } else {
                self.view.isHidden = false
            }
        })
    }
    
    @objc func applicationWillResignActive(notification: NSNotification) {
        saveOpenTabs()
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

    func addTab() {
        let newTab = BrowserTab()
        self.showTab(newTab)
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.tabs.append(newTab)
            self.collectionView?.insertItems(at: [ IndexPath(item: self.tabs.index(of: newTab)!, section: 0) ])
            self.collectionViewLayout.invalidateLayout() // todo: shouldn't the layout just know?
            let thumb = self.thumb(forTab: newTab)
            thumb?.isHidden = true
        }
        
    }
    
    func closeTab(fromCell cell: UICollectionViewCell) {
        if let path = collectionView?.indexPath(for: cell) {
            collectionView?.performBatchUpdates({
                self.tabs.remove(at: path.row)
                self.collectionView?.deleteItems(at: [path])
            }, completion: nil)
            
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
            self.tabs.insert(newTab, at: self.tabs.index(of: prevTab)! + 1)
            let ip = IndexPath(item: self.tabs.index(of: newTab)!, section: 0)
            self.collectionView?.insertItems(at: [ ip ])
            self.collectionViewLayout.invalidateLayout() // todo: shouldn't the layout just know?
        }, completion: { _ in
            self.browserVC.gestureController.swapTo(childTab: newTab)
        })
        
        return newTab.webView
    }
    
    
    func showRenameThis(_ tab: BrowserTab) {
        showTab(tab)
    }
    
    func thumb(forTab tab: BrowserTab) -> TabThumbnail! {
        //return collectionView?.visibleCells.first as! TabThumbnail!
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
        guard let tab : BrowserTab = maybeTab else { return nil }
        guard let cv = collectionView else { return nil }
        guard let thumb = thumb(forTab: tab) else { return nil }
        guard let ip = cv.indexPath(for: thumb) else { return nil }
        return cv.layoutAttributesForItem(at: ip)!.bounds
    }
    
    func setThumbPosition(expanded: Bool, offsetY: CGFloat = 0, offsetHeight: CGFloat = 0) {
        guard let cv = collectionView else { return }
        
        if (expanded) {
            if let ip = currentIndexPath {
//                let selectedThumbFrame = cv.layoutAttributesForItem(at: ip)!.frame
//                let convertedFrame = view.convert(selectedThumbFrame, from: cv)
//                let shiftUp = -convertedFrame.origin.y
//                let shiftDown = view.frame.height - convertedFrame.origin.y - convertedFrame.height
                
                currentThumb?.isHidden = true
                currentThumb?.apply(cv.layoutAttributesForItem(at: ip)!)
                
                for cell in visibleCellsAbove {
                    let ip = cv.indexPath(for: cell)!
                    cell.center = cv.layoutAttributesForItem(at: ip)!.center
//                    cell.center.y += shiftUp + offsetY
                    cell.center.y = min(cell.center.y, Const.shared.statusHeight + collectionView!.contentOffset.y + cell.bounds.height / 2)
                    cell.isHidden = false
                }
                for cell in visibleCellsBelow {
                    let ip = cv.indexPath(for: cell)!
                    cell.center = cv.layoutAttributesForItem(at: ip)!.center
//                    cell.center.y += shiftDown + offsetY - offsetHeight
                    cell.center.y = Const.shared.statusHeight + collectionView!.contentOffset.y + view.bounds.height + cell.bounds.height / 2
                    cell.isHidden = false
                }
            }
            else {
                if let lastIndexPath = cv.indexPathsForVisibleItems.sorted(by: { $0.row < $1.row }).last {
                    let selectedThumbFrame = cv.layoutAttributesForItem(at: lastIndexPath)!.frame
                    let convertedFrame = view.convert(selectedThumbFrame, from: cv)
                    let shiftUp = -convertedFrame.origin.y - convertedFrame.height
                    
                    for cell in visibleCells {
                        let ip = cv.indexPath(for: cell)!
                        cell.center = cv.layoutAttributesForItem(at: ip)!.center
                        cell.center.y += shiftUp
                        cell.isHidden = false
                    }
                }
            }
        }
        else {
            for cell in visibleCells {
                let ip = cv.indexPath(for: cell)!
                cell.center = cv.layoutAttributesForItem(at: ip)!.center
            }
        }
    }
    
    func showTab(_ tab: BrowserTab, animated: Bool = true, completion: (() -> Void)? = nil) {
        browserVC.setTab(tab)
        browserVC.modalPresentationStyle = .custom
        browserVC.transitioningDelegate = self
        
        present(browserVC, animated: animated, completion: {
            self.thumb(forTab: tab)?.unSelect(animated: false)
            self.thumb(forTab: tab)?.setTab(tab)

            if let c = completion { c() }
        })
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true

        
        if isFirstLoad {
            isFirstLoad = false
        }
        
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
extension HomeViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabs.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier,
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
            let ratio = view.frame.width / (view.frame.height - Const.shared.toolbarHeight - Const.shared.statusHeight )
            let w = view.frame.width / 2 - 16
            return CGSize(width: w, height: w / ratio )
        }
        return CGSize(width: view.frame.width - sectionInsets.left - sectionInsets.right, height: THUMB_H)
    }
    
}

// MARK: - UICollectionViewDelegateFlowLayout
extension HomeViewController : UICollectionViewDelegateFlowLayout {

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
//
////    override func collectionView(_ collectionView: UICollectionView,
////                                 moveItemAt source: IndexPath,
////                                 to destination: IndexPath) {
////        let item = tabs.remove(at: source.item)
////        tabs.insert(item, at: destination.item)
////    }
//
}

// MARK: - Saving and restoring state
extension HomeViewController {
    func saveOpenTabs() {
        let info = tabs.map { tab in tab.restorableInfo.nsDictionary }
        UserDefaults.standard.setValue(info, forKey: "openTabList")
        
        if browserVC.isViewLoaded && (browserVC.view.window != nil) {
            // viewController is visible
            let index = tabs.index(of: browserVC.browserTab!)!
            UserDefaults.standard.set(index, forKey: "presentedTabIndex")
        } else {
            UserDefaults.standard.set(-1, forKey: "presentedTabIndex")
        }
    }
    
    func getPreviousOpenTabs() -> [ TabInfo ] {
        if let openTabs = UserDefaults.standard.value(forKey: "openTabList") as? [ [ String : Any ]] {
            let converted : [ TabInfo ] = openTabs.map { dict in
                let title = dict["title"] as? String ?? ""
                let urlString = dict["urlString"] as? String ?? ""
                var topColor : UIColor
                var bottomColor : UIColor
                if let rgb = dict["topColor"] as? [ CGFloat ] {
                    topColor = UIColor(r: rgb[0], g: rgb[1], b: rgb[2] )
                }
                else {
                    topColor = UIColor.white
                }
                if let rgb = dict["bottomColor"] as? [ CGFloat ] {
                    bottomColor = UIColor(r: rgb[0], g: rgb[1], b: rgb[2] )
                }
                else {
                    bottomColor = UIColor.white
                }

                return TabInfo(
                    title: title,
                    urlString: urlString,
                    topColor: topColor,
                    bottomColor: bottomColor
                )
            }
            return converted
        }
        return []
    }
}

struct TabInfo {
    var title : String
    var urlString : String
    var topColor: UIColor
    var bottomColor: UIColor
    
    var nsDictionary : NSDictionary {
        return NSDictionary(dictionary: [
            "title" : title,
            "urlString" : urlString,
            "topColor" : topColor.getRGB(),
            "bottomColor" : bottomColor.getRGB(),
        ])
    }
    
}
