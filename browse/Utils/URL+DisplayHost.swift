//
//  URL+DisplayHost.swift
//  browse
//
//  Created by Evan Brooks on 6/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation

extension URL {
    var displayHost: String? {
        guard let host = host else { return nil}
        if host.hasPrefix("www.") {
            let index = host.index(host.startIndex, offsetBy: 4)
            return String(host[index..<host.endIndex]) //  .substring(from: index)
        } else {
            return host
        }
    }
    var isSearching: Bool {
        return searchQuery != nil
    }
    var searchQuery: String? {
        guard let components = URLComponents(string: self.absoluteString),
            let queryParam: String = components.queryItems?.first(where: { $0.name == "q" })?.value
        else { return nil }
        let withoutPlus: String = queryParam.replacingOccurrences(of: "+", with: " ")
        return withoutPlus
    }
    var cleanString: String {
        var clean = absoluteString
        clean = clean.replacingOccurrences(of: "http://", with: "")
        clean = clean.replacingOccurrences(of: "https://", with: "")
        if clean.starts(with: "www.") { clean = clean.replacingOccurrences(of: "www.", with: "") }
        if clean.last == "/" { clean.removeLast() }
        return clean
    }
    
    static func coercedFrom(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isProbablyURL else { return nil }
        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        return URL(string: "http://\(trimmed)")
    }
}

fileprivate let potentialPrefixes = [
    "http://www.",
    "https://www.",
    "http://",
    "https://"
]

// TODO: Make more robust
extension String {
    var isProbablyURL: Bool {
        return self.range(of: ".") != nil && self.range(of: " ") == nil
    }

    var urlPrefix: String? {
        guard URL.coercedFrom(self) != nil else { return nil }
        return potentialPrefixes.first(where: { self.hasPrefix($0) })
    }
}
