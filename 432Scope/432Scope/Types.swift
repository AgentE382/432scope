//
//  Types.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/10/16.
//
//

import Foundation

/*
 This file is organized top-down.
    -Basic types, range types.
    -Basic type extensions (mostly for translating)
    -Range type protocol and base class
    -Range type extensions
    -Low-level math
 */

//
// DATA TYPES
//

typealias Sample = Int
typealias Voltage = Double
typealias SampleIndex = Int
typealias Time = CGFloat
typealias Frequency = Float // this HAS to be different from Double because swift won't let me extend two typealiases separately.  This is really annoying.

typealias VoltageRange = FloatingRangeType<Voltage>
typealias TimeRange = FloatingRangeType<Time>

// these are array indices
typealias SampleIndexRange = (newest:Int, oldest:Int)

//
// BASIC TYPE EXTENSIONS
//

extension Sample: RangeableType {
    
    func asVoltage( ) -> Voltage {
        return CONFIG_AFE_VOLTAGE_RANGE.min + (Voltage(self)*ScopeViewMath.sampleToVoltageScaleFactor)
    }
    
    func asCoordinate( ) -> CGFloat {
        return ScopeViewMath.sampleToCoordinateScaleFactor * CGFloat(self - ScopeViewMath.svRange.min)
    }
}

extension Voltage: RangeableType {
    
    func asString( ) -> String {
        if ( abs(self) < 0.001 ) {
            // display micro volts
            let displayNumber = self * 1000
            return String(format:"%3.4f", displayNumber) + " \u{03BC}V"
        }
        if ( abs(self) < 1 ) {
            // display millivolts
            let displayNumber = self * 1000
            return String(format:"%3.4f", displayNumber) + " mV"
        }
        return String(format:"%.4f", self) + " V"
    }
    
    func asCoordinate( ) -> CGFloat {
        var yVal = self - ScopeViewMath.vvRange.min
        yVal *= ScopeViewMath.voltageScaleFactor
        return CGFloat(yVal)
    }
    
    func asSample( ) -> Sample {
        return Sample( (self - CONFIG_AFE_VOLTAGE_RANGE.min) * ScopeViewMath.voltageToSampleScaleFactor)
    }
    
    // if something moves by (self) volts, how many pixels does it move by?  ask this function.
    func asGraphicsDiff( ) -> CGFloat {
        return CGFloat(self * ScopeViewMath.voltageScaleFactor)
    }
}

extension SampleIndex {
    func asTime() -> Time {
        return Time(self) * CONFIG_SAMPLEPERIOD
    }
}

extension Time: RangeableType, IsTime {
    
    func asString( ) -> String {
        if ( abs(self) < 0.001 ) {
            // display micro
            let displayNumber = self * 1000
            return String(format:"%3.4f", displayNumber) + " \u{03BC}S"
        }
        if ( abs(self) < 1 ) {
            // display milli
            let displayNumber = self * 1000
            return String(format:"%3.4f", displayNumber) + " mS"
        }
        return String(format:"%.4f", self) + " S"
    }
    
    func asCoordinate( ) -> CGFloat {
        var xVal = self - ScopeViewMath.tvRange.newest
        xVal *= ScopeViewMath.timeScaleFactor
        return CGFloat(ScopeViewMath.imageSize.width - xVal);
    }
    
    func asSampleIndex( ) -> SampleIndex {
        return SampleIndex(nearbyint(self*Time(CONFIG_SAMPLERATE)))
    }
    
    func asGraphicsDiff( ) -> CGFloat {
        return CGFloat(self * ScopeViewMath.timeScaleFactor)
    }
}

extension Frequency {
    func asString(  ) ->String {
        return String(format:"%.2f", self) + " Hz"
    }
}

extension CGFloat {
    
    // if self is a ScopeImageView coordinate, these translate it to Time (x) or Voltage (y).
    func asTime( ) -> Time {
        return (Time(ScopeViewMath.imageSize.width-self)*ScopeViewMath.inverseTimeScaleFactor)+ScopeViewMath.tvRange.newest
    }
    
    func asVoltage( ) -> Voltage {
        return (Voltage(self)*ScopeViewMath.inverseVoltageScaleFactor)+ScopeViewMath.vvRange.min
    }
    
    // diff translates.  if self is a distance along x or y axes of ScopeImageView, these return the corresponding difference in time or voltage.
    func asTimeDiff( ) -> Time {
        return ScopeViewMath.inverseTimeScaleFactor * Time(self)
    }
    
    func asVoltageDiff( ) -> Voltage {
        return ScopeViewMath.inverseVoltageScaleFactor * Voltage(self)
    }
}


/*
 This is the operator protocol + boundable range generic struct.  All the *Range types are derived from this.
 */

protocol RangeableType:Comparable {
    func +(lhs: Self, rhs: Self) -> Self
    func -(lhs: Self, rhs: Self) -> Self
    func /(lhs: Self, rhs: Self) -> Self
    init(_ v: Int)
}

struct FloatingRangeType<T:RangeableType> {
    var min:T
    var max:T
    
    var span:T {
        get {
            return (self.max - self.min)
        }
        set(newSpan) {
            let newHalfSpan = newSpan/T(2)
            let oldCenter = self.center
            self.min = oldCenter - newHalfSpan
            self.max = oldCenter + newHalfSpan
        }
    }
    
    var center:T {
        get {
            return (self.max + self.min) / T(2)
        }
        set(newCenter) {
            let oldHalfSpan = self.halfSpan
            self.min = newCenter - oldHalfSpan
            self.max = newCenter + oldHalfSpan
        }
    }
    
    var halfSpan:T {
        get {
            return span / T(2)
        }
        set(newHalfSpan) {
            let oldCenter = self.center
            self.min = oldCenter - newHalfSpan
            self.max = oldCenter + newHalfSpan
        }
    }
    
    init(min:T, max:T) {
        self.min = min
        self.max = max
    }
    
    init(center:T, span:T) {
        let newHalfSpan = span / T(2)
        min = center - newHalfSpan
        max = center + newHalfSpan
    }
    
    init(center:T, halfSpan:T) {
        min = center - halfSpan
        max = center + halfSpan
    }
    
    init(min:T, span:T) {
        self.min = min
        self.max = min+span
    }
    
    init(max:T, span:T) {
        self.min = max-span
        self.max = max
    }
    
    // TODO: figure out how to put these in an extension JUST FOR TimeRange

}

// This is an extension for TimeRanges.  we have to define a protocol with the ->samplerange translator so that we can constrain the extension to this type ... swift ...
protocol IsTime {
    func asSampleIndex() -> SampleIndex
}

extension FloatingRangeType where T:IsTime {
    
    init(newest:T, oldest:T) {
        min = newest
        max = oldest
    }
    init(newest:T, span:T) {
        self.min = newest
        self.max = newest+span
    }
    init(oldest:T, span:T) {
        self.min = oldest-span
        self.max = oldest
    }
    
    var newest:T {
        get {
            return min
        }
        set(value) {
            min = value
        }
    }
    var oldest:T {
        get {
            return max
        }
        set(value) {
            max = value
        }
    }
    
    func asSampleIndexRange( ) -> SampleIndexRange {
        return (newest: min.asSampleIndex(), oldest: max.asSampleIndex())
    }
}

//
// Some basic math for bounds checking / clamping
//

func clampToRange<T:Comparable>( value:T, bounds:FloatingRangeType<T> ) -> T {
    // if the bounds are messed up, value will be max.  i am not responsible.
    if ( value < bounds.min ) {
        return bounds.min
    }
    if ( value > bounds.max ) {
        return bounds.max
    }
    return value
    
}

func clampToRange<T:Comparable>( value:T, min:T, max:T ) -> T {
    if ( value < min ) {
        return min
    }
    if ( value > max ) {
        return max
    }
    return value
}

func clampToRangeInPlace<T:Comparable>( inout value:T, bounds:FloatingRangeType<T> ) {
    if ( value < bounds.min ) {
        value = bounds.min
        return
    }
    if ( value > bounds.max ) {
        value = bounds.max
        return
    }
}

func clampToRangeInPlace<T:Comparable>( inout value:T, min:T, max:T ) {
    if ( value < min ) {
        value = min
        return
    }
    if ( value > max ) {
        value = max
        return
    }
}

