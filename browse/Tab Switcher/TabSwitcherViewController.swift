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

let FAB_SIZE: CGFloat = 64

class TabSwitcherViewController: UICollectionViewController {

    var _fetchedResultsController: NSFetchedResultsController<Tab>?
    var blockOperations: [BlockOperation] = []

    var fab: FloatButton!
    var fabSnapshot: UIView?

    let reuseIdentifier = "TabCell"
    let sectionInsets = UIEdgeInsets(top: 120.0, left: THUMB_INSET, bottom: 8.0, right: THUMB_INSET)
    let itemsPerRow: CGFloat = 2

    let cardStackTransition = CardStackTransition()
    let cardStackLayout = CardStackCollectionViewLayout()

    private var _browserVC: BrowserViewController?
    func setupBrowser(with tab: Tab) -> BrowserViewController {
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

    var tabCount: Int {
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
            frame: CGRect(x: 0, y: 0, width: FAB_SIZE, height: FAB_SIZE),
            icon: UIImage(named: "add"),
            onTap: { self.addTab() }
        )
        view.addSubview(fab, constraints: [
            view.bottomAnchor.constraint(equalTo: fab.bottomAnchor, constant: 32),
            fab.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fab.widthAnchor.constraint(equalToConstant: FAB_SIZE),
            fab.heightAnchor.constraint(equalToConstant: FAB_SIZE)
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

//    var isDisplayingFakeTab = false

    func addTab(animated: Bool = true) {
        let newTab = createTab()
        newTab.sortIndex = Int16(tabCount)
        cardStackTransition.fromBottom = true
        self.showTab(newTab, animated: animated, completion: {
            self.cardStackTransition.fromBottom = false
        })
    }

    func createTab() -> Tab {
        let context = self.fetchedResultsController.managedObjectContext
        let newTab = Tab(context: context)
        newTab.creationTime = Date()
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

    func closeTab(tab: Tab) {
        cardStackLayout.dismissIndexPath = nil
        cardStackLayout.dismissProgress = 0

        tab.isClosed = true
        _browserVC?.webViewManager.removeWebViewFor(tab)
        saveContext()
    }

    func dismissTab(from cell: UICollectionViewCell, progress: CGFloat) {
        if let indexPath = collectionView?.indexPath(for: cell) {
            cardStackLayout.dismissIndexPath = indexPath
            cardStackLayout.dismissProgress = progress
            cardStackLayout.invalidateLayout()
        }
    }
    func swipeTab(from cell: UICollectionViewCell, progress: CGFloat) {
        if let indexPath = collectionView?.indexPath(for: cell) {
            cardStackLayout.dismissIndexPath = indexPath
            cardStackLayout.swipeOffset = progress
            cardStackLayout.invalidateLayout()
        }
    }

    func thumb(forTab tab: Tab) -> DismissableTabCell? {
        return visibleCells.first(where: { (cell) -> Bool in
            return cell.browserTab == tab
        })
    }

    var currentIndexPath: IndexPath? {
        guard let tab = _browserVC?.currentTab else { return nil }
        return fetchedResultsController.indexPath(forObject: tab)
    }

    var currentThumb: DismissableTabCell? {
        guard let tab = _browserVC?.currentTab else { return nil }
        return thumb(forTab: tab)
    }

    var visibleCells: [ DismissableTabCell ] {
        guard let cv = collectionView else { return [] }
        return cv.visibleCells as? [ DismissableTabCell ] ?? []
    }

    var visibleCellsAbove: [DismissableTabCell] {
        guard let cv = collectionView else { return [] }
        guard let selIndexPath = currentIndexPath else { return [] }

        return visibleCells.filter { cell in
            let index: Int = cv.indexPath(for: cell)!.item
            return index < selIndexPath.item
        }
    }
    var visibleCellsBelow: [DismissableTabCell] {
        guard let cv = collectionView else { return [] }
        guard let selIndexPath = currentIndexPath else { return [] }

        return visibleCells.filter { cell in
            let index: Int = cv.indexPath(for: cell)!.item
            return index > selIndexPath.item
        }
    }

    func boundsForThumb(forTab maybeTab: Tab? ) -> CGRect? {
        guard let tab: Tab = maybeTab,
            let cv = collectionView,
            let thumb = thumb(forTab: tab)
        else { return nil }
        guard let ip = cv.indexPath(for: thumb) else { return nil }

        return cv.layoutAttributesForItem(at: ip)!.bounds
    }

    func setThumbsVisible() {
        visibleCells.forEach { $0.isHidden = false }
    }

    func setParentHidden(_ parentTab: Tab, hidden newValue: Bool) {
        cardStackLayout.parentIndexPath = self.fetchedResultsController.indexPath(forObject: parentTab)
        cardStackLayout.parentHidden = newValue
    }

    func setThumbScale(_ scale: CGFloat) {
        cardStackLayout.maxScale = scale
        cardStackLayout.invalidateLayout()
    }

    private func setCardOffset(to offset: CGPoint = .zero) {
        cardStackLayout.offset = offset
        cardStackLayout.invalidateLayout()
    }

    func updateStackOffset(for pos: CGPoint) {
        setCardOffset(to: CGPoint(
            x: view.center.x - pos.x,
            y: view.center.y - pos.y
        ))
    }

    func springCards(
        toStacked: Bool,
        at velocity: CGPoint = .zero,
        completion: (() -> Void)? = nil) {
        cardStackLayout.isTransitioning = true
        cardStackLayout.selectedHidden = true
        cardStackLayout.invalidateLayout()

        let spring = SpringSwitch {
            self.cardStackLayout.expandedProgress = $0
            self.cardStackLayout.invalidateLayout()
        }
        spring.setState(toStacked ? .end : .start)
        let anim = spring.springState(toStacked ? .start : .end) { (_, _) in
            completion?()
        }
        anim?.springSpeed = 6
        anim?.springBounciness = 2
    }

    func moveTabToEnd(_ tab: Tab) {
//        if tab.sortIndex == tabCount - 1 { return }
        tab.sortIndex = Int16(tabCount - 1)
        let tabs = fetchedResultsController.fetchedObjects ?? []
        var i: Int16 = 0
        for t in tabs {
            if t == tab { continue }
            t.sortIndex = i
            i += 1
        }
        saveContext()
    }

    func showTab(_ tab: Tab, animated: Bool = true, completion: (() -> Void)? = nil) {
        let browser = setupBrowser(with: tab)
        browser.modalPresentationStyle = .custom
        browser.transitioningDelegate = self

        cardStackLayout.selectedIndexPath = currentIndexPath!
        if tab.currentVisit == nil {
            cardStackTransition.useArc = false
            browser.displaySearch(isInstant: true)
        }
        present(browser, animated: animated, completion: {
            if let thumb = self.thumb(forTab: tab) {
                thumb.unSelect(animated: false)
                thumb.setTab(tab)
            }
            self.cardStackTransition.useArc = true
            self.moveTabToEnd(tab)
            completion?()
        })
    }

    func scrollToBottom(animated: Bool = false) {
        if let cv = self.collectionView, cv.isScrollableY {
            cv.setContentOffset(
                CGPoint(x: cv.contentOffset.x, y: cv.maxScrollYWithInset),
                animated: animated)
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
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        cardStackTransition.direction = .present
        return cardStackTransition
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        cardStackTransition.direction = .dismiss
        return cardStackTransition
    }
}

extension TabSwitcherViewController: NSFetchedResultsControllerDelegate {
    // MARK: - Fetched results controller

    var fetchedResultsController: NSFetchedResultsController<Tab> {
        if let existing = _fetchedResultsController { return existing }

        let fetchRequest: NSFetchRequest<Tab> = Tab.fetchRequest()
        fetchRequest.fetchBatchSize = 20
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "sortIndex", ascending: true) ]
        fetchRequest.predicate = NSPredicate(format: "isClosed == NO")

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

    func controller(
        _ controller: NSFetchedResultsController<NSFetchRequestResult>,
        didChange anObject: Any,
        at indexPath: IndexPath?,
        for type: NSFetchedResultsChangeType,
        newIndexPath: IndexPath?) {

        switch type {
        case .insert:
            blockOperations.append(BlockOperation { [weak self] in
                self?.cardStackLayout.addIndexPath = newIndexPath!
                self?.collectionView!.insertItems(at: [newIndexPath!])
                // TODO: for some reason, tap and swipe gestures don't work
                // until configurethumbnail eventually
                // gets called (ie scroll out of view and back in). Why?
            })
        case .delete:
            blockOperations.append(BlockOperation { [weak self] in
                self?.collectionView!.deleteItems(at: [indexPath!])
            })
        case .update:
            blockOperations.append(BlockOperation { [weak self] in
                guard let cv = self?.collectionView,
                    let ip = indexPath,
                    let cell = cv.cellForItem(at: ip),
                    let tab = anObject as? Tab else { return }
                self?.configureThumbnail(cell, withTab: tab)
            })
        case .move:
            blockOperations.append(BlockOperation { [weak self] in
                guard let cv = self?.collectionView,
                    let ip = indexPath,
                    let cell = cv.cellForItem(at: ip),
                    let tab = anObject as? Tab else { return }
                self?.configureThumbnail(cell, withTab: tab)
                cv.moveItem(at: ip, to: newIndexPath!)
            })
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        UIView.performWithoutAnimation {
            for operation: BlockOperation in self.blockOperations { operation.start() }
            self.blockOperations.removeAll(keepingCapacity: false)
            if let ip = self.currentIndexPath {
                self.cardStackLayout.selectedIndexPath = ip
            }
        }

//        collectionView!.performBatchUpdates({
//            for operation: BlockOperation in self.blockOperations { operation.start() }
//        }, completion: { finished in
//            self.blockOperations.removeAll(keepingCapacity: false)
//            if let ip = self.currentIndexPath {
//                self.cardStackLayout.selectedIndexPath = ip
//            }
//        })
    }

}

// MARK: - UICollectionViewDataSource
extension TabSwitcherViewController {

    override func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }

    override func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Configure the cells
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)
        let tab = fetchedResultsController.object(at: indexPath)
        configureThumbnail(cell, withTab: tab)
        return cell
    }

    func configureThumbnail(_ cell: UICollectionViewCell, withTab tab: Tab) {
        if let thumb = cell as? DismissableTabCell {
            thumb.setTab(tab)
            thumb.closeTabCallback = closeTab
            thumb.dismissCallback = dismissTab
            thumb.swipeCallback = swipeTab
        } else {
            print("cant configure thumb")
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showTab(fetchedResultsController.object(at: indexPath)) {
            collectionView.deselectItem(at: indexPath, animated: true)
        }
    }
    
    var thumbSize: CGSize {
        if view.frame.width > 400 {
            let ratio = view.frame.width / (view.frame.height - Const.toolbarHeight - Const.statusHeight )
            let w = view.frame.width / 2 - 16
            return CGSize(width: w, height: w / ratio )
        }
        return CGSize(width: view.frame.width - sectionInsets.left - sectionInsets.right, height: THUMB_H)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension TabSwitcherViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        return thumbSize
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForItem section: Int) -> UIEdgeInsets {
        return sectionInsets
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int) -> UIEdgeInsets {
        return sectionInsets
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 8
    }
}
