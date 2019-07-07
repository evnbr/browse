//
//  TabManager.swift
//  browse
//
//  Created by Evan Brooks on 7/6/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData

class TabManager: NSObject {
    var _fetchedResultsController: NSFetchedResultsController<Tab>?

    var tabCount: Int {
        return fetchedResultsController.sections?.first?.numberOfObjects ?? 0
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
    
    func lastTab() -> Tab {
        let tab = fetchedResultsController.object(at: IndexPath(item: 0, section: 0))
        return tab
    }

}


extension TabManager: NSFetchedResultsControllerDelegate {
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
}
