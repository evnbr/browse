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

class HistoryTreeViewController: UICollectionViewController, UIViewControllerTransitioningDelegate, TreeDataSource {

//    var _fetchedResultsController: NSFetchedResultsController<Visit>? = nil
    var blockOperations: [BlockOperation] = []
    let treeMaker: TreeMaker

    let reuseIdentifier = "TreeCell"
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    init() {
        let layout = TreeMakerLayout()
        treeMaker = TreeMaker(layout: layout)
        super.init(collectionViewLayout: layout)
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
            top: Const.statusHeight,
            left: 0,
            bottom: Const.toolbarHeight,
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
}

// MARK: - UICollectionViewDataSource
extension HistoryTreeViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("tree with \(treeMaker.nodeCount) nodes")
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
            cell.label.text = visit.date?.description
        }
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if let cell = collectionView.cellForItem(at: indexPath) as? VisitCell {
            cell.unSelect()
        }
        if let selectedTab = treeMaker.object(at: indexPath)?.isCurrentVisitOf,
            let browser = presentingViewController as? BrowserViewController,
            browser.currentTab !== selectedTab {
            browser.setTab(selectedTab)
        }
        self.dismiss(animated: false, completion: nil)
    }
}
