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

//        self.view.isHidden = true
        
        browserVC = BrowserViewController(home: self)
        
        collectionView?.collectionViewLayout = StackingCollectionViewLayout()
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
            onTap: self.addTab
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
        showTab(newTab)
        
//        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
//            self.tabs.append(newTab)
//            self.collectionView?.insertItems(at: [ IndexPath(item: self.tabs.index(of: newTab)!, section: 0) ])
//            self.collectionViewLayout.invalidateLayout() // todo: shouldn't the layout just know?
//            let thumb = self.thumb(forTab: newTab)
//            thumb?.isHidden = true
//        }
        
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
            self.tabs.append(newTab)
            let ip = IndexPath(item: self.tabs.count - 1, section: 0)
            self.collectionView?.insertItems(at: [ ip ])
            self.collectionViewLayout.invalidateLayout()
        }, completion: { _ in
            self.browserVC.gestureController.swapTo(childTab: newTab)
            
            if let cv = self.collectionView {
                self.collectionView?.reloadData()
                // Scroll to end
                if cv.isScrollable {
                    cv.contentOffset.y = cv.contentSize.height - cv.bounds.size.height
                }
            }
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
    
    func setThumbPosition(expanded: Bool, offsetForContainer: Bool = false) {
        guard let cv = collectionView else { return }
        
        if (expanded) {
            if let ip = currentIndexPath {
                currentThumb?.isHidden = true
                currentThumb?.apply(cv.layoutAttributesForItem(at: ip)!)
                
                for cell in visibleCellsAbove {
                    let ip = cv.indexPath(for: cell)!
                    cell.center = cv.layoutAttributesForItem(at: ip)!.center
                    cell.center.y = Const.statusHeight + collectionView!.contentOffset.y + view.bounds.height + cell.bounds.height / 2
                    cell.isHidden = false
                }
                for cell in visibleCellsBelow {
                    let ip = cv.indexPath(for: cell)!
                    cell.center = cv.layoutAttributesForItem(at: ip)!.center
                    cell.center.y = Const.statusHeight + cv.contentOffset.y + view.bounds.height + cell.bounds.height / 2
                    cell.isHidden = false
                    
                    if offsetForContainer { cell.center.y -= cv.contentOffset.y }
                }
            }
            else {
                for cell in visibleCells {
                    let ip = cv.indexPath(for: cell)!
                    cell.center = cv.layoutAttributesForItem(at: ip)!.center
                    cell.center.y = Const.statusHeight + cv.contentOffset.y + view.bounds.height + cell.bounds.height / 2
                    cell.isHidden = false
                    
                    if offsetForContainer { cell.center.y -= cv.contentOffset.y }
                }
            }
        }
        else {
            for cell in visibleCells {
                let ip = cv.indexPath(for: cell)!
                cell.center = cv.layoutAttributesForItem(at: ip)!.center
            }
            if offsetForContainer {
                for cell in visibleCellsBelow {
                    cell.center.y -= cv.contentOffset.y
                }
            }
        }
    }
    
    func showTab(
        _ tab: BrowserTab,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        browserVC.modalPresentationStyle = .custom
        browserVC.transitioningDelegate = self
        
        // TODO: settab is too expensive, noticable delay. only
        // need to set screenshot, not rearrange webview
        self.browserVC.setTab(tab)
        
        present(browserVC, animated: animated, completion: {
            self.thumb(forTab: tab)?.unSelect(animated: false)
            self.thumb(forTab: tab)?.setTab(tab)

            if let cv = self.collectionView {
                // Move this item to end of tabs array
                if let index = self.tabs.index(of: tab) {
                    self.tabs.remove(at: index)
                }
                self.tabs.append(tab)
                cv.reloadData()

                self.scrollToBottom()
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
                    self.setThumbPosition(expanded: true)
                }
            }
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
            let ratio = view.frame.width / (view.frame.height - Const.toolbarHeight - Const.statusHeight )
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
//    override func collectionView(_ collectionView: UICollectionView,
//                                 moveItemAt source: IndexPath,
//                                 to destination: IndexPath) {
//        let item = tabs.remove(at: source.item)
//        tabs.insert(item, at: destination.item)
//    }
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
