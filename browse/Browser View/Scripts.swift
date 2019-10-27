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
    static let findAttributesAtPoint = findAttributesAtPointScript
    static let customStyle = customStyleScript
    static let viewportRemover = viewportRemoverScript
}


struct FixedNavResult {
    let hasTopNav: Bool
    let hasBottomNav: Bool
}

struct DomAttributes {
    let href: String?
    let title: String?
    let src: String?
    
    init(href: String? = nil, src: String? = nil, title: String? = nil) {
        self.href = href
        self.title = title
        self.src = src
    }
}

extension WKWebView {
    func attributesAt(_ position: CGPoint, completionHandler: @escaping ((DomAttributes?) -> ()) ) {
        
        // Translate from view coordinates into zoomed page coordinates
        let scaleFactor = 1 / scrollView.zoomScale
        let pt = CGPoint(x: position.x * scaleFactor, y: position.y * scaleFactor)
        
        self.evaluateJavaScript("window.\(findAttributesAtPointFuncName)(\(pt.x), \(pt.y))") { (val, err) in
            if let err = err {
                print(err)
            }
            if let dict = val as? [String: String?],
                let href = dict["href"], href != nil,
                let title = dict["title"] {
                // This is a link
                completionHandler(DomAttributes(href: href!, title: title))
                return
            }
            if let dict = val as? [String: String?],
                let src = dict["src"], src != nil,
                let title = dict["title"] {
                // This is an image
                completionHandler(DomAttributes(src: src!, title: title))
                return
            }

            print("no info: \(val ?? "Missing val")")
            completionHandler(nil)
        }
    }
    
    func clearHighlightedElements() {
        self.evaluateJavaScript("window.\(clearHighlightedElementsFuncName)()") { (val, err) in
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

// Check if the element contains a fixed bar at top or bottom,
// by walking up the DOM and checking computed styles. Potentially used
// to suppress browser bar transparency if needed
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

private let findAttributesAtPointFuncName = "__BROWSE_GET_LINK__"
private let clearHighlightedElementsFuncName = "__BROWSE__CLEAR_ACTIVE_LINK__"
private let elementShowingMenuClassName = "__BROWSE_ACTIVE_LINK__"
private let preventSelectionClassName = "__BROWSE_PREVENT_SELECTION__"


// The script that powers our custom long-press menu. Extracts information
// about the nearest image or link element, walking up the DOM if necessary.
private let findAttributesAtPointScript = """
    (function() {
        const isLink = (el) => {
            return el && el.nodeName && el.nodeName.toLowerCase() == 'a'
                && el.hasAttribute('href')
        };
        const isImage = (el) => {
            return el && el.nodeName && el.nodeName.toLowerCase() == 'img'
                && el.hasAttribute('src')
        };


        window.\(findAttributesAtPointFuncName) = (x, y) => {
            let el = document.elementFromPoint(x, y);
            if (!el) {
                return "No el";
            }
            // Walk up to find parent with href
            while (
                typeof el === 'object'
                && el.nodeName.toLowerCase() !== 'body'
                && !isImage(el) && !isLink(el)
            ) {
                el = el.parentElement;
            }

            if (isLink(el)) {
                const href = el.getAttribute('href');
                if (!href) {
                    return "No href for link";
                }
                document.body.classList.add('\(preventSelectionClassName)');
                el.classList.add('\(elementShowingMenuClassName)');
                let title = el.getAttribute('title');
                if (!title) {
                    const linkContent = el.textContent.trim();
                    if (linkContent.length > 0) {
                        title = linkContent;
                    }
                }
                return {
                    href: href,
                    title: title
                };
            }
            if (isImage(el)) {
                const src = el.getAttribute('src');
                if (!src) {
                    return "No src for image";
                }
                document.body.classList.add('\(preventSelectionClassName)');
                el.classList.add('\(elementShowingMenuClassName)');
                return {
                    src: src,
                    title: el.getAttribute('title')
                };
            }
            return "No relevant attributes for " + el.tagName;
        };
        window.\(clearHighlightedElementsFuncName) = () => {
            const els = document.querySelectorAll('.\(elementShowingMenuClassName)');
            document.body.classList.remove('\(preventSelectionClassName)');
            for (const el of els) {
                el.classList.remove('\(elementShowingMenuClassName)');
            }
        };
    })();
"""

// html, body { overflow: hidden } breaks our content insets.
// without this, the content is stuck behind the top bar
//
// CSS for the custom-long press: suppress text-selection
// to avoid triggering the system gesture. Style the selected element.

private let customStyleScript = """
    const style = document.createElement('style');
    style.type = 'text/css';
    style.innerText = `
        /*
        html, body {
            overflow: unset !important;
        }
        */
        .\(preventSelectionClassName) *:not(input):not(textarea) {
            -webkit-user-select: none;
            -webkit-touch-callout: none;
        }
        a.\(elementShowingMenuClassName) {
            background: rgba(0,0,0,0.1);
        }
    `;
    const head = document.getElementsByTagName('head')[0];
    head.appendChild(style);
"""

// viewport-fit: cover breaks our implementation of hiding toolbar.
// without this, fixed-position elements like top bars scoot around
private let viewportRemoverScript = """
    const metaTag = document.querySelector("meta[name=viewport]")
    if (metaTag) {
        const prev = metaTag.getAttribute('content');
        const newContent = prev.replace('viewport-fit=cover', '');
        metaTag.setAttribute('content', newContent);
    }
"""


