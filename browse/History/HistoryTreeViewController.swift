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

struct TreePosition {
    let x: Int
    let y: Int
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

class TreeMaker : NSObject {
    private let initialMaxDepth = 1
    private let viewContext = HistoryManager.shared.persistentContainer.viewContext
    
    private var layout: HistoryTreeLayout
    private var nodeIDs: [IndexPath : NSManagedObjectID] = [:]
    private var cellPositions: [NSManagedObjectID : TreePosition] = [:]
    
    var nodeCount: Int {
        return nodeIDs.count
    }
    
    var gridSize : CGSize = .zero
    
    init(layout: HistoryTreeLayout) {
        self.layout = layout
        super.init()
    }
    
    func object(at ip: IndexPath) -> Visit? {
        guard let id = nodeIDs[ip] else { return nil }
        do {
            return try viewContext.existingObject(with: id) as? Visit
        }
        catch {
            print("Can't find visit on main thread: \(error.localizedDescription)")
            return nil
        }
    }
    
    func position(for ip: IndexPath) -> TreePosition? {
        guard let id = nodeIDs[ip] else { return nil }
        return cellPositions[id]
    }
    
    func addVisit(_ visit: Visit, at position: TreePosition) {
        let ip = IndexPath(item: nodeCount, section: 0)
        nodeIDs[ip] = visit.objectID
        cellPositions[visit.objectID] = position
    }
    
    func setTabs(_ mainThreadTabs: [Tab]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let ctx = HistoryManager.shared.persistentContainer.newBackgroundContext()
            var tabs: [Tab] = []
            for tab in mainThreadTabs {
                do {
                    let bgTab = try ctx.existingObject(with: tab.objectID) as! Tab
                    tabs.append(bgTab)
                } catch {
                    print("Can't find tab on bg thread: \(error.localizedDescription)")
                }
            }
            let currentVisits: [Visit] = tabs.map { $0.currentVisit! }
            let currentRoots: [Visit] = currentVisits.map { visit in
                var root = visit
                var depth = 0
                while let backItem = root.backItem, depth < self.initialMaxDepth {
                    root = backItem
                    depth += 1
                }
                return root
            }
            
            var maxY: Int = 0
            for root in currentRoots {
                let branchY = maxY
                let pos = TreePosition(x: 0, y: branchY)
                self.addVisit(root, at: pos)
                
                if let children = root.forwardItems?.allObjects as? [Visit] {
                    var childY = branchY
                    for child in children {
                        let pos = TreePosition(x: 1, y: childY)
                        self.addVisit(child, at: pos)
                        childY += 1
                    }
                    if children.count > 1 {
                        maxY += children.count - 1
                    }
                } else {
                    maxY += 1
                }
            }
            self.gridSize = CGSize(width: 2, height: maxY + 1)
            
            DispatchQueue.main.async {
                self.layout.invalidateLayout()
            }
        }
    }
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
        let layout = HistoryTreeLayout()
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
        self.dismiss(animated: true, completion: nil)
    }
}
