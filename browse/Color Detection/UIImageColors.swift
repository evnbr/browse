//
//  UIImageColors.swift
//  https://github.com/jathu/UIImageColors
//
//  Created by Jathu Satkunarajah (@jathu) on 2015-06-11 - Toronto
//  Original Cocoa version by Panic Inc. - Portland
//
//  Modified by Evan Brooks (@evnbr) 2017-09-19 - SF

import UIKit

class PCCountedColor {
    let color: UIColor
    let count: Int

    init(color: UIColor, count: Int) {
        self.color = color
        self.count = count
    }
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

extension UIColor {

    var isDarkColor: Bool {
        let RGB = self.cgColor.components
        return (0.2126 * RGB[0] + 0.7152 * RGB[1] + 0.0722 * RGB[2]) < 0.5
    }

    var isBlackOrWhite: Bool {
        let RGB = self.cgColor.components
        return (RGB[0] > 0.91 && RGB[1] > 0.91 && RGB[2] > 0.91) || (RGB[0] < 0.09 && RGB[1] < 0.09 && RGB[2] < 0.09)
    }

    func isDistinct(compareColor: UIColor) -> Bool {
        let bg = self.cgColor.components
        let fg = compareColor.cgColor.components
        let threshold: CGFloat = 0.25

        if fabs(bg[0] - fg[0]) > threshold || fabs(bg[1] - fg[1]) > threshold || fabs(bg[2] - fg[2]) > threshold {
            if fabs(bg[0] - bg[1]) < 0.03 && fabs(bg[0] - bg[2]) < 0.03 {
                if fabs(fg[0] - fg[1]) < 0.03 && fabs(fg[0] - fg[2]) < 0.03 {
                    return false
                }
            }
            return true
        }
        return false
    }

    func colorWithMinimumSaturation(minSaturation: CGFloat) -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < minSaturation {
            return UIColor(hue: hue, saturation: minSaturation, brightness: brightness, alpha: alpha)
        } else {
            return self
        }
    }

    func isContrastingColor(compareColor: UIColor) -> Bool {
        let bg = self.cgColor.components
        let fg = compareColor.cgColor.components

        let bgLum = 0.2126 * bg[0] + 0.7152 * bg[1] + 0.0722 * bg[2]
        let fgLum = 0.2126 * fg[0] + 0.7152 * fg[1] + 0.0722 * fg[2]

        let bgGreater = bgLum > fgLum
        let nom = bgGreater ? bgLum : fgLum
        let denom = bgGreater ? fgLum : bgLum
        let contrast = (nom + 0.05) / (denom + 0.05)
        return 1.6 < contrast
    }
}

let edgeWidth: Int = 12
let veryEdgeWidth: Int = 5

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

        let width: Int = cgImage.width
        let height: Int = cgImage.height

        guard let data = CFDataGetBytePtr(cgImage.dataProvider!.data) else {
            fatalError("UIImageColors.getColors failed: could not get cgImage data")
        }

        // Filter out and collect pixels from image
        let imageColorsLeft = NSCountedSet(capacity: edgeWidth * height)
        let imageColorsRight = NSCountedSet(capacity: edgeWidth * height)

        for x in 0..<width {
            for y in 0..<height {
                // Only count pixels within N of sides
                if x < edgeWidth {
                    let pixel: Int = ((width * y) + x) * 4
                    if 127 <= data[pixel+3] { // alpha over 0.5
                        let color = UIColor(
                            red: CGFloat(data[pixel + 2]) / 255,
                            green: CGFloat(data[pixel + 1]) / 255,
                            blue: CGFloat(data[pixel]) / 255,
                            alpha: 1.0
                        )
                        imageColorsLeft.add(color)
                        if x < veryEdgeWidth {
                            // boost very edges
                            imageColorsLeft.add(color)
                            imageColorsLeft.add(color)
                            imageColorsLeft.add(color)
                        }
                    }
                }
                if x > width - edgeWidth {
                    let pixel: Int = ((width * y) + x) * 4
                    if 127 <= data[pixel+3] { // alpha over 0.5
                        let color = UIColor(
                            red: CGFloat(data[pixel + 2]) / 255,
                            green: CGFloat(data[pixel + 1]) / 255,
                            blue: CGFloat(data[pixel]) / 255,
                            alpha: 1.0
                        )
                        imageColorsRight.add(color)
                        if x > width - veryEdgeWidth {
                            // boost very edges
                            imageColorsRight.add(color)
                            imageColorsRight.add(color)
                            imageColorsRight.add(color)
                        }
                    }
                }
            }
        }

        // Get background color
        let leftColor = getDominantColor(imageColors: imageColorsLeft)
        let rightColor = getDominantColor(imageColors: imageColorsRight)

        
        if let l = leftColor, let r = rightColor, l.difference(from: r) < 0.05 {
            return leftColor
        } else {
            return nil
        }
    }
    
    func getDominantColor(imageColors: NSCountedSet) -> UIColor? {
        let randomColorsThreshold = 0//Int(CGFloat(height) * 0.01)
        let sortedColorComparator: Comparator = { (main, other) -> ComparisonResult in
            guard let m = main as? PCCountedColor,
                let o = other as? PCCountedColor else {
                    return ComparisonResult.orderedSame
            }
            if m.count < o.count {
                return ComparisonResult.orderedDescending
            } else if m.count == o.count {
                return ComparisonResult.orderedSame
            } else {
                return ComparisonResult.orderedAscending
            }
        }

        let enumerator = imageColors.objectEnumerator()
        let sortedColors = NSMutableArray(capacity: imageColors.count)
        while let kolor = enumerator.nextObject() as? UIColor {
            let colorCount = imageColors.count(for: kolor)
            if colorCount > randomColorsThreshold {
                sortedColors.add(PCCountedColor(color: kolor, count: colorCount))
            }
        }
        sortedColors.sort(comparator: sortedColorComparator)
        
        if sortedColors.count > 0,
            let firstColor = sortedColors.object(at: 0) as? PCCountedColor {
            return firstColor.color
        }
        return nil
    }
}
