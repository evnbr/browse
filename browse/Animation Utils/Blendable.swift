//
//  Blendable.swift
//  browse
//
//  Created by Evan Brooks on 3/13/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

public protocol Blendable {
    static var initialValue: Self { get }
    static func blend(from: Self, to: Self, by: CGFloat) -> Self
}

extension CGPoint: Blendable {
    public static var initialValue: CGPoint { return .zero }
    
    public static func blend(from start: CGPoint, to end: CGPoint, by progress: CGFloat) -> CGPoint {
        return progress.lerp(start, end)
    }
}

extension CGFloat: Blendable {
    public static var initialValue: CGFloat { return 0 }

    public static func blend(from start: CGFloat, to end: CGFloat, by progress: CGFloat) -> CGFloat {
        return progress.lerp(start, end)
    }
}

// Blend directly on progress
extension CGFloat {
    func lerp(_ start: CGFloat, _ end: CGFloat) -> CGFloat {
        return start + (end - start) * self
    }
    
    func lerp(_ start: CGPoint, _ end: CGPoint) -> CGPoint {
        return CGPoint(
            x: self.lerp(start.x, end.x),
            y: self.lerp(start.y, end.y)
        )
    }
}
