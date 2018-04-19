//
//  WebviewColorSampler
//  browse
//
//  Created by Evan Brooks on 5/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import WebKit

let MIN_TIME_BETWEEN_UPDATES = 0.2 //0.15

protocol WebviewColorSamplerDelegate {
    var sampledWebView : WKWebView { get }
    
    var shouldUpdateSample : Bool { get }
    var bottomSamplePosition : CGFloat { get }
    
    func didTakeSample()
    func topColorChange(_ newColor : UIColor)
    func bottomColorChange(_ newColor : UIColor)
    func cancelColorChange()
}

class WebviewColorSampler : NSObject {
    
    var delegate : WebviewColorSamplerDelegate!

    private var colorUpdateTimer : Timer?
    
    var top: UIColor = UIColor.clear
    var bottom: UIColor = UIColor.clear
    
    var lastSampledColorsTime : CFTimeInterval = 0.0
    
    func startUpdates() {
        if colorUpdateTimer == nil {
            colorUpdateTimer = Timer.scheduledTimer(
                timeInterval: MIN_TIME_BETWEEN_UPDATES,
                target: self,
                selector: #selector(self.updateColors),
                userInfo: nil,
                repeats: true
            )
            colorUpdateTimer?.tolerance = 0.3
            RunLoop.main.add(colorUpdateTimer!, forMode: RunLoopMode.commonModes)
        }
    }
    
    func stopUpdates() {
        colorUpdateTimer?.invalidate()
        colorUpdateTimer = nil
        delegate.cancelColorChange()
    }
    
    @objc func updateColors() {
        guard delegate.shouldUpdateSample else { return }
        
        delegate.didTakeSample()
        
        let now = CACurrentMediaTime()
        guard ( now - lastSampledColorsTime > MIN_TIME_BETWEEN_UPDATES )  else { return }
        lastSampledColorsTime = now
        
        let sampleH : CGFloat = 6
        let sampleW : CGFloat = delegate.sampledWebView.bounds.width
        
        let bottomConfig = WKSnapshotConfiguration()
        bottomConfig.rect = CGRect(
            x: 0,
            y: delegate.bottomSamplePosition - sampleH,
            width: sampleW,
            height: sampleH
        )
        delegate.sampledWebView.takeSnapshot(with: bottomConfig) { image, error in
//            image?.getColors(scaleDownSize: bottomConfig.rect.size) { colors in
            image?.getColors() { colors in
                self.bottom = colors.background
                self.delegate.bottomColorChange(self.bottom)
            }
        }
        
        let topConfig = WKSnapshotConfiguration()
        topConfig.rect = CGRect(
            x: 0,
            y: 0,
            width: sampleW,
            height: sampleH
        )
        delegate.sampledWebView.takeSnapshot(with: topConfig) { image, error in
//            image?.getColors(scaleDownSize: topConfig.rect.size) { colors in
            image?.getColors() { colors in
                self.top = colors.background
                self.delegate.topColorChange(self.top)
            }
        }
    }
    
}
