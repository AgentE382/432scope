//
//  SampleBuffer.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/1/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//


/* 
 it stores a fixed number of samples, circular-style.
 
 when you add a sample, the oldest one is pushed out and discarded.
 
 Concurrency: array writes are done in a serial queue and reads pause the queue.
 */


import Foundation

class SampleBuffer {
    
    private var gcdSampleBufferQueue:dispatch_queue_t? = nil

    private var samples = ContiguousArray<Sample>()

    private(set) var capacity:Int = 0
    private var writeIndex:Int = 0
    
    init() {
    }
    
    init( capacity:Int, clearValue:Sample ) {
        samples = ContiguousArray<Sample>(count:capacity, repeatedValue:0)
        samples.reserveCapacity(capacity)
        self.capacity = capacity
        writeIndex = capacity - 1
        gcdSampleBufferQueue = dispatch_queue_create( "sampleBufferWriteQueue", DISPATCH_QUEUE_SERIAL )
        clearAllSamples(clearValue)
    }

    //
    // READ FUNCTIONS which should ALL suspend the dispatch queue
    //
    
    // this really should only be called by Channel for getInstantaneousVoltage.
    // everything else should be asking for ranges.
    func getNewestSample() -> Sample {
        dispatch_suspend( gcdSampleBufferQueue! )
        let newestSample = samples[newestSampleIndex]
        dispatch_resume( gcdSampleBufferQueue! )
        return newestSample
    }
    
    func getSubArray( indexRange:SampleIndexRange ) -> Array<Sample> {
        dispatch_suspend( gcdSampleBufferQueue! )
        var returnArray:[Sample] = []
        returnArray.reserveCapacity(indexRange.oldest-indexRange.newest+1)
        
        // first job: translate sample indices into array indices.
        let aIndices:SampleIndexRange = (boundsCheckIndex(indexRange.newest + newestSampleIndex), boundsCheckIndex(indexRange.oldest + newestSampleIndex))
        
        // now figure out if the range wraps around the end of the contiguous array
        if ( aIndices.newest < aIndices.oldest ) {
            // the range is one contiguous block, no wraparound.
//            print("indices \(indexRange)->\(aIndices) contiguous")
            returnArray = Array(samples[aIndices.newest...aIndices.oldest])
        } else {
            // the range wraps around. we need to get two arrays and cat them.
//            print("indices \(indexRange)->\(aIndices) wrapped")
            returnArray = Array(samples[aIndices.newest..<capacity])
            returnArray += Array(samples[0...aIndices.oldest])
        }
//        print("returning \(returnArray.count) samples")
        dispatch_resume( gcdSampleBufferQueue! )
        return returnArray
    }
    
    //
    // WRITE FUNCTIONS which should ALL queue their writes.
    //
    
    func storeNewSample( newSample:Sample ) {
        dispatch_sync( gcdSampleBufferQueue!, {
            self.samples[self.writeIndex] = newSample
            self.writeIndex -= 1
            if (self.writeIndex == 0) {
                self.writeIndex = self.capacity-1
            }
        })
    }
    
    func clearAllSamples( clearValue:Sample ) {
        dispatch_sync( gcdSampleBufferQueue!, {
            for i in 0..<self.capacity {
                self.samples[i] = clearValue
            }
        })
    }
    
    //
    // INTERNAL HELPERS
    //
    
    var newestSampleIndex:Int {
        let rval = writeIndex + 1
        if ( rval == capacity ) {
            return 0
        } else {
            return rval
        }
    }
    
    private func boundsCheckIndex( index:Int ) -> Int {
        var rval:Int = index
        while (rval < 0) {
            // it's too small. add capacity until it's good.
            rval += capacity
        }
        while (rval >= capacity) {
            // too big. remove capacity
            rval -= capacity
        }
        return rval
    }
}
