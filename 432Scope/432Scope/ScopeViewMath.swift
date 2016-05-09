//
//  ScopeViewMath.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation
import Cocoa

class ScopeViewMath {
    
    // GETTABLE: the view data set maintained here, needed for drawing.
    static private(set) var imageSize:CGSize = CGSize()
    static private(set) var vvRange:VoltageRange = VoltageRange(min:-20, max:20)
    static private(set) var tvRange:TimeRange = TimeRange(newest:0.0, oldest:0.05)
    static private(set) var voltageGridLines:[GridLine] = []
    static private(set) var timeGridLines:[GridLine] = []
    
    // PRIVATE: the viewable spans, used to detect whether a view has changed size or just position.
    static private var vvRangeSpan:Voltage = 40
    static private var tvRangeSpan:Time = 0.05
    
    // PRIVATE: scaling factors which must get recalculated whenever the view zooms or changes size.
    static private var voltageScaleFactor:Voltage = 0
    static private var timeScaleFactor:CGFloat = 0
    static private var yDiffToVoltageScaleFactor:Voltage = 0.01
    static private var xDiffToTimeScaleFactor:Time = 0.01
    
    // PRIVATE: the grid spacing, also subject to recalculation.
    static private var voltageGridSpacing:Voltage = 5
    static private var timeGridSpacing:Time = 0.02
    
    class func initializeViewMath( ) {
        initializeGridSpacingCalculator()
    }
    
    //
    // UPDATE()
    //
    // the view controller calls this when something has changed due to pan, zoom, whatever.
    // this function assumes the new ranges have been sanity-checked already.
    //

    class func update( imageSize:CGSize?, vvRange:VoltageRange?, tvRange:TimeRange? ) {
        
        // something about the view has changed, and it's being passed to us here.  if a parameter is nil, that means it hasn't changed so we can ignore it.
        
        // recalculate scaling factors?  window resize or zoom, not pan.  they depend on rangeSpan and imageSize.
        
        // recalculate grid spacing? window resize or zoom, not pan.
        
        // recalculate grid lines? on any change.
        
        var needScalingFactors:Bool = false
        var needVGridSpacing:Bool = false
        var needVGridLines:Bool = false
        var needTGridSpacing:Bool = false
        var needTGridLines:Bool = false
        
        if let newImageSize = imageSize {
            self.imageSize = newImageSize
            needScalingFactors = true
            needVGridSpacing = true
            needTGridSpacing = true
            needVGridLines = true
            needTGridLines = true
        }
        
        if let newVoltageRange = vvRange {
            self.vvRange = clampVoltageDisplayRange(newVoltageRange)
            let newVVRangeSpan = self.vvRange.max - self.vvRange.min
            // did we zoom or pan?
            if (newVVRangeSpan == self.vvRangeSpan) {
                // span is the same, so it's just a pan.
                needVGridLines = true
            } else {
                // span has changed, meaning zoom.
                needScalingFactors = true
                needVGridSpacing = true
                needVGridLines = true
            }
            self.vvRangeSpan = newVVRangeSpan
        }
        
        if let newTimeRange = tvRange {
            self.tvRange = clampTimeDisplayRange(newTimeRange)
            let newTVRangeSpan = self.tvRange.oldest - self.tvRange.newest
            // did we zoom or pan?
            if (newTVRangeSpan == self.tvRangeSpan) {
                // span didn't change, so it's just a pan
                needTGridLines = true
            } else {
                // it's a zoom.
                needScalingFactors = true
                needTGridSpacing = true
                needTGridLines = true
            }
            self.tvRangeSpan = newTVRangeSpan
        }
        
        if ( needScalingFactors) {
            recalculateScalingFactors()
        }
        if ( needVGridSpacing ) {
            recalculateVoltageGridSpacing()
        }
        if ( needTGridSpacing ) {
            recalculateTimeGridSpacing()
        }
        if ( needVGridLines ) {
            recalculateVoltageGridLines()
        }
        if ( needTGridLines ) {
            recalculateTimeGridLines()
        }
    }
    
    //
    // VIEW RANGE BOUNDS CHECKING
    //
    
    class func clampVoltageDisplayRange( range:VoltageRange ) -> VoltageRange {
        if ( range.span > CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.max ) {
            // zoomed out too far
            return CONFIG_DISPLAY_VOLTAGE_LIMITS
        }
        if ( range.span < CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.min ) {
            // zoomed in too far
            return VoltageRange(center: range.center, span: CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.min)
        }
        if ( range.min < CONFIG_DISPLAY_VOLTAGE_LIMITS.min ) {
            return VoltageRange(min: CONFIG_DISPLAY_VOLTAGE_LIMITS.min, span: range.span)
        }
        if ( range.max > CONFIG_DISPLAY_VOLTAGE_LIMITS.max ) {
            return VoltageRange(max: CONFIG_DISPLAY_VOLTAGE_LIMITS.max, span: range.span)
        }
        return range
    }
    
    class func clampTimeDisplayRange( range:TimeRange ) -> TimeRange {
        if ( range.span > CONFIG_DISPLAY_TIME_SPAN_LIMITS.max ) {
            // zoomed out too far
            return CONFIG_DISPLAY_TIME_LIMITS
        }
        if ( range.span < CONFIG_DISPLAY_TIME_SPAN_LIMITS.min ) {
            // zoomed in too far
            return TimeRange(center: range.center, span: CONFIG_DISPLAY_TIME_SPAN_LIMITS.min)
        }
        if ( range.newest < CONFIG_DISPLAY_TIME_LIMITS.newest ) {
            return TimeRange(newest: CONFIG_DISPLAY_TIME_LIMITS.newest, span: range.span)
        }
        if ( range.oldest > CONFIG_DISPLAY_TIME_LIMITS.oldest ) {
            return TimeRange(oldest: CONFIG_DISPLAY_TIME_LIMITS.oldest, span: range.span)
        }
        return range
    }
    
    //
    // COORDINATE SCALING FACTORS
    //
    
    class private func recalculateScalingFactors( ) {
        // precalculate scaling factors for various coordinate conversions
        voltageScaleFactor = Voltage(imageSize.height)/vvRangeSpan
        timeScaleFactor = imageSize.width / tvRangeSpan
        yDiffToVoltageScaleFactor = vvRangeSpan / Voltage(imageSize.height)
        xDiffToTimeScaleFactor = tvRangeSpan / Time(imageSize.width)
    }
    
    //
    // GRID SPACING
    //
    
    // The grid line spacings should go 1,2,5,10,20,50 .. etc.. so we must precalculate the points where the multiplier changes.  This must be initialized before it will do anything intelligent.
    
    static private var gridCalculatorTwosArray:[Double] = []
    static private var gridCalculatorFivesArray:[Double] = []
    
    class func initializeGridSpacingCalculator( ) {
        var twos:Double = 20
        var fives:Double = 50
        let iterations = 10
        
        for _ in 1...iterations {
            gridCalculatorTwosArray.append( twos )
            gridCalculatorFivesArray.append( fives )
            twos /= 10
            fives /= 10
        }
    }
    
    private class func getBiggerGridSpacing( oldSpacing:Double ) -> Double {
        if ( gridCalculatorTwosArray.contains(oldSpacing) ) {
            return oldSpacing * 2.5
        }
        return oldSpacing * 2
    }
    
    private class func getSmallerGridSpacing( oldSpacing:Double ) -> Double {
        if ( gridCalculatorFivesArray.contains(oldSpacing) ) {
            return oldSpacing / 2.5
        }
        return oldSpacing / 2
    }
    
    private class func recalculateVoltageGridSpacing( ) {
        while ( true ) {
            // get a couple of coords at the current spacing.
            let highTest = Translate.toGraphics(voltageGridSpacing)
            let lowTest = Translate.toGraphics(Voltage(0.0))
            let pixelSpacing = highTest - lowTest
            if ( pixelSpacing < CONFIG_DISPLAY_VOLTAGE_GRID_CONSTANT ) {
                // too close. raise the spacing.
                voltageGridSpacing = getBiggerGridSpacing(voltageGridSpacing)
                continue
            }
            if ( pixelSpacing > (CONFIG_DISPLAY_VOLTAGE_GRID_CONSTANT*2.6)) {
                // too far apart. lower the spacing.
                voltageGridSpacing = getSmallerGridSpacing(voltageGridSpacing)
                continue
            }
            // we got here so it's fine.
            break;
        }
    }
    
    private class func recalculateTimeGridSpacing( ) {
        while ( true ) {
            // get a couple of coords at the current spacing.
            let highTest = Translate.toGraphics(Time(0))
            let lowTest = Translate.toGraphics(timeGridSpacing)
            let pixelSpacing = highTest - lowTest
            if ( pixelSpacing < CONFIG_DISPLAY_TIME_GRID_CONSTANT ) {
                // too close. raise the spacing.
                timeGridSpacing = Time(getBiggerGridSpacing(Double(timeGridSpacing)))
                continue
            }
            if ( pixelSpacing > (CONFIG_DISPLAY_TIME_GRID_CONSTANT*2.6)) {
                // too far apart. lower the spacing.
                timeGridSpacing = Time(getSmallerGridSpacing(Double(timeGridSpacing)))
                continue
            }
            // we got here so it's fine.
            break;
        }
    }
    
    //
    // GRID LINES THEMSELVES
    //
    
    private class func recalculateTimeGridLines( ) {
        let firstGridMultiplier = ceil(tvRange.newest / timeGridSpacing)
        var aGridTime:Time = firstGridMultiplier * timeGridSpacing
        var gridCoords:[GridLine] = []
        while ( aGridTime < tvRange.oldest ) {
            let xPos = Translate.toGraphics(aGridTime)
            let label = getTimeAsString(aGridTime)
            gridCoords.append(GridLine(lineCoord:xPos, label:label))
            aGridTime += timeGridSpacing
        }
        timeGridLines = gridCoords
    }
    
    private class func recalculateVoltageGridLines( ) {
        var gridCoords:[GridLine] = []
        var aGridVoltage:Voltage = voltageGridSpacing
        while ( aGridVoltage < vvRange.max ) {
            if ( aGridVoltage > vvRange.min ) {
                let yPos = Translate.toGraphics(aGridVoltage)
                let label = getVoltageAsString(aGridVoltage)
                gridCoords.append(GridLine(lineCoord:yPos, label:label))
            }
            aGridVoltage += voltageGridSpacing
        }
        // reverse the array so far and add ground, so that at the end we'll have them in order as they appear on screen, and we can add labels to every 2nd or third one easily.
        gridCoords = gridCoords.reverse()
        gridCoords.append(GridLine(lineCoord:Translate.toGraphics(Voltage(0.0)), label:nil, color:colorGroundLine))
        aGridVoltage = -voltageGridSpacing
        while ( aGridVoltage > vvRange.min ) {
            if ( aGridVoltage < vvRange.max ) {
                let yPos = Translate.toGraphics(aGridVoltage)
                let label = getVoltageAsString(aGridVoltage)
                gridCoords.append(GridLine(lineCoord:yPos, label:label))
            }
            aGridVoltage -= voltageGridSpacing
        }
        //print( "V spacing: \(voltageGridSpacing)\t\(gridCoords)")
        voltageGridLines = gridCoords
    }
}

//
// TRANSLATE
// an interface to coordinate system translation math.  It inherits from ScopeViewMath because these translations depend on the scale factors calculated there.
//

class Translate: ScopeViewMath {
    
    class func toGraphics( voltage:Voltage ) -> CGFloat {
        var yVal = voltage - vvRange.min
        yVal *= voltageScaleFactor
        return CGFloat(yVal)
    }
    
    class func toGraphics( time:Time ) -> CGFloat {
        var xVal = time - tvRange.newest
        xVal *= timeScaleFactor
        return CGFloat(imageSize.width - xVal);
    }
    
    class func toVoltage( yCoord:CGFloat ) -> Voltage {
        let inverseScaling = 1 / voltageScaleFactor
        return (Voltage(yCoord)*inverseScaling)+vvRange.min
    }
    
    class func toTime( xCoord:CGFloat ) -> Time {
        let inverseScaling = 1 / timeScaleFactor
        return (Time(imageSize.width-xCoord)*inverseScaling)+tvRange.newest
    }
    
    class func graphicsDeltaToVoltage( yDiff:CGFloat ) -> Voltage {
        return yDiffToVoltageScaleFactor * Voltage(yDiff)
    }
    
    class func graphicsDeltaToTime( xDiff:CGFloat ) -> Time {
        return xDiffToTimeScaleFactor * Time(xDiff)
    }
    
}

class GridLine {
    
    //
    // THIS is really just a tuple, but it's a class so I could write constructors with sane initialization values.
    //
    
    var lineCoord:CGFloat = 0
    var label:String? = nil
    var color:NSColor = colorGridLine
    
    init( ) {
        lineCoord = 0
        label = nil
    }
    
    init( lineCoord:CGFloat ) {
        self.lineCoord = lineCoord
        label = nil
    }
    
    init( lineCoord:CGFloat, label:String? ) {
        self.lineCoord = lineCoord
        self.label = label
    }
    
    init( lineCoord:CGFloat, label:String?, color:NSColor ) {
        self.lineCoord = lineCoord
        self.label = label
        self.color = color
    }
}

class VoltageRange {
    var min:Voltage = 0
    var max:Voltage = 1
    
    var span:Voltage {
        get {
            return (self.max - self.min)
        }
        set(newSpan) {
            let newHalfSpan = newSpan/2
            let oldCenter = self.center
            self.min = oldCenter - newHalfSpan
            self.max = oldCenter + newHalfSpan
        }
    }
    
    var center:Voltage {
        get {
            return (self.max + self.min) / 2
        }
        set(newCenter) {
            let oldHalfSpan = self.halfSpan
            self.min = newCenter - oldHalfSpan
            self.max = newCenter + oldHalfSpan
        }
    }
    
    var halfSpan:Voltage {
        get {
            return span / 2
        }
        set(newHalfSpan) {
            let oldCenter = self.center
            self.min = oldCenter - newHalfSpan
            self.max = oldCenter + newHalfSpan
        }
    }
    
    init(min:Voltage, max:Voltage) {
        self.min = min
        self.max = max
    }
    
    init(center:Voltage, span:Voltage) {
        let newHalfSpan = span / 2
        min = center - newHalfSpan
        max = center + newHalfSpan
    }
    
    init(center:Voltage, halfSpan:Voltage) {
        min = center - halfSpan
        max = center + halfSpan
    }
    
    init(min:Voltage, span:Voltage) {
        self.min = min
        self.max = min+span
    }
    
    init(max:Voltage, span:Voltage) {
        self.min = max-span
        self.max = max
    }
}

class TimeRange {
    var newest:Time = 0
    var oldest:Time = 1
    
    var span:Time {
        get {
            return (self.oldest - self.newest)
        }
        set(newSpan) {
            let newHalfSpan = newSpan/2
            let oldCenter = self.center
            self.newest = oldCenter - newHalfSpan
            self.oldest = oldCenter + newHalfSpan
        }
    }
    
    var center:Time {
        get {
            return (self.oldest + self.newest) / 2
        }
        set(newCenter) {
            let oldHalfSpan = self.halfSpan
            self.newest = newCenter - oldHalfSpan
            self.oldest = newCenter + oldHalfSpan
        }
    }
    
    var halfSpan:Time {
        get {
            return span / 2
        }
        set(newHalfSpan) {
            let oldCenter = self.center
            self.newest = oldCenter - newHalfSpan
            self.oldest = oldCenter + newHalfSpan
        }
    }
    
    init(newest:Time, oldest:Time) {
        self.newest = newest
        self.oldest = oldest
    }
    
    init(center:Time, span:Time) {
        let newHalfSpan = span / 2
        newest = center - newHalfSpan
        oldest = center + newHalfSpan
    }
    
    init(center:Time, halfSpan:Time) {
        newest = center - halfSpan
        oldest = center + halfSpan
    }
    
    init(newest:Time, span:Time) {
        self.newest = newest
        self.oldest = newest+span
    }
    
    init(oldest:Time, span:Time) {
        self.newest = oldest-span
        self.oldest = oldest
    }
}

