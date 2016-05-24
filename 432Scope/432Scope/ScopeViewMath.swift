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
    static private(set) var vvRange:VoltageRange = VoltageRange(min:-5, max:5)
    static private(set) var tvRange:TimeRange = TimeRange(newest:0.0, oldest:0.05)
    static private(set) var svRange:SampleRange = SampleRange(min:Sample(0), max:CONFIG_SAMPLE_MAX_VALUE)
    static private(set) var voltageGridLines:[GridLine] = []
    static private(set) var timeGridLines:[GridLine] = []
    
    // PRIVATE: the viewable spans, used to detect whether a view has changed size or just position.
    static private(set) var vvRangeSpan:Voltage = 10
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
    static private var voltageGridSpacing:Voltage = 2
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
            svRange.min = self.vvRange.min.asSample()
            svRange.max = self.vvRange.max.asSample()
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
        

        sampleToCoordinateScaleFactor = imageSize.height / CGFloat(svRange.span)
    }
    
    //
    // TEMPORARY SAMPLE TRANSFORM STUFF, for scaling individual channels differently.. caller, YOU MUST REVERT AFTER YOU"RE DONE!
    //
    
    static private(set) var sampleDisplayTransform:(zeroVolts:CGFloat, offset:CGFloat, scaling:CGFloat)? = nil
    
    class func setSampleDisplayTransform(offset:Voltage, scaling:Double) {
        if ((offset == 0) && (scaling == 1.0)) {
            sampleDisplayTransform = nil
        } else {
            sampleDisplayTransform = (
                zeroVolts: CGFloat(Voltage(0.0).asSample()),
                offset: CGFloat(offset.asSampleDiff()),
                scaling: CGFloat(scaling)
            )
            return
        }
    }
    
    class func clearSampleDisplayTransform() {
        sampleDisplayTransform = nil
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
                let label = (-aGridTime).asString()
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
            gridCoords.append(GridLine(lineCoord: centerTime.asCoordinate(), label: Time(0.0).asString(), color: CONFIG_DISPLAY_SCOPEVIEW_GROUNDLINE_COLOR))
            
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
    
    //
    // SELECTION RECTANGLE STUFF
    //
    
    typealias TVCoord = (t:Time, v:Voltage)
    static private var selectionStartPoint:TVCoord? = nil
    static private var selectionEndPoint:TVCoord? = nil
    
    class func updateSelection(point:CGPoint?) {
        if let cgPoint = point {
            // we've been given a new point.  first let's convert it to (t,v)
            var newPoint:TVCoord = (t:0, v:0)
            switch scopeImageViewDisplayState {
            case .Stop, .Timeline:
                newPoint.t = -cgPoint.x.asTime()
                newPoint.v = cgPoint.y.asVoltage()
                break
            case .Trigger:
                let tCorr = imageSize.width.asTimeDiff() / 2
                newPoint.t = cgPoint.x.asTimeDiff() - tCorr
                newPoint.v = cgPoint.y.asVoltage()
                break
            }
            
            if selectionStartPoint == nil {
                // it's a starting point for a new selection.
                selectionStartPoint = newPoint
            } else {
                // it's a drag
                selectionEndPoint = newPoint
            }
            
        } else {
            // we were passed nil, so clear it all.
            selectionStartPoint = nil
            selectionEndPoint = nil
        }
    }
    
    static var selectionRect:CGRect? {
        get {
            if selectionEndPoint == nil {
                return nil
            }
            
            var origin = CGPoint()
            var size = CGSize()
            
            switch scopeImageViewDisplayState {
            case .Stop, .Timeline:
                origin.x = (-selectionStartPoint!.t).asCoordinate()
                origin.y = selectionStartPoint!.v.asCoordinate()
                size.width = (-selectionEndPoint!.t).asCoordinate() - origin.x
                size.height = selectionEndPoint!.v.asCoordinate() - origin.y
                break
                
            case .Trigger:
                let tCorr = imageSize.width / 2
                origin.x = selectionStartPoint!.t.asGraphicsDiff() + tCorr
                origin.y = selectionStartPoint!.v.asCoordinate()
                size.width = (selectionEndPoint!.t.asGraphicsDiff() + tCorr) - origin.x
                size.height = selectionEndPoint!.v.asCoordinate() - origin.y
                break
            }
            
            let rect = CGRect(origin:origin, size:size)
            return rect
        }
    }
    
    class func getSelectionRanges() -> (tRange:TimeRange, vRange:VoltageRange)? {
        if ( selectionEndPoint == nil ) {
            // there isn't a valid selection so we can't return ranges.
            return nil
        }
        let tRange = TimeRange(min: selectionStartPoint!.t, max: selectionEndPoint!.t)
        let vRange = VoltageRange(min: selectionStartPoint!.v, max: selectionEndPoint!.v)
        return (tRange, vRange)
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

