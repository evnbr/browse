//
//  TreeMakerLayout.swift
//  browse
//
//  Created by Evan Brooks on 04/14/18.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

class TreeConnectorAttributes: UICollectionViewLayoutAttributes {
    var connectorOffset: CGSize? = nil
    
    override func copy(with zone: NSZone?) -> Any {
        let copy = super.copy(with: zone) as! TreeConnectorAttributes
        copy.connectorOffset = self.connectorOffset
        return copy
    }
    
    override func isEqual(_ object: Any?) -> Bool {
        if let rhs = object as? TreeConnectorAttributes {
            if connectorOffset != rhs.connectorOffset {
                return false
            }
            return super.isEqual(object)
        } else {
            return false
        }
    }
}

class TreeMakerLayout: UICollectionViewLayout {
    var attributesList = [ TreeConnectorAttributes ]()
    var spacing = CGPoint(x: 180, y: 240)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }
        guard let treeMaker = (cv.dataSource as? TreeDataSource)?.treeMaker else { return .zero }

        let size = treeMaker.gridSize
        return CGSize(
            width:  size.width  * spacing.x + cv.bounds.width,
            height: size.height * spacing.y + cv.bounds.height)
    }
    
    override init() {
        super.init()
    }
    
    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        guard let treeMaker = (cv.dataSource as? TreeDataSource)?.treeMaker else { return }

        let count = cv.numberOfItems(inSection: 0)
        let margin = CGPoint(
            x: cv.bounds.size.width * 0.5,
            y: cv.bounds.size.height * 0.5)
        
        attributesList = (0..<count).map { i -> TreeConnectorAttributes in
            let indexPath = IndexPath(item: i, section: 0)
            let attributes = TreeConnectorAttributes(forCellWith: indexPath)
            attributes.bounds = CGRect(x: 0, y: 0, width: 240, height: 420)
            attributes.transform = CGAffineTransform(scale: 0.5)

            if let pt = treeMaker.position(for: indexPath)?.point {
                attributes.center = CGPoint(
                    x: margin.x + pt.x * spacing.x,
                    y: margin.y + pt.y * spacing.y)
                
                if let parentPt = treeMaker.parentPosition(for: indexPath)?.point {
                    let dX = pt.x - parentPt.x - 1
                    let dY = pt.y - parentPt.y
                    let size = CGSize(width: (60 + dX * spacing.x) * 2, height: (dY * spacing.y) * 2)
                    attributes.connectorOffset = size
                }
            }

            return attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList.filter { attrs -> Bool in
            return rect.intersects(attrs.frame.insetBy(dx: -40, dy: -40))
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.count > 0, // sometimes this method sent nil paths - why?
            indexPath.row < attributesList.count else { return nil }
        return attributesList[indexPath.row]
    }
}
