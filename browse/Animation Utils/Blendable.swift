//
//  Blendable.swift
//  browse
//
//  Created by Evan Brooks on 3/13/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

public protocol Blendable {
    static var initialValue : Self { get }
    static func blend(from: Self, to: Self, by: CGFloat) -> Self
}

extension CGPoint : Blendable {
    public static var initialValue: CGPoint { return .zero }
    
    public static func blend(from start: CGPoint, to end: CGPoint, by progress: CGFloat) -> CGPoint {
        return progress.blend(start, end)
    }
}

extension CGFloat : Blendable {
    public static var initialValue: CGFloat { return 0 }

    public static func blend(from start: CGFloat, to end: CGFloat, by progress: CGFloat) -> CGFloat {
        return progress.blend(start, end)
    }
}

// Blend directly on progress
extension CGFloat {
    func blend(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        return start + (end - start) * self;
    }
    
    func blend(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
        return CGPoint(
            x: self.blend(start.x, end.x),
            y: self.blend(start.y, end.y)
        )
    }
}
