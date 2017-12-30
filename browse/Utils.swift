//
//  Utils.swift
//  browse
//
//  Created by Evan Brooks on 12/25/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation

func clip(_ val: CGFloat) -> CGFloat {
    return max(0, min(1, val))
}

func blend(from: CGFloat, to: CGFloat, by pct: CGFloat) -> CGFloat {
    return from + (to - from) * pct;
}

func progress(value: CGFloat, from: CGFloat, to: CGFloat) -> CGFloat {
    let dist = from - to
    let amt = from - value
    return amt / dist;
}

func elasticLimit(_ val : CGFloat, constant: CGFloat = 150) -> CGFloat {
    let resist = 1 - log10(1 + abs(val) / 150) // 1 ... 0.5
    return val * resist
}


extension CGFloat {
    
    func clip() -> CGFloat {
        return Swift.max(0, Swift.min(1, self))
    }
    
    func progress(from: CGFloat, to: CGFloat) -> CGFloat {
        let total = from - to
        let amt = from - self
        return amt / total;
    }
    
    func reverse() -> CGFloat {
        return 1 - self
    }
}


extension CGAffineTransform {
    init(scale s: CGFloat) {
        self.init(scaleX: s, y: s)
    }
}
