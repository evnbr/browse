//
//  HistoryTreeViewController.swift
//  browse
//
//  Created by Evan Brooks on 6/3/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData

class HistoryTreeViewController: UICollectionViewController, UIViewControllerTransitioningDelegate {

    var _fetchedResultsController: NSFetchedResultsController<Visit>? = nil
    var blockOperations: [BlockOperation] = []

    let reuseIdentifier = "TreeCell"
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    init() {
        let layout = HistoryTreeLayout()
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let cv = self.collectionView else { return }
            cv.contentOffset.x = cv.maxScrollX
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
    
    func saveContext() {
        let context = self.fetchedResultsController.managedObjectContext
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            print("Unresolved error \(nserror), \(nserror.userInfo)")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

extension HistoryTreeViewController: NSFetchedResultsControllerDelegate {
    // MARK: - Fetched results controller
    
    var fetchedResultsController: NSFetchedResultsController<Visit> {
        if let existing = _fetchedResultsController { return existing }
        
        let fetchRequest: NSFetchRequest<Visit> = Visit.fetchRequest()
        fetchRequest.fetchBatchSize = 20
        fetchRequest.sortDescriptors = [ NSSortDescriptor(key: "date", ascending: true) ]
        
        let frc = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: HistoryManager.shared.persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: "AllVisits")
        frc.delegate = self
        _fetchedResultsController = frc
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
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
                self?.configureCell(cell, with: anObject as! Visit)
            })
        case .move:
            blockOperations.append(BlockOperation { [weak self] in
                guard let cv = self?.collectionView, let ip = indexPath, let cell = cv.cellForItem(at: ip) else { return }
                self?.configureCell(cell, with: anObject as! Visit)
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
extension HistoryTreeViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: reuseIdentifier,
            for: indexPath)
        // Configure the cells
        
        let visit = fetchedResultsController.object(at: indexPath)
        configureCell(cell, with: visit)
        
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

