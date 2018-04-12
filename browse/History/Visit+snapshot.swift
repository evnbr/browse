//
//  Visit+snapshot.swift
//  browse
//
//  Created by Evan Brooks on 3/17/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

// Extend codegen'd Visit model to simplify snapshots
extension Visit {
    var snapshot: UIImage? {
        get {
            if let uuid = self.uuid {
                return HistoryManager.shared.snapshot(for: uuid)
            }
            return nil
        }
        set {
            guard let image = newValue else { return }
            HistoryManager.shared.setSnapshot(image, for: self)
        }
    }
}
