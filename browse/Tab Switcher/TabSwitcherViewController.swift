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

class TabSwitcherViewController: UICollectionViewController {

    var _fetchedResultsController: NSFetchedResultsController<Tab>? = nil
    var blockOperations: [BlockOperation] = []

    var fab : FloatButton!
    var fabSnapshot : UIView?
    
    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 120.0, left: THUMB_INSET, bottom: 8.0, right: THUMB_INSET)
    let itemsPerRow : CGFloat = 2
    
    let thumbAnimationController = StackAnimatedTransitioning()
    let cardStackLayout = CardStackingLayout()

    private var _browserVC : BrowserViewController?
    func browser(for tab: Tab) -> BrowserViewController {
        if let browser = _browserVC {
            browser.setTab(tab)
            return browser
        }
        let newBrowser = BrowserViewController(tabSwitcher: self, tab: tab)
        _browserVC = newBrowser
        return newBrowser
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if let b = _browserVC, b.view.window != nil && !b.isBeingDismissed {
            return b.preferredStatusBarStyle
        }
        return .lightContent
    }
    override var prefersStatusBarHidden: Bool {
        return _browserVC?.prefersStatusBarHidden ??  false
    }
    
    var tabCount : Int {
        return fetchedResultsController.sections?.first?.numberOfObjects ?? 0
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.clipsToBounds = false
        navigationController?.navigationBar.barStyle = .blackTranslucent
        navigationController?.navigationBar.tintColor = .white
        
        collectionView?.clipsToBounds = false
        collectionView?.collectionViewLayout = cardStackLayout
        collectionView?.delaysContentTouches = false
        collectionView?.alwaysBounceVertical = true
        collectionView?.scrollIndicatorInsets.top = Const.statusHeight
        collectionView?.indicatorStyle = .white
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.register(DismissableTabCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView?.backgroundColor = .black
        
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.scrollToBottom()
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
    
    var isDisplayingFakeTab = false
    func showSearch() {
        let search = SearchViewController()
        search.isFakeTab = true
//        if tabCount < 1 { search.showingCancel = false }
        isDisplayingFakeTab = true
        present(search, animated: true, completion: nil)
//        addTab()
    }

    func addTab(startingFrom url: URL? = nil, animated: Bool = true) {
        let newTab = createTab()
        showTab(newTab, animated: animated, completion: {
            if let startURL = url,
                let browser = self._browserVC {
                browser.navigateTo(startURL)
            }
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
            let tab = fetchedResultsController.object(at: indexPath)
            _browserVC?.webViewManager.removeWebViewFor(tab)
            context.delete(tab)
            saveContext()
        }
    }
    
    func thumb(forTab tab: Tab) -> DismissableTabCell? {
        return collectionView?.visibleCells.first(where: { (cell) -> Bool in
            let thumb = cell as! DismissableTabCell
            return thumb.browserTab == tab
        }) as! DismissableTabCell?
    }
    
    var currentIndexPath : IndexPath? {
        guard let tab = _browserVC?.currentTab else { return nil }
        return fetchedResultsController.indexPath(forObject: tab)
    }
    
    var currentThumb : DismissableTabCell? {
        guard let tab = _browserVC?.currentTab else { return nil }
        return thumb(forTab: tab)
    }

    var visibleCells: [DismissableTabCell] {
        guard let cv = collectionView else { return [] }
        return cv.visibleCells as! [DismissableTabCell]
    }
    
    var visibleCellsAbove: [DismissableTabCell] {
        guard let cv = collectionView else { return [] }
        guard let selIndexPath = currentIndexPath else { return [] }

        return visibleCells.filter{ cell in
            let index : Int = cv.indexPath(for: cell)!.item
            return index < selIndexPath.item
        }
    }
    var visibleCellsBelow: [DismissableTabCell] {
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
    
    func setThumbsVisible() {
        visibleCells.forEach { $0.isHidden = false }
    }
    
    func setParentHidden(_ parentTab : Tab, hidden newValue: Bool) {
        cardStackLayout.parentIndexPath = self.fetchedResultsController.indexPath(forObject: parentTab)
        cardStackLayout.parentHidden = newValue
    }
    
    func setThumbScale(_ scale: CGFloat) {
        cardStackLayout.scale = scale
        cardStackLayout.invalidateLayout()
    }
    
    func setThumbPosition(cardOffset: CGPoint = .zero, offsetForContainer: Bool = false, isSwitcherMode: Bool = false, isToParent: Bool = false) {
        cardStackLayout.offset = cardOffset
        cardStackLayout.invalidateLayout()
    }
    
    func springCards(toStacked: Bool, at velocity: CGPoint = .zero, completion: (() -> ())? = nil) {
        if !toStacked {
            cardStackLayout.offset = .zero
            cardStackLayout.scale = 1
        }
        
        cardStackLayout.selectedHidden = true
        cardStackLayout.invalidateLayout()

        let spring = SpringSwitch {
            self.cardStackLayout.expandedProgress = $0
            self.cardStackLayout.invalidateLayout()
        }
        spring.setState(toStacked ? .end : .start)
        let anim = spring.springState(toStacked ? .start : .end) { (_, _) in
            if toStacked {
                self.cardStackLayout.selectedHidden = false
                self.cardStackLayout.invalidateLayout()
            }
            completion?()
        }
        anim?.springSpeed = 7
        anim?.springBounciness = 3
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
        let browser = self.browser(for: tab)
        browser.modalPresentationStyle = .custom
        browser.transitioningDelegate = self
        
        cardStackLayout.selectedIndexPath = currentIndexPath!

        present(browser, animated: animated, completion: {
            if let thumb = self.thumb(forTab: tab) {
                thumb.unSelect(animated: false)
                thumb.setTab(tab)
            }
            self.moveTabToEnd(tab)
            completion?()
        })
    }
    
    func scrollToBottom() {
        if let cv = self.collectionView, cv.isScrollableY {
            cv.contentOffset.y = cv.maxScrollYWithInset
        }
    }
    
    func updateThumbs() {
        visibleCells.forEach { $0.refresh() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        navigationController?.isNavigationBarHidden = true
        fabSnapshot = fab.snapshotView(afterScreenUpdates: false)
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
}

extension TabSwitcherViewController: UIViewControllerTransitioningDelegate {
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
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "sortIndex", ascending: true) ]
        
        let frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: HistoryManager.shared.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "OpenTabs")
        frc.delegate = self
        _fetchedResultsController = frc
        
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
            if let ip = self.currentIndexPath {
                self.cardStackLayout.selectedIndexPath = ip
            }
            self.scrollToBottom() // TODO this might be overkill
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
        if let thumb = cell as? DismissableTabCell {
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

