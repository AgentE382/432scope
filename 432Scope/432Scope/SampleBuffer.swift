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
    
    private var samples:ContiguousArray<Sample> = []
    private var capacity:Int = 0
    private var writeIndex:Int = 0
    
    var trigger:Trigger? = nil
    
    func wrapIndex( index:Int ) -> Int {
        var rval = index
        while ( rval < 0 ) {
            rval += capacity
        }
        while ( rval >= capacity ) {
            rval -= capacity
        }
        return rval
    }

    init() {
    }
    
    init( capacity:Int, clearValue:Sample ) {
        samples = ContiguousArray<Sample>(count: capacity, repeatedValue: clearValue)
        samples.reserveCapacity(capacity)
        
        self.capacity = capacity
        writeIndex = capacity - 1
        
        gcdSampleBufferQueue = dispatch_queue_create( "sampleBufferWriteQueue", DISPATCH_QUEUE_SERIAL )
    }

    //
    // READ FUNCTIONS which should ALL use dispatch_sync
    //
    
    func getNewestSample() -> Sample {
        let newestSampleIndex = self.wrapIndex(self.writeIndex + 1)
        return self.samples[newestSampleIndex]
    }
    
    func getSampleRange( timeRange:TimeRange ) -> Array<Sample> {
        
        var rval:Array<Sample> = []
        let indexRange:SampleIndexRange = (newest:timeRange.newest.asSampleIndex(), oldest:timeRange.oldest.asSampleIndex())

        if ((indexRange.oldest - indexRange.newest) == 0) {
            return rval
        }
        
       dispatch_sync(gcdSampleBufferQueue!, {
            print("sync point")
            dispatch_suspend(self.gcdSampleBufferQueue!)
        })
        let safeNewest = self.wrapIndex(indexRange.newest + self.writeIndex + 1)
        let safeOldest = self.wrapIndex(indexRange.oldest + self.writeIndex + 1)
        if ( safeNewest < safeOldest ) {
            // contiguous
            rval = Array<Sample>(self.samples[safeNewest...safeOldest])
        } else {
            // the range wraps around the end of the array
            rval = Array<Sample>(self.samples[safeNewest...(self.capacity-1)])
            rval += Array<Sample>(self.samples[0...safeOldest])
        }
        dispatch_resume(gcdSampleBufferQueue!)
        return rval
        
    }

    //
    // WRITE FUNCTIONS which should ALL queue their writes.
    //
    
    func storeNewSample( newSample:Sample ) {
        dispatch_sync( gcdSampleBufferQueue!, {
            self.samples[self.writeIndex] = newSample
            self.writeIndex = self.wrapIndex(self.writeIndex-1)
            if let trig = self.trigger {
                trig.processSample(newSample)
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
}
