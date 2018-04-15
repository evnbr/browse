//
//  HistoryTreeLayout.swift
//  browse
//
//  Created by Evan Brooks on 04/14/18.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit


class HistoryTreeLayout: UICollectionViewFlowLayout {
    var attributesList = [ UICollectionViewLayoutAttributes ]()
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        guard let cv = collectionView else { return .zero }
        return CGSize(
            width: CGFloat(cv.numberOfItems(inSection: 0) * 130),
            height: 300)
    }
    
    override init() {
        super.init()
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        if newBounds == collectionView?.bounds { return false }
        return true
    }
    
    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        let count = cv.numberOfItems(inSection: 0)
        
        attributesList = (0..<count).map { i -> UICollectionViewLayoutAttributes in
            let indexPath = IndexPath(item: i, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.bounds = CGRect(x: 0, y: 0, width: 240, height: 420)
            attributes.center = CGPoint(x: i * 130, y: 160)
            attributes.transform = CGAffineTransform(scale: 0.5)
            
            return attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList.filter { attrs -> Bool in
            return rect.intersects(attrs.frame.insetBy(dx: -40, dy: -40)) && attrs.alpha > 0 && !attrs.isHidden
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.count > 0, // sometimes this method sent nil paths - why?
            indexPath.row < attributesList.count else { return nil }
        return attributesList[indexPath.row]
    }
}
