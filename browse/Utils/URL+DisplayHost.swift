//
//  URL+DisplayHost.swift
//  browse
//
//  Created by Evan Brooks on 6/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation

extension URL {
    var displayHost : String {
        get {
            guard let host : String = self.host else { return "No host"}
            if host.hasPrefix("www.") {
                let index = host.index(host.startIndex, offsetBy: 4)
                return host.substring(from: index)
            }
            else {
                return host
            }
        }
    }
    var searchQuery : String {
        get {
            guard let components = URLComponents(string: self.absoluteString) else { return "?" }
            let queryParam : String = (components.queryItems?.first(where: { $0.name == "q" })?.value)!
            let withoutPlus : String = queryParam.replacingOccurrences(of: "+", with: " ")
            return withoutPlus
        }
    }
}
