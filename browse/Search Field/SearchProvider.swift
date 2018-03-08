//
//  SearchProvider
//  browse
//
//  Created by Evan Brooks on 3/7/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

protocol SearchProvider {
    func serpURLfor(_  query: String) -> URL?
    func suggestionURLfor(_ query: String) -> URL?
    func parseSuggestions(from data: NSArray, maxCount: Int) -> [String]
}
