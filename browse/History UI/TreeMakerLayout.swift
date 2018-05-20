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
    
    private let itemScale: CGFloat = 0.5
    private let itemSize = CGSize(width: 120 * 2, height: 240 * 2)
    private let itemSpacing = CGPoint(x: 180, y: 280)
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }
        guard let treeMaker = (cv.dataSource as? TreeDataSource)?.treeMaker else { return .zero }

        let gridSize = treeMaker.gridSize
        return CGSize(
            width:  gridSize.width  * itemSpacing.x + cv.bounds.width,
            height: gridSize.height * itemSpacing.y + cv.bounds.height)
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
            attributes.bounds = CGRect(origin: .zero, size: itemSize)
            attributes.transform = CGAffineTransform(scale: itemScale)

            if let pt = treeMaker.position(for: indexPath)?.point {
                attributes.center = CGPoint(
                    x: margin.x + pt.x * itemSpacing.x,
                    y: margin.y + pt.y * itemSpacing.y)
                
                if let parentPt = treeMaker.parentPosition(for: indexPath)?.point {
                    let dX = pt.x - parentPt.x - 1
                    let dY = pt.y - parentPt.y
                    let size = CGSize(width: (60 + dX * itemSpacing.x) * 2, height: (dY * itemSpacing.y) * 2)
                    attributes.connectorOffset = size
                }
            }

            return attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList
        return attributesList.filter { attrs -> Bool in
            let cardFrame = attrs.frame.insetBy(dx: -abs((attrs.connectorOffset ?? .zero).width), dy: -40)
//            let connector = attrs.connectorOffset ?? .zero
//            print(connector)
//            let connectorFrame = CGRect(
//                x: cardFrame.origin.x - connector.width,
//                y: cardFrame.origin.y,
//                width: connector.width,
//                height: connector.width
//            )
            return rect.intersects(cardFrame)
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.count > 0, // sometimes this method sent nil paths - why?
            indexPath.row < attributesList.count else { return nil }
        return attributesList[indexPath.row]
    }
}
