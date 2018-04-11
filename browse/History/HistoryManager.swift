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
    private var historyVisitMap: [ WKBackForwardListItem : Visit ] = [:]

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "HistoryModel")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()
    
    func visit(from item: WKBackForwardListItem) -> Visit? {
        return historyVisitMap[item]
    }
    
    func existingSite(for url: URL) -> Site? {
        let ctx = persistentContainer.viewContext
        let request = NSFetchRequest<Site>(entityName: "Site")
        request.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        do {
            let results = try ctx.fetch(request)
            return results.first
        } catch let error{
            print(error)
            return nil
        }
    }
    
    func sync(tab: Tab, with list: WKBackForwardList) {
        guard let currentWKItem = list.currentItem else { return }
        
        if let prevVisit = visit(from: currentWKItem) {
            // Update title and url
            if let title = currentWKItem.title, title != "" {
                prevVisit.title = title
            }
            prevVisit.url = currentWKItem.url
            tab.currentVisit = prevVisit
        }
        else {
            // Create a new entry
            let newVisit = addVisit(from: currentWKItem, parent: nil)
            if let backWKItem = list.backItem,
                let backItem = visit(from: backWKItem),
                backItem == tab.currentVisit {
                // We went forward, link these pages together
                newVisit?.backItem = tab.currentVisit
                tab.currentVisit?.addToForwardItems(newVisit!)
            }
            historyVisitMap[currentWKItem] = newVisit
            tab.currentVisit = newVisit
        }
        
        var site: Site? = nil
        if let currentSite = tab.currentVisit?.site, currentSite.url == currentWKItem.url {
            site = currentSite
        }
        else if let existingSite = existingSite(for: currentWKItem.url) {
            site = existingSite
        }
        else if let newSite = addSite(url: currentWKItem.url, title: currentWKItem.title) {
            site = newSite
        }
        
        if let visit = tab.currentVisit, let site = site {
            visit.site = site
            if let title = currentWKItem.title, title != "" {
                site.title = title
            }
            site.addToVisits(visit)
            if let count = site.visits?.count {
                site.visitCount = Int32(count)
            }
        }
        
        saveContext()
    }
    
    // Convert wkwebview history item
    func addVisit(from item: WKBackForwardListItem, parent: Visit?) -> Visit? {
        return addVisit(parent: parent, url: item.url, title: item.title)
    }
    
    // Convert and save history item
    func addVisit(parent: Visit?, url: URL, title: String?) -> Visit? {
        let context = persistentContainer.viewContext
        
        let visit = Visit(context: context)
        visit.firstVisit = Date()
        visit.uuid = UUID()
        visit.url = url
        visit.title = title ?? "Untitled"
        visit.backItem = parent
        
        return visit
    }
    func addSite(url: URL, title: String?) -> Site? {
        let context = persistentContainer.viewContext

        let site = Site(context: context)
        site.title = title
        site.url = url
        
        return site
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump // dedupe sites
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nserror = error as NSError
                print("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}

// Convenience to get Visit from webview
extension WKBackForwardListItem {
    var visit : Visit? {
        return HistoryManager.shared.visit(from: self)
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
    func snapshot(for item: Visit) -> UIImage? {
        guard let id = item.uuid else { return nil }
        if let cached = snapshotCache[id] { return cached }
        return loadSnapshotFromFile(id)
    }
    
    func setSnapshot(_ image: UIImage, for item: Visit) {
        guard let uuid = item.uuid else { return }
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
