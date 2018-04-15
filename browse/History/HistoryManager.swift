//
//  HistoryManager.swift
//  browse
//
//  Created by Evan Brooks on 3/15/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData
import WebKit

class HistoryManager: NSObject {
    static let shared = HistoryManager()
    
    private var snapshotCache: [ UUID : UIImage ] = [:]
    private var historyIDMap: [ WKBackForwardListItem : NSManagedObjectID ] = [:]

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HistoryModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error loading stores: \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(mergeChangeIntoMainContext(notif:)),
            name: .NSManagedObjectContextDidSave,
            object: nil)
    }
    
    @objc func mergeChangeIntoMainContext(notif: Notification) {
        // this wasn't running on main thread before and may have been crashing
        DispatchQueue.main.async {
            self.persistentContainer.viewContext.mergeChanges(fromContextDidSave: notif)
        }
    }
    
    func existingVisit(from item: WKBackForwardListItem, in context: NSManagedObjectContext) -> Visit? {
        guard let id = historyIDMap[item] else { return nil }
        do {
            return try context.existingObject(with: id) as? Visit
        }
        catch let error {
            print(error)
            return nil
        }
    }
    
    func existingSite(for url: URL, in context: NSManagedObjectContext) -> Site? {
        let request = NSFetchRequest<Site>(entityName: "Site")
        request.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        do {
            let results = try context.fetch(request)
            return results.first
        } catch let error {
            print(error)
            return nil
        }
    }
    
    var isSyncing = false
    func sync(tab mainThreadTab: Tab, with list: WKBackForwardList) {
        if isSyncing { return }
        guard let wkItem = list.currentItem else { return }
        
        if mainThreadTab.currentVisit?.objectID == historyIDMap[wkItem]
        && mainThreadTab.currentVisit?.url == wkItem.url
        && mainThreadTab.currentVisit?.title == wkItem.title {
            // unchanged, don't need to hit core data
            return
        }

        persistentContainer.performBackgroundTask { ctx in
            guard let tab = try? ctx.existingObject(with: mainThreadTab.objectID) as! Tab else {
                print("tab doesn't exist on bg context")
                return
            }
            self.isSyncing = true

            if let prevVisit = self.existingVisit(from: wkItem, in: ctx) {
                // Move to this context, update title and url
                // print("update visit")
                if let title = wkItem.title, title != "" {
                    prevVisit.title = title
                }
                prevVisit.url = wkItem.url
                
                tab.currentVisit?.isCurrentVisitOf = nil
                tab.currentVisit = prevVisit
                prevVisit.isCurrentVisitOf = tab
            }
            else {
                // Create a new entry
                // print("new visit")
                let newVisit = self.addVisit(from: wkItem, parent: nil, in: ctx)!
                
                if let backWKItem = list.backItem,
                    let backVisit = self.existingVisit(from: backWKItem, in: ctx),
                    backVisit == tab.currentVisit {
                    // We went forward, link these pages together
                    newVisit.backItem = tab.currentVisit
                    tab.currentVisit?.addToForwardItems(newVisit)
                }
                tab.currentVisit?.isCurrentVisitOf = nil
                tab.currentVisit = newVisit
                newVisit.isCurrentVisitOf = tab
            }

            var site: Site? = nil
            if let currentSite = tab.currentVisit?.site, currentSite.url == wkItem.url {
                site = currentSite
            }
            else if let existingSite = self.existingSite(for: wkItem.url, in: ctx) {
                site = existingSite
            }
            else if let newSite = self.addSite(url: wkItem.url, title: wkItem.title, in: ctx) {
                site = newSite
            }
            else {
                fatalError("couldn't create a new site")
            }
        
            if let visit = tab.currentVisit, let site = site {
                if let title = wkItem.title, title != "" {
                    site.title = title
                }
                if visit.site !== site {
                    let oldSite = visit.site
                    oldSite?.removeFromVisits(visit)
                    visit.site = site
                    site.addToVisits(visit)
                }
                if let count = site.visits?.count {
                    site.visitCount = Int32(count)
                }
            }
            if tab.currentVisit!.uuid == nil {
                // sanity check
                fatalError("current visit not valid")
            }
            
            self.save(context: ctx)
            self.historyIDMap[wkItem] = tab.currentVisit!.objectID // id is temp until saved
            self.isSyncing = false
        }
    }
    
    // Convert wkwebview history item
    func addVisit(from item: WKBackForwardListItem, parent: Visit?, in context: NSManagedObjectContext) -> Visit? {
        return addVisit(parent: parent, url: item.url, title: item.title, in: context)
    }
    
    // Convert and save history item
    func addVisit(parent: Visit?, url: URL, title: String?, in context: NSManagedObjectContext) -> Visit? {
        let visit = Visit(context: context)
        visit.date = Date()
        visit.uuid = UUID()
        visit.url = url
        visit.title = title ?? url.host ?? url.absoluteString
        visit.backItem = parent
        return visit
    }
    
    func addSite(url: URL, title: String?, in context: NSManagedObjectContext) -> Site? {
        let site = Site(context: context)
        site.title = title ?? url.host ?? url.absoluteString
        site.url = url
        return site
    }
    
    func save(context: NSManagedObjectContext) {
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error saving: \(nserror.localizedDescription)")
                print("\(nserror.userInfo)")
            }
        }
    }
}

// Convenience to get Visit from webview
extension WKBackForwardListItem {
    var visit : Visit? {
        let ctx = HistoryManager.shared.persistentContainer.viewContext
        let existVisit = HistoryManager.shared.existingVisit(from: self, in: ctx)
        return existVisit
    }
}

// Typeahead fetching
extension HistoryManager {
    private func fetchItemsContaining(_ str: String, completion: @escaping ([HistorySearchResult]?) -> () ) {
        guard str.count > 0 else { return }
        persistentContainer.performBackgroundTask { ctx in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Site")
            
            // todo: doesn't handle spaces
            var predicates : [NSPredicate] = []
            for word in str.split(separator: " ") {
                if word.count < 2 { continue }
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "url CONTAINS[cd] %@", ".\(word)"), // www.WOrd.com
                    NSPredicate(format: "url CONTAINS[cd] %@", "/\(word)"), // prot://WOrd.com
                    NSPredicate(format: "title CONTAINS[cd] %@", " \(word)"), // The WOrd
                ]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [ NSSortDescriptor(key: "visitCount", ascending: false) ]
            
            // Distinct on URL or Title else full of dupes
            request.propertiesToFetch = ["url", "title", "visitCount"]
            request.returnsDistinctResults = true
            request.resultType = .dictionaryResultType

            // Should be enough to filter more carefully later
            request.returnsObjectsAsFaults = false
            request.fetchBatchSize = 12
            request.fetchLimit = 12
            do {
                let results = try ctx.fetch(request)
                var cleanResults : [ HistorySearchResult ] = []
                for result in results {
                    if let dict = result as? NSDictionary,
                       let title = dict["title"] as? String,
                       let count = dict["visitCount"] as? Int,
                       let url = dict["url"] as? URL {
                        cleanResults.append(HistorySearchResult(
                            title: title, url: url, visitCount: count))
                    }
                }
                completion(cleanResults)
            } catch let error{
                completion(nil)
                print(error)
            }
        }
    }
        
    func findItemsMatching(_ str: String, completion: @escaping ([HistorySearchResult]?) -> () ) {
        fetchItemsContaining(str) { completion($0) }
    }
}

struct HistorySearchResult {
    let title: String
    let url: URL
    let visitCount: Int
}

// Deal with snapshots
extension HistoryManager {
    func snapshot(for id: UUID) -> UIImage? {
        if let cached = snapshotCache[id] { return cached }
        return loadSnapshotFromFile(id)
    }
    
    func setSnapshot(_ image: UIImage, for item: Visit) {
        guard let uuid = item.uuid else {
            print("set item has no uuid: \(item)")
            return
        }
        snapshotCache[uuid] = image
        writeSnapshotToFile(image, id: uuid)
    }
    
    func loadSnapshotFromFile(_ id: UUID) -> UIImage? {
        guard let dir = FileManager.defaultDirURL else { return nil }
        return UIImage(contentsOfFile:
            URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(id.uuidString).png").path)
    }
    
    func writeSnapshotToFile(_ image: UIImage, id: UUID) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let data = UIImagePNGRepresentation(image),
                let dir = FileManager.defaultDirURL
                else { return }
            do {
                try data.write(to: dir.appendingPathComponent("\(id.uuidString).png"))
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

fileprivate extension FileManager {
    static var defaultDirURL : URL? {
        return try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
}
