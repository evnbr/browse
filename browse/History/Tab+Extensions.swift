//
//  Tab+Extensions.swift
//  browse
//
//  Created by Evan Brooks on 3/17/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import WebKit

extension Tab {
    var hasParent: Bool {
        return self.parentTab != nil
    }

    func updateSnapshot(from webView: WKWebView, completionHandler: @escaping (UIImage) -> Void = { _ in }) {
        let wasShowingIndicators = webView.scrollView.showsVerticalScrollIndicator
        let item = currentVisit
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.takeSnapshot(with: nil) { (image, _) in
            if wasShowingIndicators {
                webView.scrollView.showsVerticalScrollIndicator = true
            }
            if let img: UIImage = image {
                item?.snapshot = img
                completionHandler(img)
            }
        }
    }
}
