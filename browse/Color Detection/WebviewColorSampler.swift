//
//  WebviewColorSampler
//  browse
//
//  Created by Evan Brooks on 5/14/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation
import WebKit

let MIN_TIME_BETWEEN_SAMPLE = 0.1 //0.15
let MIN_TIME_BETWEEN_FIXED = 0.3 //0.15

protocol WebviewColorSamplerDelegate: class {
    var sampledWebView: WKWebView { get }

    var shouldUpdateSample: Bool { get }
    var bottomSamplePosition: CGFloat { get }

    func topColorChange(_ newColor: UIColor, offset: CGPoint)
    func bottomColorChange(_ newColor: UIColor, offset: CGPoint)
    func cancelColorChange()
    
    func fixedPositionDidChange(_ result: FixedNavResult)
}

class WebviewColorSampler: NSObject {

    weak var delegate: WebviewColorSamplerDelegate!

    private var colorUpdateTimer: Timer?
    private var fixedUpdateTimer: Timer?

    var top: UIColor = UIColor.clear
    var bottom: UIColor = UIColor.clear
    
    var lastFixedResult: FixedNavResult?

    var lastSampledColorsTime: CFTimeInterval = 0.0
    var lastSampledFixedTime: CFTimeInterval = 0.0

    func startUpdates() {
        if colorUpdateTimer == nil {
            colorUpdateTimer = Timer.scheduledTimer(
                timeInterval: MIN_TIME_BETWEEN_SAMPLE,
                target: self,
                selector: #selector(self.updateColors),
                userInfo: nil,
                repeats: true
            )
            colorUpdateTimer?.tolerance = 0.2
            RunLoop.main.add(colorUpdateTimer!, forMode: RunLoopMode.commonModes)
        }
        if fixedUpdateTimer == nil {
            fixedUpdateTimer = Timer.scheduledTimer(
                timeInterval: MIN_TIME_BETWEEN_FIXED,
                target: self,
                selector: #selector(self.updateFixed),
                userInfo: nil,
                repeats: true
            )
            colorUpdateTimer?.tolerance = 0.2
            RunLoop.main.add(colorUpdateTimer!, forMode: RunLoopMode.commonModes)
        }
    }

    func stopUpdates() {
        colorUpdateTimer?.invalidate()
        fixedUpdateTimer?.invalidate()
        
        colorUpdateTimer = nil
        fixedUpdateTimer = nil
        
        delegate.cancelColorChange()
    }
    
    var sampledWebviewIsLoading: Bool {
        return delegate.sampledWebView.isLoading
    }
    
    @objc func updateFixed() {
        let now = CACurrentMediaTime()
        guard (now - lastSampledFixedTime) > MIN_TIME_BETWEEN_FIXED else { return }
        lastSampledFixedTime = now

//        delegate.sampledWebView.evaluateFixedNav { (result) in
//            self.lastFixedResult = result
//            self.delegate.fixedPositionDidChange(result)
//        }
    }

    @objc func updateColors() {
        guard delegate.shouldUpdateSample else { return }

        let now = CACurrentMediaTime()
        guard (now - lastSampledColorsTime) > MIN_TIME_BETWEEN_SAMPLE else { return }
        lastSampledColorsTime = now

        let sampleH: CGFloat = 6
        let sampleW: CGFloat = delegate.sampledWebView.bounds.width

        let offsetDuringSnapshot = delegate.sampledWebView.scrollView.contentOffset
        let currentItem = delegate.sampledWebView.backForwardList.currentItem

        func didNavigateAfterSample() -> Bool {
            return self.delegate.sampledWebView.backForwardList.currentItem !== currentItem
        }

        let bottomConfig = WKSnapshotConfiguration()
        bottomConfig.rect = CGRect(
            x: 0,
            y: delegate.bottomSamplePosition - sampleH,
            width: sampleW,
            height: sampleH
        )
        delegate.sampledWebView.takeSnapshot(with: bottomConfig) { image, _ in
            if didNavigateAfterSample() { return }
//            image?.getColors(scaleDownSize: bottomConfig.rect.size) { colors in
            image?.asyncGetEdgeColors { color in
                if didNavigateAfterSample() { return }
                if color == .white && self.sampledWebviewIsLoading { return }
                
                self.bottom = color
                self.delegate.bottomColorChange(self.bottom, offset: offsetDuringSnapshot)
            }
        }

        let topConfig = WKSnapshotConfiguration()
        topConfig.rect = CGRect(
            x: 0,
            y: delegate.sampledWebView.safeAreaInsets.top,
            width: sampleW,
            height: sampleH
        )
        delegate.sampledWebView.takeSnapshot(with: topConfig) { image, _ in
            if didNavigateAfterSample() { return }
            image?.asyncGetEdgeColors { color in
                if didNavigateAfterSample() { return }
                if color == .white && self.sampledWebviewIsLoading { return }
                
                self.top = color
                self.delegate.topColorChange(self.top, offset: offsetDuringSnapshot)
            }
        }
    }
}
