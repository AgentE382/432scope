//
//  ScopeImageView.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/3/16.
//
//

import Cocoa

class ScopeImageView: NSImageView {
    
    //
    // COCOA SILLINESS
    //

    // this prevents Cocoa from trying to draw things which would be behind this view, which is silly because this view covers them completely
    override var opaque:Bool {
        return true
    }
    
    //
    // THE INFO NEEDED TO DRAW SIGNALS
    //
    
    // the channels we're responsible for drawing
    var channels:[Channel] = []
    
    // drawing ranges
    var vvRange:VoltageRange = (CONFIG_AFE_VOLTAGE_RANGE.min, CONFIG_AFE_VOLTAGE_RANGE.max)
    var tvRange:TimeRange = (0.0, 2.0)
    
    // grid info
    var voltageGridPositions:[CGFloat] = []
    var timeGridPositions:[CGFloat] = []
    var groundLineYCoord:CGFloat = 100
    
    //
    // PLOTTING SAMPLE VALUES ON SCREEN
    //
    
    var sampleVisibleRange:(min:Int, max:Int) = (0,Int(Sample.max))
    var sampleScaleFactor:CGFloat = 0.001
    
    func recalculateSampleTranslationFactor( ch:Int ) {
        sampleVisibleRange.min = channels[ch].translateVoltageToSample(vvRange.min)
        sampleVisibleRange.max = channels[ch].translateVoltageToSample(vvRange.max)
        let sampleSpan = sampleVisibleRange.max - sampleVisibleRange.min
        sampleScaleFactor = frame.height / CGFloat(sampleSpan)
    }
    
    func translateSampleToGraphicsY( sample:Sample ) -> CGFloat {
        let sampleHeight = CGFloat(Int(sample)-sampleVisibleRange.min)
        return sampleHeight * sampleScaleFactor
    }

    //
    // DRAWING FUNCTIONS
    //
    
    func drawSamplesBezier( ch:Int ) {
        // this is pretty fast. 13-14% without the NSPointArray involved.

        // set up this channel's color and translation factor
        channels[ch].displayColor.setStroke()
        recalculateSampleTranslationFactor(ch)
        
        // get the samples, their spacing, starting X ...
        let sampleArray = channels[ch].getSampleRange(tvRange)
        let sampleXSpacing:CGFloat = frame.width / CGFloat(sampleArray.count-1)
        var xPosition = frame.width
        
        // set up the bezier path object ...
        let bezierPath = NSBezierPath()
        bezierPath.moveToPoint(NSPoint(x: xPosition, y: translateSampleToGraphicsY(sampleArray[0])))
        
        // add the points
        for sample in sampleArray {
            bezierPath.lineToPoint(NSPoint(x: xPosition, y: translateSampleToGraphicsY(sample)))
            xPosition -= sampleXSpacing
        }
        
        // draw
        bezierPath.stroke()
    }
    
    func drawGridLines( ) {
        // GRIDLINES
        colorGridLine.setFill()
        // VERTICAL (TIME) GRIDLINES
        for xCoord in timeGridPositions {
            NSRectFill(NSRect(x: xCoord, y: 0, width: 1, height: frame.height))
        }
        // HORIZONTAL (VOLTAGE) GRIDLINES
        for yCoord in voltageGridPositions {
            NSRectFill(NSRect(x: 0, y: yCoord, width: frame.width, height: 1))
        }
        // GROUND LINE
        colorGroundLine.setFill()
        NSRectFill(NSRect(x: 0, y: groundLineYCoord, width: frame.width, height: 1))
    }

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
        var nsgc:NSGraphicsContext? = nil
        if ( CONFIG_DISPLAY_ENABLE_ANTIALIASING == false ) {
            nsgc = NSGraphicsContext.currentContext()
            nsgc?.saveGraphicsState()
            nsgc?.shouldAntialias = false
        }
        
        // Black background
        colorBackground.setFill()
        NSRectFill(NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        
        // grid lines
        drawGridLines()
        
        // curves
        for ch in 0..<channels.count {
            drawSamplesBezier(ch)
        }
        
        if ( CONFIG_DISPLAY_ENABLE_ANTIALIASING == false ) {
            nsgc?.restoreGraphicsState()
        }
    }
}
