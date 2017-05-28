//
//  BrowseURLProtocol.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  Based on https://www.raywenderlich.com/76735/using-nsurlprotocol-swift
//  and https://github.com/WildDylan/WKWebViewWithURLProtocol/blob/master/Example/WKWebViewWithURLProtocol/URLProtocol.m

import Foundation

let KEY : String = "_browse_url_protocol_key_"

class BrowseURLProtocol: URLProtocol, NSURLConnectionDataDelegate {
    
    var connection : NSURLConnection!
    
    override class func canInit(with request: URLRequest) -> Bool {
        
        if let scheme = request.url?.scheme {
            if scheme.caseInsensitiveCompare("http") == .orderedSame
            || scheme.caseInsensitiveCompare("https") == .orderedSame {
                
//                print("➡️ Request: \(request.url?.host ?? "Somewhere?")")

                if URLProtocol.property(forKey: KEY, in: request) != nil {
                    return false
                }
                
                if Blocker.shared.isEnabled {
                    return true
                }
                else {
                    return false
                }
            }
        }
        return false
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let url = request.url {
            if Blocker.shared.shouldBlock(url) {
                return redirectToNowhere(request)
            }
        }
        
        return request
    }
    
    class func redirectToNowhere(_ originalRequest : URLRequest) -> URLRequest {
        
        print("🛑 Blocked: \(originalRequest.url?.host ?? "Somewhere?")")
        
        var newRequest = originalRequest
        let blank = "about:blank"
        newRequest.url = URL(string: blank)
        
        return newRequest
    }
    
    override func startLoading() {
        guard let mutableRequest = (self.request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            // Handle the error
            print("couldn't make mutablerequest")
            return
        }
        URLProtocol.setProperty(true, forKey: KEY, in: mutableRequest)
        connection = NSURLConnection(request: mutableRequest as URLRequest, delegate: self)
        
    }
    
    override func stopLoading() {
        connection.cancel()
    }
    
    // MARK: - NSURLConnectionDelegate
    // see https://github.com/buzzfeed/mattress/blob/master/Source/URLProtocol.swift for example with nsurlsession

    func connection(_ connection: NSURLConnection, didReceive response: URLResponse) -> Void {
        self.client!.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    }
    
    func connection(_ connection: NSURLConnection, didReceive data: Data) {
        self.client!.urlProtocol(self, didLoad: data)
    }
    
    func connectionDidFinishLoading(_ connection: NSURLConnection) {
        self.client!.urlProtocolDidFinishLoading(self)
    }
    
    func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        self.client!.urlProtocol(self, didFailWithError: error)
    }

}
