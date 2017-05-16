//
//  Sampler.swift
//  browse
//
//  Created by Evan Brooks on 5/15/17.
//  Copyright © 2017 Evan Brooks. All rights reserved.
//

import Foundation

class Sampler {
    var samples: Array<Float>
    var sampleCount = 0
    var period = 5
    
    init(period: Int = 5) {
        self.period = period
        samples = Array<Float>()
    }
    
    var average: Float {
        let sum: Float = samples.reduce(0, +)
        
        return sum / Float(period)
    }
    
    var sum: Float {
        return samples.reduce(0, +)
    }
    
    func addSample(value: Float) {
        sampleCount += 1
        let pos = Int(fmodf(Float(sampleCount), Float(period)))
        
        if pos >= samples.count {
            samples.append(value)
        } else {
            samples[pos] = value
        }
        
    }
}
