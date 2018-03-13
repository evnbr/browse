//
//  SpringTransitionPrototocol.swift
//  browse
//
//  Created by Evan Brooks on 3/12/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import Foundation
import pop

enum SpringTransitionState : CGFloat {
    case start = 0
    case end = 1
}

protocol SpringTransition {
    associatedtype ValueType
    var start : ValueType { get set }
    var end : ValueType { get set }
    func springState(_ : SpringTransitionState ) -> POPSpringAnimation?
    func setState(_ : SpringTransitionState )
    func update()
}

