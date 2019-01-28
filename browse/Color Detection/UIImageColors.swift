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
    public func asyncGetEdgeColors(scaleDownSize: CGSize = CGSize.zero, completionHandler: @escaping (UIColor) -> Void) {
        DispatchQueue.global().async {
            let result = self.getEdgeColors(scaleDownSize: scaleDownSize)
            
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
    
    public func getEdgeColors(scaleDownSize: CGSize = CGSize.zero) -> UIColor? {
        // TODO: Scale down is not encessary but without it
        // the image gets released(?) and accessing the bytes will fail
        var scaleDownSize = scaleDownSize
        if scaleDownSize == CGSize.zero {
            let ratio = self.size.width / self.size.height
            let r_width: CGFloat = 320
            scaleDownSize = CGSize(width: r_width, height: r_width / ratio)
        }
        let cgImage = self.resizeForUIImageColors(newSize: scaleDownSize).cgImage!
//        let cgImage = self.cgImage!

        let imageSize = IntSize(width: cgImage.width, height: cgImage.height)

        guard let data = CFDataGetBytePtr(cgImage.dataProvider!.data) else {
            fatalError("UIImageColors.getColors failed: could not get cgImage data")
        }

        // Filter out and collect pixels from image
        let imageColorsLeft = countedColorSet(
            for: data,
            at: imageSize,
            startX: 0,
            sampleWidth: edgeWidth)
        let imageColorsRight = countedColorSet(
            for: data,
            at: imageSize,
            startX: imageSize.width - edgeWidth,
            sampleWidth: edgeWidth)

        // Get background color
        let leftColor = dominantColor(in: imageColorsLeft)
        let rightColor = dominantColor(in: imageColorsRight)

        guard let left = leftColor, let right = rightColor else {
            // Sampling failed, bail out
            return nil
        }
        
        if left.difference(from: right) < 0.01 {
            // Colors are very close, reasonable to assume edges are background
            if COLOR_DEBUG { print("left/right match") }
            return left
        }
        
        // Colors are different. Add a middle sample as a tie breaker.
        let middleSampleWidth = 30
        let imageColorsMiddle = countedColorSet(
            for: data,
            at: imageSize,
            startX: (imageSize.width / 2) - (middleSampleWidth / 2),
            sampleWidth: middleSampleWidth)
        let middleColor = dominantColor(in: imageColorsMiddle)
        
        guard let middle = middleColor else { return nil }
        let leftDiff = left.difference(from: middle)
        let rightDiff = right.difference(from: middle)

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
    
    private func countedColorSet(
        for imageData: UnsafePointer<UInt8>,
        at imageSize: IntSize,
        startX: Int,
        sampleWidth: Int
        ) -> NSCountedSet {
        
        let countedSet = NSCountedSet(capacity: sampleWidth * imageSize.height)
        let endX = startX + sampleWidth
        
        for y in 0..<imageSize.height {
            for x in startX..<endX {
                let pixel: Int = ((imageSize.width * y) + x) * 4
                if imageData[pixel + 3] >= 127 { // alpha over 0.5
                    let color = UIColor(
                        red: CGFloat(imageData[pixel + 2]) / 255,
                        green: CGFloat(imageData[pixel + 1]) / 255,
                        blue: CGFloat(imageData[pixel]) / 255,
                        alpha: 1.0
                    )
                    countedSet.add(color)
                }
            }
        }
        return countedSet
    }
    
    private func dominantColor(in set: NSCountedSet) -> UIColor? {
        if let first = set.allObjects
            .compactMap({ $0 as? UIColor})
            .max(by: { set.count(for: $0) < set.count(for: $1) })  {
            return first
        }
        
        return nil
    }
}
