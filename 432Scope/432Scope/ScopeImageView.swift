//
//  ScopeImageView.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/3/16.
//
//

import Cocoa

class ScopeImageView: NSImageView {
    
    // this prevents Cocoa from trying to draw things which would be behind this view, which is silly because this view covers them completely
    override var opaque:Bool {
        return true
    }

    var channels:[Channel] = []

    //
    // TRACE PLOTTING
    //
    
    func drawSamplesPointArray(ch:Int) {
        // one channel: ~22%, yeah, it's a little faster ...
        
        // set up this channel's color and translation factor
        channels[ch].traceColor.setStroke()
        
        // get the samples, their count, their spacing, starting X ...
        let samples = channels[ch].sampleBuffer.getSampleRange(ScopeViewMath.tvRange)
        let sampleXSpacing:CGFloat = frame.width / CGFloat(samples.count)
        var xPosition = frame.width
        
        // set up the bezier path object ...
        let bezierPath = NSBezierPath()
        bezierPath.moveToPoint(NSPoint(x: xPosition, y: samples[0].asCoordinate() ))
        
        // build an array of points from the first slice
        let points = NSPointArray.alloc(samples.count)
        for i in 0..<samples.count {
            points[i] = NSPoint(x: xPosition, y: samples[i].asCoordinate() )
            xPosition -= sampleXSpacing
        }

        bezierPath.appendBezierPathWithPoints(points, count: samples.count)

        points.dealloc(samples.count)
        
        // draw.  DO NOT closePath!!
        bezierPath.stroke()
    }

    //
    // GRID DRAWING
    //
    
    let gridLineLabelAttributes:[String:AnyObject] = [ NSForegroundColorAttributeName: NSColor(calibratedWhite:0.6, alpha:1.0),NSFontAttributeName: NSFont(name:"Menlo", size:10.0)! ]
    
    func drawGridLines( ) {
        // GRIDLINES
        CONFIG_DISPLAY_SCOPEVIEW_GRIDLINE_COLOR.setFill()
        
        // VERTICAL (TIME) GRIDLINES
        for tLine in ScopeViewMath.timeGridLines {
            // line
            tLine.color.setFill()
            NSRectFill(NSRect(x: tLine.lineCoord, y: 0, width: 1, height: frame.height))
            // label
            if let lineLabel = tLine.label {
                let stringSize = lineLabel.sizeWithAttributes(gridLineLabelAttributes)
                lineLabel.drawAtPoint(NSPoint(x:tLine.lineCoord, y:frame.height-stringSize.height), withAttributes: gridLineLabelAttributes)
            }
        }
        
        // HORIZONTAL (VOLTAGE) GRIDLINES
        for vLine in ScopeViewMath.voltageGridLines {
            //line
            vLine.color.setFill()
            NSRectFill(NSRect(x: 0, y: vLine.lineCoord, width: frame.width, height: 1))
            //label
            if let lineLabel = vLine.label {
                let stringSize = lineLabel.sizeWithAttributes(gridLineLabelAttributes)
                lineLabel.drawAtPoint(NSPoint(x:frame.width-stringSize.width, y:vLine.lineCoord), withAttributes: gridLineLabelAttributes)
            }
        }
    }
    
    //
    // DRAWING MAIN
    //

    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)
  
        // Black background
        CONFIG_DISPLAY_SCOPEVIEW_BACKGROUND_COLOR.setFill()
        NSRectFill(NSRect(x: 0, y: 0, width: frame.width, height: frame.height))
        
        // recompute if necessary
        
        // grid lines
        drawGridLines()
        
        // curves
        for ch in 0..<channels.count {
            drawSamplesPointArray(ch)
        }
        globalDrawActive = false
    }
}

var globalDrawActive:Bool = false
