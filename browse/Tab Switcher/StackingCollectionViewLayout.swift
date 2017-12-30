//
//  StackingCollectionViewLayout.swift
//  browse
//
//  Created by Evan Brooks on 10/5/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

let itemSpacing : CGFloat = 200
let itemHeight : CGFloat = THUMB_H

class StackingCollectionViewLayout: UICollectionViewFlowLayout {
    
    var attributesList = [UICollectionViewLayoutAttributes]()
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: collectionView!.bounds.width,
                      height: CGFloat(collectionView!.numberOfItems(inSection: 0)) * itemSpacing + (itemHeight - itemSpacing) + 240)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func prepare() {
        super.prepare()
        
        let topScrollPos = Const.shared.statusHeight + 12 //60
        let scrollPos = collectionView!.contentOffset.y
        
        let count = collectionView!.numberOfItems(inSection: 0)
        attributesList = (0..<count).map { (i)
            -> UICollectionViewLayoutAttributes in
            // 1
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            
            var newCenter = CGPoint(
                x: collectionView!.center.x,
                y: 120.0 + collectionView!.center.y + CGFloat(i) * itemSpacing
            )
            
            attributes.bounds.size = CGSize(
                width: collectionView!.bounds.width - THUMB_INSET * 2,
                height: itemHeight
            )
            

            let distFromTop = newCenter.y - (attributes.bounds.height / 2) - scrollPos - topScrollPos

//            if distFromTop < 0 {
//                intendedFrame.origin.y = intendedFrame.origin.y - distFromTop * 0.9
////                let s = 1 - pctOver * 0.05
////                attributes.transform = CGAffineTransform(scaleX: s, y: s)
//            }
            
            let pct = distFromTop.progress(from: -400, to: 600).clip().reverse()
            let s = (pct * pct * 0.15).reverse()
//            attributes.transform = CGAffineTransform(scaleX: s, y: s)
            attributes.bounds.size.width *= s
            
            newCenter.y -= distFromTop * 0.85 * pct

            if i < count - 1 {
                attributes.alpha = 1 - ( pct * pct * pct )
            }
            attributes.center = newCenter
            attributes.zIndex = i * 20

//            var transform = CATransform3DIdentity
//            transform.m34 = 1 / -500
//            transform = CATransform3DRotate(transform, CGFloat(-5 * Double.pi / 180), 1, 0, 0)
//            attributes.transform3D = transform
            
            return attributes
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let limit = (collectionView!.bounds.width - THUMB_INSET * 2) * 0.85
        return attributesList.filter({ attr -> Bool in
            return attr.alpha > 0.1
        })
//        return super.layoutAttributesForElements(in: rect)
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesList[indexPath.row]
//        return super.layoutAttributesForItem(at: indexPath)
    }

}
