//
//  AveragingFilter.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/22/16.
//
//

import Foundation

//
// This one works on anything with RangeableType operators.
//

class AveragingFilter<T:RangeableType> {
    
    private var buffer:[T]
    private(set) var bufferSize:Int
    private var writeIndex:Int
    private var total:T

    init(bufferSize:Int, startingAverage:T) {
        self.buffer = Array<T>(count: bufferSize, repeatedValue: startingAverage)
        self.buffer.reserveCapacity(bufferSize)
        self.bufferSize = bufferSize
        self.total = startingAverage * T(bufferSize)
        self.writeIndex = 0
    }
    
    func filter(newValue:T) -> T {
        // adjust total
        total = total - buffer[writeIndex]
        total = total + newValue
        // store the new value
        buffer[writeIndex] = newValue
        // update writeIndex
        writeIndex += 1
        if ( writeIndex == bufferSize ) {
            writeIndex = 0
        }
        // return the new average
        let newAverage = total / T(bufferSize)
        return newAverage
    }
    
    func getItemByAge( age:Int ) -> T {
        var index:Int = writeIndex - 1 - age
        while ( index < 0 ) {
            index += bufferSize
        }
        return buffer[index]
    }
}

//
// This one is really fast for UInt samples using 2^x / bitwise math.
//

class FastSampleAveragingFilter {

    private var buffer:[Sample]
    private(set) var bufferSize:UInt
    private var writeIndex:UInt
    private var total:UInt
    
    private var indexBitMask:UInt
    private var divisionBitShift:UInt
    
    init(depthExponent:UInt, initialAverage:Sample) {
        divisionBitShift = depthExponent
        bufferSize = UInt(exp2(Double(depthExponent)))
        total = UInt(initialAverage * Sample(bufferSize))
        
        indexBitMask = 0
        var maskBit:UInt = 1
        for _ in 0..<depthExponent {
            indexBitMask |= maskBit
            maskBit <<= 1
        }
        
        buffer = Array<Sample>(count: Int(bufferSize), repeatedValue: initialAverage)
        buffer.reserveCapacity(Int(bufferSize))
        writeIndex = 0
        
    }
    
    func filter(newValue:Sample) -> Sample {
        // adjust total
        total = total - UInt(buffer[Int(writeIndex)])
        total = total + UInt(newValue)
        // store the new value
        buffer[Int(writeIndex)] = newValue
        // adjust writeIndex
        writeIndex += 1
        writeIndex &= indexBitMask
        // do the division and return
        let rval = Sample(total >> divisionBitShift)
//        print("\(buffer) -> \(rval)")
        return rval
    }
    
    func getItemByAge( age:Int ) -> Sample {
        var index:Int = Int(writeIndex) - 1 - age
        while ( index < 0 ) {
            index += Int(bufferSize)
        }
        return buffer[index]
    }
    
}

