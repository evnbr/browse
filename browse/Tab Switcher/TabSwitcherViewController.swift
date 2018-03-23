//
//  TabSwitcherViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import WebKit
import CoreData

class TabSwitcherViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {

    var browserVC : BrowserViewController!
    var _fetchedResultsController: NSFetchedResultsController<Tab>? = nil
    var blockOperations: [BlockOperation] = []

    var fab : FloatButton!
    var fabSnapshot : UIView?
    
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
    
    var tabCount : Int {
        return fetchedResultsController.sections?.first?.numberOfObjects ?? 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        browserVC = BrowserViewController(home: self)
        
        collectionView?.collectionViewLayout = StackingCollectionViewLayout()
        collectionView?.delaysContentTouches = false
        collectionView?.alwaysBounceVertical = true
        collectionView?.scrollIndicatorInsets.top = Const.statusHeight
        collectionView?.indicatorStyle = .white
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.register(TabThumbnail.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView?.backgroundColor = .black

        title = ""
        view.backgroundColor = .black
        
        
        fab = FloatButton(
            frame: CGRect(x: 0, y: 0, width: 64, height: 64),
            icon: UIImage(named: "add"),
            onTap: self.showSearch
        )
        view.addSubview(fab, constraints: [
            view.bottomAnchor.constraint(equalTo: fab.bottomAnchor, constant: 32),
            fab.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fab.widthAnchor.constraint(equalToConstant: 64),
            fab.heightAnchor.constraint(equalToConstant: 64),
        ])

        collectionView?.contentInset = UIEdgeInsets(
            top: Const.statusHeight,
            left: 0,
            bottom: Const.toolbarHeight,
            right: 0
        )
        
        if #available(iOS 11.0, *) {
            collectionView?.contentInsetAdjustmentBehavior = .never
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        updateCollectionViewLayout(with: size)
    }
    
    private func updateCollectionViewLayout(with size: CGSize) {
        if let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.invalidateLayout()
        }
    }
    
    func showSearch() {
        let search = SearchViewController()
        if tabCount < 1 { search.showingCancel = false }
        present(search, animated: true, completion: nil)
    }

    func addTab(startingFrom url: URL? = nil, animated: Bool = true) {
        let newTab = createTab()
        showTab(newTab, animated: animated, completion: {
            if let u = url { self.browserVC.navigateTo(u) }
        })
    }
    
    func createTab() -> Tab {
        let context = self.fetchedResultsController.managedObjectContext
        let newTab = Tab(context: context)
        saveContext()
        return newTab
    }
    
    func saveContext() {
        let context = self.fetchedResultsController.managedObjectContext
        do {
            try context.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nserror = error as NSError
            print("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    func closeTab(fromCell cell: UICollectionViewCell) {
        if let indexPath = collectionView?.indexPath(for: cell) {
            let context = fetchedResultsController.managedObjectContext
            context.delete(fetchedResultsController.object(at: indexPath))
            saveContext()
        }
    }
    
    
    func thumb(forTab tab: Tab) -> TabThumbnail? {
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
        guard let tab = browserVC.currentTab else { return nil }
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
    
    func boundsForThumb(forTab maybeTab: Tab? ) -> CGRect? {
        guard let tab : Tab = maybeTab,
            let cv = collectionView,
            let thumb = thumb(forTab: tab)
        else { return nil }
        guard let ip = cv.indexPath(for: thumb) else { return nil }
        
        return cv.layoutAttributesForItem(at: ip)!.bounds
    }
    
    func adjustedCenterFor(_ ip: IndexPath, cardOffset: CGPoint = .zero, switcherProgress: CGFloat, offsetByScroll: Bool = false, isSwitcherMode: Bool = false) -> CGPoint {
        let cv = collectionView!
        let count = fetchedResultsController.fetchedObjects?.count ?? 0
        let currentIndex = currentIndexPath?.item ?? count
        let attrs = cv.layoutAttributesForItem(at: ip)!
        var center = attrs.center
        if ip.item == currentIndex { return center }
        
        let switchingY = center.y
        var collapsedY = center.y
        
        let distFromFront : CGFloat = CGFloat(count - ip.item - 1)
        
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
    
    func setThumbsVisible() {
        visibleCells.forEach { $0.isHidden = false }
    }
    
    func setParentHidden(_ parentTab : Tab, hidden newValue: Bool) {
        thumb(forTab: parentTab)?.isHidden = newValue
    }
    
    func setThumbScale(_ scale: CGFloat) {
        visibleCells.forEach { $0.scale = scale }
    }
    
    func setThumbPosition(switcherProgress: CGFloat, cardOffset: CGPoint = .zero, offsetForContainer: Bool = false, isSwitcherMode: Bool = false, isToParent: Bool = false) {
        for cell in visibleCells {
            let ip = collectionView!.indexPath(for: cell)!
            cell.center = adjustedCenterFor(ip, cardOffset: cardOffset, switcherProgress: switcherProgress, offsetByScroll: offsetForContainer, isSwitcherMode: isSwitcherMode)
        }
        if !isSwitcherMode { currentThumb?.isHidden = true }
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
    
    func moveTabToEnd(_ tab: Tab) {
        tab.sortIndex = Int16(tabCount - 1)
        let tabs = fetchedResultsController.fetchedObjects ?? []
        var i : Int16 = 0
        for t in tabs {
            if t != tab {
                t.sortIndex = i
                i += 1
            }
        }
        saveContext()
    }
    
    func showTab(_ tab: Tab, animated: Bool = true, completion: (() -> Void)? = nil) {
        browserVC.modalPresentationStyle = .custom
        browserVC.transitioningDelegate = self
        
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
            if cv.isScrollableY {
                cv.contentOffset.y = cv.contentSize.height - cv.bounds.size.height
            }
        }
    }
    
    func updateThumbs() {
        visibleCells.forEach { $0.refresh() }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
        fabSnapshot = fab.snapshotView(afterScreenUpdates: false)
        
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

extension TabSwitcherViewController: NSFetchedResultsControllerDelegate {
    // MARK: - Fetched results controller
    
    var fetchedResultsController: NSFetchedResultsController<Tab> {
        if let existing = _fetchedResultsController { return existing }
        
        let fetchRequest: NSFetchRequest<Tab> = Tab.fetchRequest()
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "sortIndex", ascending: true) ]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: HistoryManager.shared.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "OpenTabs")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nserror = error as NSError
            print("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            blockOperations.append(BlockOperation { [weak self] in
                self?.collectionView!.insertItems(at: [newIndexPath!])
            })
        case .delete:
            blockOperations.append(BlockOperation { [weak self] in
                self?.collectionView!.deleteItems(at: [indexPath!])
            })
        case .update:
            blockOperations.append(BlockOperation { [weak self] in
                guard let cv = self?.collectionView, let ip = indexPath, let cell = cv.cellForItem(at: ip) else { return }
                self?.configureThumbnail(cell, withTab: anObject as! Tab)
            })
        case .move:
            blockOperations.append(BlockOperation { [weak self] in
                guard let cv = self?.collectionView, let ip = indexPath, let cell = cv.cellForItem(at: ip) else { return }
                self?.configureThumbnail(cell, withTab: anObject as! Tab)
                cv.moveItem(at: ip, to: newIndexPath!)
            })
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        collectionView!.performBatchUpdates({
            for operation: BlockOperation in self.blockOperations { operation.start() }
        }, completion: { finished in
            self.blockOperations.removeAll(keepingCapacity: false)
        })
    }

}

// MARK: - UICollectionViewDataSource
extension TabSwitcherViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath)
        // Configure the cells
        
        let tab = fetchedResultsController.object(at: indexPath)
        configureThumbnail(cell, withTab: tab)
        
        return cell
    }
    
    func configureThumbnail(_ cell: UICollectionViewCell, withTab tab: Tab) {
        if let thumb = cell as? TabThumbnail {
            thumb.setTab(tab)
            thumb.closeTabCallback = closeTab
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        showTab(fetchedResultsController.object(at: indexPath))
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

