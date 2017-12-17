//
//  StackingCollectionViewLayout.swift
//  browse
//
//  Created by Evan Brooks on 10/5/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import UIKit

let itemSpacing : CGFloat = 160
let itemHeight : CGFloat = THUMB_H

class StackingCollectionViewLayout: UICollectionViewFlowLayout {
    
    var attributesList = [UICollectionViewLayoutAttributes]()
    
    override var collectionViewContentSize: CGSize {
        return CGSize(width: collectionView!.bounds.width,
                      height: CGFloat(collectionView!.numberOfItems(inSection: 0)) * itemSpacing + (itemHeight - itemSpacing))
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }
    
    override func prepare() {
        super.prepare()
        
        let topScrollPos = Const.shared.statusHeight
        let scrollPos = collectionView!.contentOffset.y

        attributesList = (0..<collectionView!.numberOfItems(inSection: 0)).map { (i)
            -> UICollectionViewLayoutAttributes in
            // 1
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            
            var intendedFrame = CGRect(
                origin: CGPoint(
                    x: THUMB_INSET ,
                    y: CGFloat(i) * itemSpacing
                ),
                size: CGSize(
                    width: collectionView!.bounds.width - THUMB_INSET * 2,
                    height: itemHeight
                )
            )
            

            let distFromTop = intendedFrame.origin.y - scrollPos - topScrollPos
            let pctOver = abs(distFromTop) / 200

            if distFromTop < 0 {
                intendedFrame.origin.y = intendedFrame.origin.y - distFromTop * 0.9
                let s = 1 - pctOver * 0.05
                attributes.transform = CGAffineTransform(scaleX: s, y: s)
            }
//
//            if distFromTop < 600 {
//                let pctToTop = clip(max(0, abs(distFromTop)) / 400)
//                print(pctToTop)
//
//                let s = 0.9 + pctToTop * 0.1
//                attributes.transform = CGAffineTransform(scaleX: s, y: s)
//            }


            attributes.frame = intendedFrame
            attributes.zIndex = i * 20

//            var transform = CATransform3DIdentity
//            transform.m34 = 1 / -500
//            transform = CATransform3DRotate(transform, CGFloat(-5 * Double.pi / 180), 1, 0, 0)
//            attributes.transform3D = transform
            
            return attributes
        }
    }
    
    func elasticLimit(_ val : CGFloat) -> CGFloat {
        let resist = 1 - log10(1 + abs(val) / 150) // 1 ... 0.5
        return val * resist
    }

    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return attributesList
//        return super.layoutAttributesForElements(in: rect)
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesList[indexPath.row]
//        return super.layoutAttributesForItem(at: indexPath)
    }

}
