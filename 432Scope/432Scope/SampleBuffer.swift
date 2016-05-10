//
//  SampleBuffer.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/1/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//


/* 
 stores samples, connects to a trigger detector ...
 Concurrency: array writes are done in a serial queue and reads pause the queue.
 */


import Foundation


class SampleBuffer {
    
    private var gcdSampleBufferQueue:dispatch_queue_t? = nil
    private var samples = CircularArray<Sample>()
    
    var trigger:Trigger? = nil

    init() {
    }
    
    init( capacity:Int, clearValue:Sample ) {
        samples = CircularArray(capacity: capacity, repeatedValue: clearValue)
        gcdSampleBufferQueue = dispatch_queue_create( "sampleBufferWriteQueue", DISPATCH_QUEUE_SERIAL )
        clearAllSamples(clearValue)
    }

    //
    // READ FUNCTIONS which should ALL suspend the dispatch queue
    //
    
    func getNewestSample() -> Sample {
        dispatch_suspend( gcdSampleBufferQueue! )
        let newestSample = samples.getNewestEntry()
        dispatch_resume( gcdSampleBufferQueue! )
        return newestSample
    }
    
    func getSubArray( indexRange:SampleIndexRange ) -> Array<Sample> {
        dispatch_suspend( gcdSampleBufferQueue! )
        let returnArray = samples.getSubArray(indexRange.newest, last: indexRange.oldest)
        dispatch_resume( gcdSampleBufferQueue! )
        return returnArray
    }

    //
    // WRITE FUNCTIONS which should ALL queue their writes.
    //
    
    func storeNewSample( newSample:Sample ) {
        dispatch_sync( gcdSampleBufferQueue!, {
            self.samples.storeNewEntry(newSample)
            if let trig = self.trigger {
                trig.processSample(newSample)
            }
        })
    }
    
    func clearAllSamples( clearValue:Sample ) {
        dispatch_sync( gcdSampleBufferQueue!, {
            self.samples.setAllEntries(clearValue)
        })
    }
}
