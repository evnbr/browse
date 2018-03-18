//
//  HistoryItem+snapshot.swift
//  browse
//
//  Created by Evan Brooks on 3/17/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

// Extend codegen'd HistoryItem model to simplify snapshots
extension HistoryItem {
    var snapshot: UIImage? {
        get { return HistoryManager.shared.snapshot(for: self) }
        set {
            guard let image = newValue else { return }
            HistoryManager.shared.setSnapshot(image, for: self)
        }
    }
}
