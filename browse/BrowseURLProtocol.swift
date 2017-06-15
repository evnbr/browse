//
//  BrowseURLProtocol.swift
//  browse
//
//  Created by Evan Brooks on 5/26/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//
//  Based on https://www.raywenderlich.com/76735/using-nsurlprotocol-swift
//  and https://github.com/WildDylan/WKWebViewWithURLProtocol/blob/master/Example/WKWebViewWithURLProtocol/URLProtocol.m
//
//  Note that we only handle requests with the custom protocol
//  if we plan on blocking it. We should be able to pass through requests
//  without blocking them, and only check in canonicalRequest, but it isn't working.

import Foundation

let KEY : String = "_browse_url_protocol_key_"

class BrowseURLProtocol: URLProtocol, NSURLConnectionDataDelegate {
    
    var connection : NSURLConnection!
    
    override class func canInit(with request: URLRequest) -> Bool {
        
        let isPost = request.httpMethod == "POST"
        if isPost {
            if let count : Int = request.httpBody?.count {
                print("⚠️ Warning: POST request with body of size \(count) bytes ")
            }
            print("⚠️ Warning: POST request with no body")
            
//            let reqWith = request.value(forHTTPHeaderField: "x-requested-with")
//            print("Requested from \(reqWith)")
        }
        
        if let scheme = request.url?.scheme {
            if scheme.caseInsensitiveCompare("http") == .orderedSame
            || scheme.caseInsensitiveCompare("https") == .orderedSame {
                
//                print("➡️ Request: \(request.url?.host ?? "Somewhere?")")

                if URLProtocol.property(forKey: KEY, in: request) != nil {
//                    print("Already handled..")
                    return false
                }
                
                if Blocker.shared.isEnabled {
                    if let url = request.url { // TODO: if we check here we don't need to check in cannonicalRequest
                        if Blocker.shared.shouldBlock(url) {
//                            print("Handling...")
                            return true
                        }
                    }
                }
            }
            else {
                print("Unknown scheme: \(request.url?.absoluteString ?? "no url")")
            }
        }
        else {
            print("No scheme: \(request.url?.absoluteString ?? "no url")")
        }

//        print("Not handling...")
        return false
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        if let url = request.url {
            if Blocker.shared.shouldBlock(url) {
                print("🛑 Will block: \(request.url?.host ?? "Somewhere?")")
                return redirectToNowhere(request)
            }
        }
        
        return request
    }
    
    override class func requestIsCacheEquivalent(_ aRequest: URLRequest,
                                                 to bRequest: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(aRequest, to:bRequest)
    }
    

    
    class func redirectToNowhere(_ originalRequest : URLRequest) -> URLRequest {
        
        var newRequest = originalRequest
        let blank = "about:blank"
        newRequest.url = URL(string: blank)
        
        print("🛑 Blocked: \(originalRequest.url?.host ?? "Somewhere?")")
        
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
        if connection != nil {
           connection.cancel()
        }
        connection = nil
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
