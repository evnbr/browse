//
//
//  UIImageColors.swift
//
//  Based on https://github.com/jathu/UIImageColors
//  Created by Jathu Satkunarajah (@jathu) on 2015-06-11 - Toronto
//  Original Cocoa version by Panic Inc. - Portland
//

import UIKit

let edgeWidth: Int = 8
let COLOR_DEBUG = false

struct IntSize {
    let width: Int
    let height: Int
}

extension CGColor {
    var components: [CGFloat] {
        var red = CGFloat()
        var green = CGFloat()
        var blue = CGFloat()
        var alpha = CGFloat()
        UIColor(cgColor: self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [red, green, blue, alpha]
    }
}

extension UIImage {
    private func resizeForUIImageColors(newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        defer {
            UIGraphicsEndImageContext()
        }
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        guard let result = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError("UIImageColors.resizeForUIImageColors failed: UIGraphicsGetImageFromCurrentImageContext returned nil")
        }

        return result
    }
    
    /**
     Get `UIImageColors` from the image asynchronously (in background thread).
     Discussion: Use smaller sizes for better performance at the cost of quality colors. Use larger sizes for better color sampling and quality at the cost of performance.
     
     - parameter scaleDownSize:     Downscale size of image for sampling, if `CGSize.zero` is provided, the sample image is rescaled to a width of 250px and the aspect ratio height.
     - parameter completionHandler: `UIImageColors` for this image.
     */
    public func asyncGetEdgeColors(completionHandler: @escaping (UIColor) -> Void) {
        DispatchQueue.global().async {
            let result = self.getEdgeColors()
            
            if let color = result {
                DispatchQueue.main.async {
                    completionHandler(color)
                }
            }
        }
    }

    /**
     Get `UIImageColors` from the image synchronously (in main thread).
     Discussion: Use smaller sizes for better performance at the cost of quality colors.
     Use larger sizes for better color sampling and quality at the cost of performance.
     
     - parameter scaleDownSize: Downscale size of image for sampling, if `CGSize.zero`
     is provided, the sample image is rescaled to a width of 250px and the aspect ratio height.
     
     - returns: `UIImageColors` for this image.
     */
    
    public func getEdgeColors() -> UIColor? {
        let ratio = self.size.width / self.size.height
        let maxWidth: CGFloat = 320
        let scaleDownSize = CGSize(width: maxWidth, height: maxWidth / ratio)

        let cgImage = self.resizeForUIImageColors(newSize: scaleDownSize).cgImage!

        let imageSize = IntSize(width: cgImage.width, height: cgImage.height)

        guard let data = CFDataGetBytePtr(cgImage.dataProvider!.data) else {
            fatalError("UIImageColors.getColors failed: could not get cgImage data")
        }

        let leftColor = dominantColor(
            for: data,
            at: imageSize,
            startX: 0,
            sampleWidth: edgeWidth)
        let rightColor = dominantColor(
            for: data,
            at: imageSize,
            startX: imageSize.width - edgeWidth,
            sampleWidth: edgeWidth)

        guard let left = leftColor, let right = rightColor else {
            // Dominant color not detected, bail out
            return nil
        }
        
        if left.difference(from: right) < 0.01 {
            // Colors are very close, reasonable to assume edges are background
            if COLOR_DEBUG { print("left/right match") }
            return left
        }
        
        // Colors are different. Add a middle sample as a tie breaker.
        let middleSampleWidth = 30
        guard let middleColor = dominantColor(
            for: data,
            at: imageSize,
            startX: (imageSize.width / 2) - (middleSampleWidth / 2),
            sampleWidth: middleSampleWidth
        ) else {
            return nil
        }
        
        let leftDiff = left.difference(from: middleColor)
        let rightDiff = right.difference(from: middleColor)

        if leftDiff < rightDiff && leftDiff < 0.05 {
            // Reasonable to assume left edge is background
            if COLOR_DEBUG { print("middle is more like left") }
            return left
        }
        if rightDiff < leftDiff && rightDiff < 0.05 {
            // Reasonable to assume right edge is background
            if COLOR_DEBUG { print("middle is more like right") }
            return right
        }
        if COLOR_DEBUG { print("all the colors are different, skipping") }
        return nil
    }
    
    private func dominantColor(
        for imageData: UnsafePointer<UInt8>,
        at imageSize: IntSize,
        startX: Int,
        sampleWidth: Int
    ) -> UIColor? {
        
        let set = NSCountedSet(capacity: sampleWidth * imageSize.height)
        let endX = startX + sampleWidth
        
        for y in 0..<imageSize.height {
            for x in startX..<endX {
                let pxIndex: Int = ((imageSize.width * y) + x) * 4
                guard imageData[pxIndex + 3] >= 127 else {
                    // alpha over 0.5
                    continue
                }
                set.add(UIColor(
                    red: CGFloat(imageData[pxIndex + 2]) / 255,
                    green: CGFloat(imageData[pxIndex + 1]) / 255,
                    blue: CGFloat(imageData[pxIndex]) / 255,
                    alpha: 1.0
                ))
            }
        }
        
        if let first = set.allObjects
            .max(by: { set.count(for: $0) < set.count(for: $1) }) as? UIColor  {
            return first
        }
        
        return nil
    }
    
}
