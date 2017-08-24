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
    var selectedTab : BrowserTab?
    var browserVC : BrowserViewController!
    
    var toolbar : ColorToolbarView!
    
    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 8.0, left: 6.0, bottom: 8.0, right: 6.0)
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
        
        collectionView?.delaysContentTouches = false
        collectionView?.alwaysBounceVertical = true
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
            x: 0,
            y: view.frame.height - TOOLBAR_H,
            width: view.frame.width,
            height: TOOLBAR_H
        ))
        toolbar.backgroundColor = .black
        toolbar.autoresizingMask = [ .flexibleTopMargin, .flexibleWidth ]
        
        let addButton = ToolbarTextButton(
            title: "New",
            withIcon: UIImage(named: "add"),
            onTap: self.addTab
        )
        addButton.size = .small
        
        let clearButton = ToolbarTextButton(
            title: "Clear",
            withIcon: nil, //UIImage(named: "add"),
            onTap: self.clearTabs
        )
        clearButton.size = .small
        
        toolbar.items = [addButton]
        view.addSubview(toolbar)
        
        collectionView?.contentInset = UIEdgeInsets(
            top: STATUS_H,
            left: 0,
            bottom: TOOLBAR_H,
            right: 0
        )
        
        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillResignActive(notification:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
        
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
            let thumb = self.thumb(forTab: newTab)
            thumb?.isHidden = true
        }
        
    }
    
    func closeTab(fromCell cell: UICollectionViewCell) {
        if let path = collectionView?.indexPath(for: cell) {
            collectionView?.performBatchUpdates({
                self.tabs.remove(at: path.row)
                self.collectionView?.deleteItems(at: [path])
            }, completion: { _ in
                if self.tabs.count == 0 {
                    self.addTab()
                }
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
        let prevTab = self.selectedTab!
        // if we don't wait for each animation to complete,
        // the states get weird and the orginal tab gets hidden
        browserVC.dismiss(animated: true, completion: {
            self.collectionView?.performBatchUpdates({
//                self.tabs.append(newTab)
                
                // below tab that launched it
                self.tabs.insert(newTab, at: self.tabs.index(of: prevTab)! + 1)
                let ip = IndexPath(item: self.tabs.index(of: newTab)!, section: 0)
                self.collectionView?.insertItems(at: [ ip ])
            }, completion: { _ in
                self.showTab(newTab)
            })
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
    
    func showTab(_ tab: BrowserTab, animated: Bool = true, completion: (() -> Void)? = nil) {
        selectedTab = tab
        
        browserVC.setTab(tab)
        browserVC.modalPresentationStyle = .custom
        browserVC.transitioningDelegate = self
        
        present(browserVC, animated: animated, completion: {
            self.thumb(forTab: tab)?.unSelect(animated: false)
            if let c = completion { c() }
        })
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
        
        
        if isFirstLoad {
            isFirstLoad = false
            if tabs.count == 0 { addTab() }
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
    
    // TODO: This should be part of a custom layout subclass
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let cv = collectionView else { return }
        for cell in cv.visibleCells {
            let ip = cv.indexPath(for: cell)!
            let intendedFrame = cv.layoutAttributesForItem(at: ip)!.frame
            let vFrame = view.convert(intendedFrame, from: cell.superview)
            
            let scrollLimit = STATUS_H
            if vFrame.origin.y < scrollLimit {
                let pctOver = abs(scrollLimit - vFrame.origin.y) / 200
                cell.frame.origin.y = intendedFrame.origin.y - vFrame.origin.y + scrollLimit
                cell.alpha = 1 - pctOver
                let s = 1 - pctOver * 0.05
                cell.transform = CGAffineTransform(scaleX: s, y: s)
                cell.isUserInteractionEnabled = false
            }
            else {
                cell.frame.origin.y = intendedFrame.origin.y
                cell.alpha = 1
                cell.isUserInteractionEnabled = true
            }
            cell.layer.zPosition = CGFloat(ip.row)
        }
    }
    
    var thumbSize : CGSize {
        if view.frame.width > 400 {
            let ratio = view.frame.width / (view.frame.height - TOOLBAR_H - STATUS_H )
            let w = view.frame.width / 2 - 16
            return CGSize(width: w, height: w / ratio )
        }
        return CGSize(width: view.frame.width - sectionInsets.left - sectionInsets.right, height: THUMB_H)
//        return CGSize(width: view.frame.width, height: THUMB_H)
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
        return 8.0
    }
    
    override func collectionView(_ collectionView: UICollectionView,
                                 moveItemAt source: IndexPath,
                                 to destination: IndexPath) {
        let item = tabs.remove(at: source.item)
        tabs.insert(item, at: destination.item)
    }
    
    
}

// MARK: - Saving and restoring state
extension HomeViewController {
    func saveOpenTabs() {
        let info = tabs.map { tab in tab.restorableInfo.nsDictionary }
        UserDefaults.standard.setValue(info, forKey: "openTabList")
        
        if browserVC.isViewLoaded && (browserVC.view.window != nil) {
            // viewController is visible
            let index = tabs.index(of: selectedTab!)!
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
                var color : UIColor
                if let rgb = dict["color"] as? [ CGFloat ] {
                    color = UIColor(r: rgb[0], g: rgb[1], b: rgb[2] )
                }
                else {
                    color = UIColor.white
                }
                
                return TabInfo(
                    title: title,
                    urlString: urlString ,
                    color: color
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
    var color: UIColor
    
    var nsDictionary : NSDictionary {
        return NSDictionary(dictionary: [
            "title" : title,
            "urlString" : urlString,
            "color" : color.array,
        ])
    }
    
}
