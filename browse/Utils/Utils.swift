//
//  Utils.swift
//  browse
//
//  Created by Evan Brooks on 12/25/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation

// MARK: - Origami Patches

func clip(_ val: CGFloat) -> CGFloat {
    return max(0, min(1, val))
}

func blend(from: CGFloat, to: CGFloat, by pct: CGFloat) -> CGFloat {
    return from + (to - from) * pct
}

func progress(value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
    let dist = from - to
    let amt = from - value
    return amt / dist
}

func elasticLimit(_ val: CGFloat, constant: CGFloat = 150) -> CGFloat {
    let resist = 1 - log10(1 + abs(val) / constant) // 1 ... 0.5
    return val * resist
}

// MARK: - Origami Patch Extensions

extension CGFloat {

    func clip() -> CGFloat {
        return Swift.max(0, Swift.min(1, self))
    }
    func limit(min: CGFloat, max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, self))
    }

    func progress(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
        let total = from - to
        let amt = from - self
        return amt / total
    }

    func reverse() -> CGFloat {
        return 1 - self
    }
}

extension CGPoint {
    func distanceTo(_ otherPoint: CGPoint) -> CGFloat {
        let xDist = otherPoint.x - self.x
        let yDist = otherPoint.y - self.y
        return sqrt((xDist * xDist) + (yDist * yDist))
    }
}

// MARK: - Transform
extension CGAffineTransform {
    init(scale s: CGFloat) {
        self.init(scaleX: s, y: s)
    }

    var xScale: CGFloat {
        return a
//        return sqrt(a * a + c * c);
    }

    func scaledBy(_ newScale: CGFloat) -> CGAffineTransform {
        return self.scaledBy(x: newScale, y: newScale)
    }
}

// MARK: - Constraints
extension UIView {
    func addSubview(_ child: UIView, constraints: [NSLayoutConstraint]) {
        addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(constraints)
    }
}

func constrain4(_ A: UIView, _ B: UIView) {
    A.topAnchor.constraint(equalTo: B.topAnchor).isActive = true
    A.bottomAnchor.constraint(equalTo: B.bottomAnchor).isActive = true
    A.leftAnchor.constraint(equalTo: B.leftAnchor).isActive = true
    A.rightAnchor.constraint(equalTo: B.rightAnchor).isActive = true
}

func constrainTop3(_ A: UIView, _ B: UIView) {
    A.topAnchor.constraint(equalTo: B.topAnchor).isActive = true
    A.leftAnchor.constraint(equalTo: B.leftAnchor).isActive = true
    A.rightAnchor.constraint(equalTo: B.rightAnchor).isActive = true
}

func constrainBottom3(_ A: UIView, _ B: UIView) {
//    A.translatesAutoresizingMaskIntoConstraints = false
//    B.translatesAutoresizingMaskIntoConstraints = false

    A.bottomAnchor.constraint(equalTo: B.bottomAnchor).isActive = true
    A.leftAnchor.constraint(equalTo: B.leftAnchor).isActive = true
    A.rightAnchor.constraint(equalTo: B.rightAnchor).isActive = true
}

// MARK: - UIScrollView
extension UIScrollView {
    var isScrollableY: Bool {
        return contentSize.height > bounds.height
    }
    var isScrollableX: Bool {
        return contentSize.width > bounds.width
    }
    var isAtTop: Bool {
        return contentOffset.y == minScrollY
    }
    var isOverScrolledTop: Bool {
        return contentOffset.y < minScrollY
    }
    var isOverScrolledLeft: Bool {
        return contentOffset.x < 0
    }
    var isOverScrolledBottom: Bool {
        return contentOffset.y > maxScrollY
    }
    var isOverScrolledBottomWithInset: Bool {
        return contentOffset.y > maxScrollYWithInset
    }
    var isOverScrolledRight: Bool {
        return contentOffset.x > maxScrollX
    }
    var maxScrollX: CGFloat {
        return contentSize.width - bounds.size.width
    }
    var minScrollY: CGFloat {
        return 0 //-safeAreaInsets.top
    }
    var maxScrollYWithInset: CGFloat {
        // handle negative content inset used on webview
        return contentSize.height - bounds.size.height + contentInset.bottom
    }
    var maxScrollY: CGFloat {
        return contentSize.height - bounds.size.height
    }
}

// MARK: - UIView
extension UIView {
    var radius: CGFloat {
        set { layer.cornerRadius = newValue }
        get { return layer.cornerRadius }
    }

    var scale: CGFloat {
        set { transform = CGAffineTransform(scale: newValue) }
        get { return transform.xScale }
    }
}

extension UICollectionViewLayoutAttributes {
    var scale: CGFloat {
        set { transform = CGAffineTransform(scale: newValue) }
        get { return transform.xScale }
    }
}
