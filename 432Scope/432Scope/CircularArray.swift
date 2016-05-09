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

class CircularArray<T> {
    
    private var theArray:ContiguousArray<T>
    private var capacity:Int
    private var writeIndex:Int
    
    private var newestEntryIndex:Int {
        let rval = writeIndex + 1
        if ( rval == capacity ) {
            return 0
        }
        return rval
    }
    
    init() {
        theArray = ContiguousArray<T>()
        capacity = 0
        writeIndex = -1
    }
    
    init(capacity:Int, repeatedValue:T) {
        theArray = ContiguousArray<T>(count: capacity, repeatedValue: repeatedValue)
        theArray.reserveCapacity(capacity)
        self.capacity = capacity
        writeIndex = capacity - 1
    }
    
    func getNewestEntry( ) -> T {
        return theArray[newestEntryIndex]
    }
    
    //func getSubArray
    
}