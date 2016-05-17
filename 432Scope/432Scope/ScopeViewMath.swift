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
    
    // the Scope View state
    enum ScopeImageViewDisplayState {
        case Stop
        case Timeline
        case Trigger(Channel)
    }
    static var scopeImageViewDisplayState:ScopeImageViewDisplayState = .Timeline
    
    // GETTABLE: the view data set maintained here, needed for drawing.
    static private(set) var imageSize:CGSize = CGSize()
    static private(set) var vvRange:VoltageRange = VoltageRange(min:-20, max:20)
    static private(set) var tvRange:TimeRange = TimeRange(newest:0.0, oldest:0.05)
    static private(set) var svRange:(min:Sample, max:Sample) = (0, CONFIG_SAMPLE_MAX_VALUE)
    static private(set) var voltageGridLines:[GridLine] = []
    static private(set) var timeGridLines:[GridLine] = []
    
    // PRIVATE: the viewable spans, used to detect whether a view has changed size or just position.
    static private(set) var vvRangeSpan:Voltage = 40
    static private(set) var tvRangeSpan:Time = 0.05
    
    // PRIVATE: scaling factors which must get recalculated whenever the view zooms or changes size.
    static private(set) var voltageScaleFactor:Voltage = 0
    static private(set) var inverseVoltageScaleFactor:Voltage = 0
    static private(set) var timeScaleFactor:CGFloat = 0
    static private(set) var inverseTimeScaleFactor:CGFloat = 0
    static private(set) var sampleToCoordinateScaleFactor:CGFloat = 0.001
    // These scaling factors are constant but I really want all the scale factors kept in one place.
    static let sampleToVoltageScaleFactor:Voltage = (CONFIG_AFE_VOLTAGE_RANGE.span) / Voltage(CONFIG_SAMPLE_MAX_VALUE)
    static let voltageToSampleScaleFactor:Voltage = Voltage(CONFIG_SAMPLE_MAX_VALUE)/(CONFIG_AFE_VOLTAGE_RANGE.span)
    
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
        
        // we've been sent a new imageSize
        if let newImageSize = imageSize {
            self.imageSize = newImageSize
            needScalingFactors = true
            needVGridSpacing = true
            needTGridSpacing = true
            needVGridLines = true
            needTGridLines = true
        }
        
        // we've been sent new viewable Voltage range
        if let newVoltageRange = vvRange {
            self.vvRange = newVoltageRange
            self.vvRange.clampToSpanLimitsAndOuterBounds(CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.min, maximumSpan: CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.max, outerBounds: CONFIG_DISPLAY_VOLTAGE_LIMITS)
            let newVVRangeSpan = self.vvRange.span
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
        
        // we've been sent new viewable Time range.
        if let newTimeRange = tvRange {
            self.tvRange = newTimeRange
            self.tvRange.clampToSpanLimitsAndOuterBounds(CONFIG_DISPLAY_TIME_SPAN_LIMITS.min, maximumSpan: CONFIG_DISPLAY_TIME_SPAN_LIMITS.max, outerBounds: CONFIG_DISPLAY_TIME_LIMITS)
            let newTVRangeSpan = self.tvRange.span
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
    // COORDINATE SCALING FACTORS
    //
    
    private class func recalculateScalingFactors( ) {
        // precalculate scaling factors for various coordinate conversions
        voltageScaleFactor = Voltage(imageSize.height)/vvRangeSpan
        inverseVoltageScaleFactor = vvRangeSpan / Voltage(imageSize.height)
        timeScaleFactor = imageSize.width / tvRangeSpan
        inverseTimeScaleFactor = tvRangeSpan / Time(imageSize.width)
        
        svRange.min = vvRange.min.asSample() //channels[ch].translateVoltageToSample(ScopeViewMath.vvRange.min)
        svRange.max = vvRange.max.asSample() //channels[ch].translateVoltageToSample(ScopeViewMath.vvRange.max)
        let sampleSpan = svRange.max - svRange.min
        sampleToCoordinateScaleFactor = imageSize.height / CGFloat(sampleSpan)
        
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
            let pixelSpacing = voltageGridSpacing.asGraphicsDiff()
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
            let pixelSpacing = timeGridSpacing.asGraphicsDiff()
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
        // this changes depending on the view mode...
        switch scopeImageViewDisplayState {
            
        case .Stop, .Timeline:
            let firstGridMultiplier = ceil(tvRange.newest / timeGridSpacing)
            var aGridTime:Time = firstGridMultiplier * timeGridSpacing
            var gridCoords:[GridLine] = []
            while ( aGridTime < tvRange.oldest ) {
                let xPos = aGridTime.asCoordinate()
                let label = aGridTime.asString()
                gridCoords.append(GridLine(lineCoord:xPos, label:label))
                aGridTime += timeGridSpacing
            }
            timeGridLines = gridCoords
            break
            
        case .Trigger:
            var gridCoords:[GridLine] = []
            
            // start at the first gridline in positive time, count newer
            let centerTime:Time = tvRange.center
            var aGridTime = centerTime - timeGridSpacing
            while (aGridTime > tvRange.newest) {
                let xPos = aGridTime.asCoordinate()
                let xLabel = (-(aGridTime - centerTime)).asString()
                gridCoords.append(GridLine(lineCoord: xPos, label: xLabel))
                aGridTime -= timeGridSpacing
            }
            // count older
            aGridTime = centerTime + timeGridSpacing
            while ( aGridTime < tvRange.oldest ) {
                let xPos = aGridTime.asCoordinate()
                let xLabel = (-(aGridTime - centerTime)).asString()
                gridCoords.append(GridLine(lineCoord: xPos, label: xLabel))
                aGridTime += timeGridSpacing
            }
            // add t=0 line
            gridCoords.append(GridLine(lineCoord: centerTime.asCoordinate(), label: Time(0.0).asString(), color: NSColor(calibratedWhite: 1.0, alpha: 1.0)))
            
            timeGridLines = gridCoords
            break
        }
    }
    
    private class func recalculateVoltageGridLines( ) {
        var gridCoords:[GridLine] = []
        var aGridVoltage:Voltage = voltageGridSpacing
        while ( aGridVoltage < vvRange.max ) {
            if ( aGridVoltage > vvRange.min ) {
                let yPos = aGridVoltage.asCoordinate()
                let label = aGridVoltage.asString()
                gridCoords.append(GridLine(lineCoord:yPos, label:label))
            }
            aGridVoltage += voltageGridSpacing
        }
        // reverse the array so far and add ground, so that at the end we'll have them in order as they appear on screen, and we can add labels to every 2nd or third one easily.
        gridCoords = gridCoords.reverse()
        gridCoords.append(GridLine(lineCoord:Voltage(0.0).asCoordinate(), label:nil, color:CONFIG_DISPLAY_SCOPEVIEW_GROUNDLINE_COLOR))
        aGridVoltage = -voltageGridSpacing
        while ( aGridVoltage > vvRange.min ) {
            if ( aGridVoltage < vvRange.max ) {
                let yPos = aGridVoltage.asCoordinate()
                let label = aGridVoltage.asString()
                gridCoords.append(GridLine(lineCoord:yPos, label:label))
            }
            aGridVoltage -= voltageGridSpacing
        }
        voltageGridLines = gridCoords
    }
}


struct GridLine {
    
    //
    // THIS is really just a tuple, but it's a struct so I could write constructors with sane init behavior.
    //
    
    var lineCoord:CGFloat = 0
    var label:String? = nil
    var color:NSColor = CONFIG_DISPLAY_SCOPEVIEW_GRIDLINE_COLOR
    
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

