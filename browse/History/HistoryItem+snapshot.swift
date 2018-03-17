//
//  HistoryItem+snapshot.swift
//  browse
//
//  Created by Evan Brooks on 3/17/18.
//  Copyright © 2018 Evan Brooks. All rights reserved.
//

// Extend codegen'd HistoryItem model to support uiimage snapshots
extension HistoryItem {
    var snapshot: UIImage? {
        get {
            guard let uuid = self.uuid else { return nil }
            if let cached = HistoryManager.shared.snapshotCache[uuid] {
                return cached
            }
            guard let dir = FileManager.defaultDirURL else { return nil }
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent("\(uuid.uuidString).png").path)
        }
        set {
            guard let image = newValue, let uuid = self.uuid else { return }
            HistoryManager.shared.snapshotCache[uuid] = image
            
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = UIImagePNGRepresentation(image), let dir = FileManager.defaultDirURL else { return }
                do {
                    try data.write(to: dir.appendingPathComponent("\(uuid.uuidString).png"))
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
    }
}

fileprivate extension FileManager {
    static var defaultDirURL : URL? {
        return try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
}
