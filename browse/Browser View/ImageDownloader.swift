//
//  File.swift
//  browse
//
//  Created by Evan Brooks on 9/8/19.
//  Copyright © 2019 Evan Brooks. All rights reserved.
//

import Foundation

struct ImageDownloader {
    static func downloadImageFrom(url: URL, completionHandler: @escaping ((UIImage?) -> ())) {
        let session = URLSession(configuration: .default)
        
        let downloadTask = session.dataTask(with: url) { (data, response, error) in
            // The download has finished.
            if let e = error {
                print("Error downloading picture: \(e)")
                completionHandler(nil)
                return
            }
            guard let res = response as? HTTPURLResponse else {
                print("Couldn't get response code for some reason")
                completionHandler(nil)
                return
            }
            print("Downloaded photo with response code \(res.statusCode)")
            guard let imageData = data else {
                print("Couldn't get image: Image is nil")
                completionHandler(nil)
                return
            }
            let image = UIImage(data: imageData)
            completionHandler(image)
        }
        downloadTask.resume()
    }
}
