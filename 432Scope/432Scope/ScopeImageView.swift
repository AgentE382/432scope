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
//    var vvRange:VoltageRange = (CONFIG_AFE_VOLTAGE_RANGE.min, CONFIG_AFE_VOLTAGE_RANGE.max)
//    var tvRange:TimeRange = (0.0, 2.0)
    
    // grid info
//    var voltageGridPositions:[CGFloat] = []
//    var timeGridPositions:[CGFloat] = []
//    var voltageGridLines:[GridLine] = []
//    var timeGridLines:[GridLine] = []
//    var groundLineYCoord:CGFloat = 100
    
    //
    // PLOTTING SAMPLE VALUES ON SCREEN
    //
    
    var sampleVisibleRange:(min:Int, max:Int) = (0,Int(Sample.max))
    var sampleScaleFactor:CGFloat = 0.001
    
    func recalculateSampleTranslationFactor( ch:Int ) {
        sampleVisibleRange.min = channels[ch].translateVoltageToSample(ScopeViewMath.vvRange.min)
        sampleVisibleRange.max = channels[ch].translateVoltageToSample(ScopeViewMath.vvRange.max)
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
        let sampleArray = channels[ch].getSampleRange(ScopeViewMath.tvRange)
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

    let gridLineLabelAttributes:[String:AnyObject] = [ NSForegroundColorAttributeName: NSColor(calibratedWhite:0.6, alpha:1.0),
                                                       NSFontAttributeName: NSFont(name:"Menlo", size:10.0)! ]
    
//    let gridLineLabelFrequency:Int = 2 // draw every 2nd label.
    
    func drawGridLines( ) {
        // GRIDLINES
        colorGridLine.setFill()
        
//        var labelCounter = 1
        // VERTICAL (TIME) GRIDLINES
        for tLine in ScopeViewMath.timeGridLines {
            
            // line
            tLine.color.setFill()
            NSRectFill(NSRect(x: tLine.lineCoord, y: 0, width: 1, height: frame.height))
            
/*            if ( labelCounter < gridLineLabelFrequency ) {
                labelCounter += 1
                continue
            }
            labelCounter=1*/
            
            if let lineLabel = tLine.label {
                let stringSize = lineLabel.sizeWithAttributes(gridLineLabelAttributes)
                lineLabel.drawAtPoint(NSPoint(x:tLine.lineCoord, y:frame.height-stringSize.height), withAttributes: gridLineLabelAttributes)
            }
        }
        
//        labelCounter = 1
        // HORIZONTAL (VOLTAGE) GRIDLINES
        for vLine in ScopeViewMath.voltageGridLines {
            
            vLine.color.setFill()
            NSRectFill(NSRect(x: 0, y: vLine.lineCoord, width: frame.width, height: 1))
            
/*            if ( labelCounter < gridLineLabelFrequency ) {
                labelCounter += 1
                continue
            }
            labelCounter=1*/
            
            if let lineLabel = vLine.label {
                let stringSize = lineLabel.sizeWithAttributes(gridLineLabelAttributes)
                lineLabel.drawAtPoint(NSPoint(x:frame.width-stringSize.width, y:vLine.lineCoord), withAttributes: gridLineLabelAttributes)
            }
        }
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
