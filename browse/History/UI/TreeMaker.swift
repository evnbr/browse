//
//  TreeMaker.swift
//  browse
//
//  Created by Evan Brooks on 4/20/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit
import CoreData

struct TreePosition {
    let x: Int
    let y: Int
    
    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }
}

class TreeMaker : NSObject {
    private let initialMaxDepth = 10
    private let viewContext = HistoryManager.shared.persistentContainer.viewContext
    
    private var layout: TreeMakerLayout
    private var nodeIDs: [IndexPath : NSManagedObjectID] = [:]
    private var cellPositions: [NSManagedObjectID : TreePosition] = [:]
    
    var nodeCount: Int {
        return nodeIDs.count
    }
    
    var gridSize : CGSize = .zero
    
    init(layout: TreeMakerLayout) {
        self.layout = layout
        super.init()
    }
    
    func object(at ip: IndexPath) -> Visit? {
        guard let id = nodeIDs[ip] else {
            print("Unknown Indexpath: \(ip)")
            return nil
        }
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
    
    private func moveThread(tabs originalTabs: [Tab], to ctx: NSManagedObjectContext) -> [Tab] {
        var tabs: [Tab] = []
        for tab in originalTabs {
            do {
                let bgTab = try ctx.existingObject(with: tab.objectID) as! Tab
                tabs.append(bgTab)
            } catch {
                print("Can't find tab on bg thread: \(error.localizedDescription)")
            }
        }
        return tabs
    }
    
    private func dateSorter(_ a: Visit, _ b: Visit) -> Bool {
        guard let ad = a.date, let bd = b.date else { return false }
        return ad < bd
    }
    
    private func traverseTrees(from roots: [Visit]) {
        var currentY: Int = 0
        var currentDepth: Int = 0
        var maxDepth: Int = 0
        
        func traverse(_ node: Visit) {
            let subtreeStartY = currentY
            let pos = TreePosition(x: currentDepth, y: subtreeStartY)
            self.addVisit(node, at: pos)
            
            if let children = node.forwardItems?.allObjects as? [Visit] {
                currentDepth += 1
                if currentDepth > maxDepth { maxDepth = currentDepth }
                for child in children.sorted(by: dateSorter) {
                    traverse(child)
                }
                currentDepth -= 1
            }
            if subtreeStartY == currentY {
                currentY += 1
            }
        }
        
        roots.sorted(by: dateSorter).forEach { traverse($0) }
        self.gridSize = CGSize(width: maxDepth, height: currentY)
    }
    
    func setTabs(_ mainThreadTabs: [Tab]) {
        DispatchQueue.global(qos: .userInitiated).async {
            let context = HistoryManager.shared.persistentContainer.newBackgroundContext()
            let tabs = self.moveThread(tabs: mainThreadTabs, to: context)
            let currentVisits: [Visit] = tabs.map { $0.currentVisit! }
            let currentRoots: [Visit] = currentVisits.map { visit in
                var root = visit
                var backDepth = 0
                while let backItem = root.backItem, backDepth < self.initialMaxDepth {
                    root = backItem
                    backDepth += 1
                }
                return root
            }
            
            self.traverseTrees(from: currentRoots)
            DispatchQueue.main.async {
                self.layout.invalidateLayout()
            }
        }
    }
}
