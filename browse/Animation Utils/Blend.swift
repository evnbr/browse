//
//  Blend.swift
//  browse
//
//  Created by Evan Brooks on 3/16/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class Blend<T : Blendable>: NSObject {
    private var _progress : CGFloat = 0
    var start : T = T.initialValue
    var end : T = T.initialValue

    typealias BlendUpdateBlock = (T) -> ()
    let updateBlock : BlendUpdateBlock
    
    init(update block : @escaping BlendUpdateBlock) {
        updateBlock = block
        super.init()
    }
    
    convenience init(start: T, end: T, update block: @escaping BlendUpdateBlock) {
        self.init(update: block)
        setValue(of: .start, to: start)
        setValue(of: .end, to: end)
    }

    func setValue(of: SpringTransitionState, to newValue: T) {
        if of == .start { start = newValue }
        else if of == .end { end = newValue }
    }
    
    var progress: CGFloat {
        get { return _progress }
        set {
            _progress = newValue
            update()
        }
    }
    
    private func update() {
        let newVal : T = T.blend(from: start, to: end, by: _progress)
        updateBlock(newVal)
    }

}
