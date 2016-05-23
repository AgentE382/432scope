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
    
    // use this to sync / lock the memory buffer
    private var gcdSampleBufferQueue:dispatch_queue_t? = nil
    
    // the memory buffer itself
    private var samples:ContiguousArray<Sample> = []
    private var capacity:Int = 0
    private var writeIndex:Int = 0
    
    // if there's a trigger object attached, samples will be passed through to it as well.
    var trigger:Trigger? = nil
    
    func suspendWrites() {
        dispatch_sync(gcdSampleBufferQueue!, {
            dispatch_suspend(self.gcdSampleBufferQueue!)
        })
    }
    
    func resumeWrites() {
        dispatch_resume(gcdSampleBufferQueue!)
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

    //
    // READ FUNCTIONS.  These do NOT suspend writes so just be aware the array could be running around under you.
    
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
        
        // lock this here in a const in case there are sample writes happening in another thread
        let lockedWriteIndex = self.writeIndex
        
        let safeNewest = self.wrapIndex(indexRange.newest + lockedWriteIndex + 1)
        let safeOldest = self.wrapIndex(indexRange.oldest + lockedWriteIndex + 1)
        if ( safeNewest < safeOldest ) {
            // contiguous
            rval = Array<Sample>(self.samples[safeNewest...safeOldest])
        } else {
            // the range wraps around the end of the array
            rval = Array<Sample>(self.samples[safeNewest...(self.capacity-1)])
            rval += Array<Sample>(self.samples[0...safeOldest])
        }
        return rval
        
    }
    
    //
    // READ-WITHOUT-COPY, and MINMAX stuff, for the new drawing trick.
    //
    // set a subrange depth, and then query indices on that timeframe ...
    //
    
    // returns the first sample in the subrange
    func getSampleAtTime( time:Time ) -> Sample {
        return samples[wrapIndex(time.asSampleIndex())]
    }
    
    // let's try doing this all locally in sampleBuffer, maybe the call / deref overhead is significant ...
    func getSubRangeMinMaxes(timeRange:TimeRange, howManySubranges:Int) -> [(min:Sample, max:Sample)] {

        // figure out how many samples to minmax per pixel
        
        // TODO: parallel-process this??
        
        // TODO: get this function call out of here?
        
        // TODO: write "getSampleAtTime" so the UI has that as a MoveTo point.
        
        let visibleSampleCount:Int = getSubRangeSampleCount(timeRange)
        let subrangeWidthInSamples:CGFloat = CGFloat(visibleSampleCount) / CGFloat(howManySubranges)
        let subrangeSampleCount:Int = Int(ceil(subrangeWidthInSamples))
        
        // this will track the start of the current subrange.  we start at newestSample + the beginning of the visible frame.
        var subrangeStartIndexAsFloat = CGFloat(wrapIndex(timeRange.newest.asSampleIndex()+(1+writeIndex)))
        var subrangeStartIndex = Int(floor(subrangeStartIndexAsFloat))
        
//        print("samples in time range: \(visibleSampleCount)\t\tframe width in samples: \(subrangeWidthInSamples)")
        
        // this subfunction will do the actual computing. just set subrangeStartIndex and subrangeSampleCount (which is already set as it was declared) ...
        var min:Sample = Sample.max
        var max:Sample = Sample.min
        var realIndex:Int = 0
        var currentSample:Sample = 0
        var subrangeEndIndex:Int = 0
        func getLocalMinMax() -> (min:Sample, max:Sample) {
            // eliminate the obvious stuff ...
            if subrangeSampleCount <= 1 {
                let theLonelySample = samples[subrangeStartIndex]
                return (min:theLonelySample, max:theLonelySample)
            }
            
            // TODO: get wrapIndex out of this picture
            min = Sample.max
            max = Sample.min
            realIndex = 0
            currentSample = 0
            subrangeEndIndex = subrangeStartIndex + subrangeSampleCount
            
            for i in subrangeStartIndex..<subrangeEndIndex {
                realIndex = wrapIndex(i)
                currentSample = samples[realIndex]
                if ( currentSample < min ) {
                    min = currentSample
                }
                if ( currentSample > max ) {
                    max = currentSample
                }
            }
            return (min:min, max:max)
        }

        // create the return object ...
        var minmaxes:[(min:Sample, max:Sample)] = []
        minmaxes.reserveCapacity(howManySubranges)
        
        // here we go ...
        for _ in 0..<howManySubranges {
            minmaxes.append(getLocalMinMax())
            subrangeStartIndexAsFloat += subrangeWidthInSamples
            subrangeStartIndex = Int(floor(subrangeStartIndexAsFloat))
        }
        
        return minmaxes
    }
    
    private func getSubRangeSampleCount(timeRange:TimeRange) -> Int {
        let oldest = timeRange.oldest.asSampleIndex()
        let newest = timeRange.newest.asSampleIndex()
        return (oldest - newest) + 1
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
