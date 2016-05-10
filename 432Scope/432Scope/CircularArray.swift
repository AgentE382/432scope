//
//  CircularArray.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation

//
// CircularArray
//
// This is the data structure used to store samples and trigger events and whatever else it's good for.  It's a circular buffer where you can pull a sub-range of it and it will wrap around the end of a contiguous array for you if necessary.
//
// If you need locking or write-safety, do it in whatever structure encapsulates an instance of this, because there's none of that in here!!!!!
//

class CircularArray<T:Comparable> {
    
    private var theArray:ContiguousArray<T>
    private(set) var capacity:Int
    private var writeIndex:Int
    
    private var newestEntryIndex:Int {
        let rval = writeIndex + 1
        if ( rval == capacity ) {
            return 0
        }
        return rval
    }
    
    init() {
 //       print("-init empty")
        theArray = ContiguousArray<T>()
        capacity = 0
        writeIndex = -1
    }
    
    init(capacity:Int, repeatedValue:T) {
//        print("-init capacity:\(capacity) repeatedValue:\(repeatedValue)")
        theArray = ContiguousArray<T>(count: capacity, repeatedValue: repeatedValue)
        theArray.reserveCapacity(capacity)
        self.capacity = capacity
        writeIndex = 0
    }
    
    func getNewestEntry( ) -> T {
        return theArray[newestEntryIndex]
    }
    
    func getEntry( index:Int ) -> T {
        return theArray[wrapIndex(index+newestEntryIndex)]
    }
    
    func wrapIndex( index:Int ) -> Int {
        // this wraps out-of-bounds indexes to safe ones within the array capacity
        var safeIndex:Int = index
        while ( safeIndex < 0 ) {
            safeIndex += capacity
        }
        while ( safeIndex >= capacity ) {
            safeIndex -= capacity
        }
        return safeIndex
    }
    
    // the bounds you pass to this function are INCLUSIVE.
    func getSubArray( first:Int, last:Int ) -> Array<T> {
        let newCapacity = last - first + 1
        let safeFirst = wrapIndex(first+newestEntryIndex)
        let safeLast = wrapIndex(last+newestEntryIndex)
//        print ("-getSubArray first:\(first) last:\(last) length:\(newCapacity)")
        if ( newCapacity > capacity ) {
            print("-getSubArray: subCapacity > capacity. what are you doing.")
        }
        if ( safeLast >= safeFirst ) {
//            print("-getSubArray mapped [\(first),\(last)] to [\(safeFirst),\(safeLast)]: contiguous")
            // the slice we want is one contiguous block. gogogo.
            return Array(theArray[safeFirst...safeLast])
        }
        if ( safeLast < safeFirst ) {
  //          print("-getSubArray mapped [\(first),\(last)] to [\(safeFirst),\(safeLast)]: wrapped")
            // the slice we want actually wraps around, so we have to pull two different chunks.
            var subArray = Array(theArray[safeFirst...(capacity-1)])
            subArray += Array(theArray[0...safeLast])
            return subArray
        }
        // if we got here, first = last, so that's an empty array ...
        return []
    }
    
/*    func getSubArrayMinMax( first:Int, last:Int ) -> (min:T, max:T) {
        let newCapacity = last - first + 1
        let safeFirst = wrapIndex(first+newestEntryIndex)
        let safeLast = wrapIndex(last+newestEntryIndex)
        if ( newCapacity > capacity ) {
            print("-getSubArrayMinMax: subCapacity > capacity. what are you doing.")
        }
        if ( safeLast >= safeFirst ) {
            // contiguous. one slice.
            let slice = theArray[safeFirst...safeLast]
            
            return (min:slice.minElement()!, max:slice.maxElement()!)
        }
        if ( safeLast < safeFirst ) {
            // two slices.
            let slice1 = theArray[safeFirst...(capacity-1)]
            let slice2 = theArray[0...safeLast]
            var rval:(min:T, max:T)
            let s1min = slice1.minElement()!
            let s1max = slice1.maxElement()!
            let s2min = slice2.minElement()!
            let s2max = slice2.maxElement()!
            if ( s1min < s2min ) {
                rval.min = s1min
            } else {
                rval.min = s2min
            }
            if ( s1max > s2max ) {
                rval.max = s1max
            } else {
                rval.max = s2max
            }
            return rval
        }
        // i cannot help you.  poor soul.
        return (min:theArray[0],max:theArray[0])
    }*/
    
    func storeNewEntry( entry:T ) {
 //       print("-storeNewEntry writeIndex:\(writeIndex) entry:\(entry)")
        theArray[writeIndex] = entry
        writeIndex -= 1
        if ( writeIndex < 0 ) {
            writeIndex = capacity - 1
        }
    }
    
    func setAllEntries( toValue:T ) {
        for i in 0..<capacity {
            theArray[i] = toValue
        }
    }
    
}
