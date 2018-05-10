//
//  TypeaheadCell.swift
//  browse
//
//  Created by Evan Brooks on 2/23/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

import UIKit

class TypeaheadCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .subtitle, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        let bg = UIView(frame: bounds)
        bg.backgroundColor = .darkTouch
        selectedBackgroundView = bg
        
        indentationWidth = 12.0
        indentationLevel = 0
        
        textLabel?.lineBreakMode = .byWordWrapping
        textLabel?.numberOfLines = 1
        textLabel?.font = .systemFont(ofSize: 14)
        layoutMargins = UIEdgeInsetsMake(12, 24, 12, 24)
        
        detailTextLabel?.font = .systemFont(ofSize: 18)
        detailTextLabel?.numberOfLines = 1
        
//        let backer = UIView(frame: contentView.bounds)
//        backer.backgroundColor = .white
//        backer.radius = Const.shared.cardRadius
//        backer.layer.shadowRadius = 12
//        backer.layer.shadowOpacity = 0.2
//        backer.frame.size.height = 200
//        backer.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        contentView.clipsToBounds = true
        clipsToBounds = true
//        contentView.insertSubview(backer, at: 0)
    }
    
    func configure(title: String?, detail: String?, highlight: String) {
        if let title = title {
            let titleOverlaps = title.allNSRanges(of: highlight, split: true)
            let attributedTitle = NSMutableAttributedString(string: title)
            titleOverlaps.forEach { attributedTitle.addAttributes([.foregroundColor : tintColor.withAlphaComponent(0.5)], range: $0) }
            textLabel?.attributedText = attributedTitle
        }
        
        if let detail = detail {
            let detailOverlaps = detail.allNSRanges(of: highlight, split: true)
            let attributedDetail = NSMutableAttributedString(string: detail)
            detailOverlaps.forEach { attributedDetail.addAttributes([.foregroundColor : tintColor.withAlphaComponent(0.5)], range: $0) }
            detailTextLabel?.attributedText = attributedDetail
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        textLabel?.text = nil
        detailTextLabel?.text = nil
    }
    
    override func tintColorDidChange() {
        textLabel?.textColor = tintColor
        detailTextLabel?.textColor = tintColor //.withAlphaComponent(0.7)
        selectedBackgroundView?.backgroundColor = tintColor.isLight ? .darkTouch : .lightTouch
    }
}

// based on https://stackoverflow.com/questions/40413218/swift-find-all-occurrences-of-a-substring
extension String {
    func allRanges(of text: String, split: Bool = false) -> [Range<String.Index>] {
        if split {
            // split query into words, find ranges of each word, and append ranges
            return text.split(separator: " ").map { self.allRanges(of: String($0) ) }.reduce([], +)
        }
        //the slice within which to search
        let slice = self
        
        var previousEnd: String.Index? = slice.startIndex
        var ranges = [Range<String.Index>]()
        
        while let r = slice.range(
            of: text,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: previousEnd! ..< slice.endIndex,
            locale: nil) {
                if previousEnd != self.endIndex { //don't increment past the end
                    previousEnd = self.index(after: r.lowerBound)
                }
                ranges.append(r)
        }
        
        return ranges
    }
    
    func allNSRanges(of text: String, split: Bool = false) -> [NSRange] {
        return allRanges(of: text, split: split).map(indexRangeToNSRange)
    }
    
    func indexToInt(_ index: String.Index) -> Int {
        return self.distance(from: self.startIndex, to: index)
    }
    
    func indexRangeToIntRange(_ range: Range<String.Index>) -> Range<Int> {
        return indexToInt(range.lowerBound) ..< indexToInt(range.upperBound)
    }
    
    func indexRangeToNSRange(_ range: Range<String.Index>) -> NSRange {
        let start = indexToInt(range.lowerBound)
        let end = indexToInt(range.upperBound)
        return NSMakeRange(start, end - start)
    }
}
