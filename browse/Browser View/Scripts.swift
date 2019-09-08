//
//  JSUtils.swift
//  browse
//
//  Created by Evan Brooks on 9/8/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import UIKit

struct Scripts {
    static let checkFixed = checkFixedScript
    static let findLinkAtPoint = findLinkAtPointScript
    static let customStyle = customStyleScript
}


struct FixedNavResult {
    let hasTopNav: Bool
    let hasBottomNav: Bool
}

struct LinkInfo {
    let href: String
    let title: String?
}

extension WKWebView {
    func linkAt(_ position: CGPoint, completionHandler: @escaping ((LinkInfo?) -> ()) ) {
        
        // Translate gesture point into the coordinate system of the zoomed page
        let scaleFactor = 1 / scrollView.zoomScale
        let pt = CGPoint(x: position.x * scaleFactor, y: position.y * scaleFactor)
        
        self.evaluateJavaScript("window.\(findLinkAtPointFuncName)(\(pt.x), \(pt.y))") { (val, err) in
            if let err = err {
                print(err)
            }
            if let dict = val as? [String: String?],
                let href = dict["href"], href != nil,
                let title = dict["title"] {
                completionHandler(LinkInfo(href: href!, title: title))
                return
            }
            
            print("no link info: \(val ?? "Missing val")")
            completionHandler(nil)
        }
    }
    
    func clearHighlightedLinks() {
        self.evaluateJavaScript("window.\(clearHighlightedLinksFuncName)()") { (val, err) in
            if let err = err {
                print(err)
            }
        }
    }
    
    func evaluateFixedNav(_ completionHandler: @escaping (FixedNavResult) -> Void) {
        evaluateJavaScript("window.\(checkFixedFuncName)()") { (result, _) in
            if let dict = result as? [String: Bool],
                let top = dict["top"],
                let bottom = dict["bottom"] {
                completionHandler(FixedNavResult(
                    hasTopNav: top,
                    hasBottomNav: bottom))
            }
        }
    }
}




private let checkFixedFuncName = "__BROWSE_HAS_FIXED_NAV__"

private let checkFixedScript = """
    (function() {
        const isFixed = (elm) => {
            let el = elm;
            while (typeof el === 'object' && el.nodeName.toLowerCase() !== 'body') {
                const pos = window.getComputedStyle(el).getPropertyValue('position').toLowerCase()
                if (pos === 'fixed' || pos === 'sticky' || pos === '-webkit-sticky') return true;
                el = el.parentElement;
            }
            return false;
        };
        window.\(checkFixedFuncName) = () => {
            return {
                top: isFixed(document.elementFromPoint(1,1)),
                bottom: isFixed(document.elementFromPoint(1,window.innerHeight - 1))
            }
        };
    })();
"""

private let findLinkAtPointFuncName = "__BROWSE_GET_LINK__"
private let clearHighlightedLinksFuncName = "__BROWSE__CLEAR_ACTIVE_LINK__"
private let highlightLinkClassName = "__BROWSE_ACTIVE_LINK__"
private let preventSelectionClassName = "__BROWSE_PREVENT_SELECTION__"

private let findLinkAtPointScript = """
    (function() {
        window.\(findLinkAtPointFuncName) = (x, y) => {
            let el = document.elementFromPoint(x, y);
            if (!el) {
                return "No el";
            }
            // Walk up to find parent with href
            while (
                typeof el === 'object'
                && el.nodeName.toLowerCase() !== 'body'
                && !el.hasAttribute('href')
            ) {
                el = el.parentElement;
            }

            const href = el.getAttribute('href');
            if (!href) {
                return "No href for " + el.tagName;
            }
            document.body.classList.add('\(preventSelectionClassName)');
            el.classList.add('\(highlightLinkClassName)');
            return {
                href: href,
                title: el.getAttribute('title')
            };
        };
        window.\(clearHighlightedLinksFuncName) = () => {
            const els = document.querySelectorAll('.\(highlightLinkClassName)');
            document.body.classList.remove('\(preventSelectionClassName)');
            for (const el of els) {
                el.classList.remove('\(highlightLinkClassName)');
            }
        };
    })();
"""

private let customStyleScript = """
    const style = document.createElement('style');
    style.type = 'text/css';
    style.innerText = `
        .__BROWSE_PREVENT_SELECTION__ *:not(input):not(textarea) {
        -webkit-user-select: none;
        -webkit-touch-callout: none;
    }
    .\(highlightLinkClassName) {
        transition: all 0.3s;
        background: rgba(0,0,0,0.1);
        transform: scale(1.08);
    }
    `;
    const head = document.getElementsByTagName('head')[0];
    head.appendChild(style);
"""

