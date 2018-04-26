//
//  HistoryTreeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData

protocol TreeDataSource {
    var treeMaker: TreeMaker { get }
}

class HistoryTreeViewController: UICollectionViewController, TreeDataSource {

//    var _fetchedResultsController: NSFetchedResultsController<Visit>? = nil
    var blockOperations: [BlockOperation] = []
    let treeMaker: TreeMaker
    let zoomTransition = HistoryZoomAnimatedTransitioning()
    let reuseIdentifier = "TreeCell"
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    init() {
        let layout = TreeMakerLayout()
        treeMaker = TreeMaker(layout: layout)
        super.init(collectionViewLayout: layout)
        transitioningDelegate = self
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = ""
        view.backgroundColor = .black

        view.clipsToBounds = false
        collectionView?.delaysContentTouches = false
        collectionView?.scrollIndicatorInsets.top = Const.statusHeight
        collectionView?.indicatorStyle = .white
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
        collectionView?.register(VisitCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView?.backgroundColor = .black
        
        collectionView?.contentInset = UIEdgeInsets(
            top: 0,// Const.statusHeight,
            left: 0,
            bottom: 0, //Const.toolbarHeight,
            right: 0
        )
        
        collectionView?.contentInsetAdjustmentBehavior = .never        
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
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func centerIndexPath(_ ip: IndexPath) {
        collectionView!.scrollToItem(
            at: ip,
            at: [ .centeredVertically, .centeredHorizontally ],
            animated: false)
    }
}

extension HistoryTreeViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        zoomTransition.direction = .present
        return zoomTransition
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        zoomTransition.direction = .dismiss
        return zoomTransition
    }
}

// MARK: - UICollectionViewDataSource
extension HistoryTreeViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return treeMaker.nodeCount
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath)
        // Configure the cells
        if let visit = treeMaker.object(at: indexPath) {
            configureCell(cell, with: visit)
        }
        
        return cell
    }
    
    func configureCell(_ cell: UICollectionViewCell, with visit: Visit) {
        if let cell = cell as? VisitCell {
            cell.setVisit(visit)
//            cell.label.text = visit.date?.description
        }
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let cell = collectionView.cellForItem(at: indexPath) as? VisitCell {
            cell.unSelect()
        }
        if let visit = treeMaker.object(at: indexPath),
            let tab = visit.tab,
            let wkItem = HistoryManager.shared.wkListItem(for: visit),
            let browser = presentingViewController as? BrowserViewController {
            
            if browser.webView.backForwardList.backList.contains(wkItem)
                || browser.webView.backForwardList.forwardList.contains(wkItem) {
            }
            
            browser.setTab(tab)
            browser.setVisit(visit, wkItem: wkItem)
            
            zoomTransition.targetIndexPath = indexPath
            self.dismiss(animated: true, completion: {
                self.zoomTransition.targetIndexPath = nil
            })
        }
    }
}
