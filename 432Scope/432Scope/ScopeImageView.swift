//
//  ScopeImageView.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/3/16.
//
//

import Cocoa

protocol ScopeImageViewNotifications {
    func drawingWillBegin()
    func drawingHasFinished()
}

class ScopeImageView: NSImageView {
    
    
    // this prevents Cocoa from trying to draw things which would be behind this view, which is silly because this view covers them completely
    override var opaque:Bool {
        return true
    }

    var notifications:ScopeImageViewNotifications? = nil
    var channels:[Channel] = []
    
    //
    // SELECTION BOX
    //
    
    private var selectionBoxPhase:CGFloat = 0
    private var selectionBoxPhaseDelta:CGFloat = 0.5
    
    func drawSelection() {
        guard ScopeViewMath.selectionRect != nil else {
            return
        }
        
        let color = NSColor.whiteColor()
        color.setStroke()
        
        let currentContext = NSGraphicsContext.currentContext()?.CGContext
        CGContextSetLineDash(currentContext, selectionBoxPhase, [5,5], 2)
        CGContextStrokeRect(currentContext, ScopeViewMath.selectionRect!)
        selectionBoxPhase += selectionBoxPhaseDelta
    }

    //
    // SAMPLE PLOTTING
    //
    
    func drawSamples_minmax_inplace(chIndex:Int) {
        let ch = channels[chIndex]
        
        // get all the local minmaxes
        let minmaxes = ch.sampleBuffer.getSubRangeMinMaxes(ScopeViewMath.tvRange, howManySubranges: Int(frame.width))
        
        // we can start our path now at the first sample ...
        let cgPath = CGPathCreateMutable()
        CGPathMoveToPoint(cgPath, nil, frame.width, CGFloat(ch.sampleBuffer.getSampleAtTime(ScopeViewMath.tvRange.newest)))
        // trace the maxes ...
        var currentXPixel = frame.width
        for local in minmaxes {
            CGPathAddLineToPoint(cgPath, nil, currentXPixel, local.max.asCoordinate())
            currentXPixel -= 1
        }
        // .. now trace the mins
        for local in minmaxes.reverse() {
            currentXPixel += 1
            CGPathAddLineToPoint(cgPath, nil, currentXPixel, local.min.asCoordinate())
        }
        
        // set the color
        let color = ch.displayProperties.traceColor
        color.setStroke()
        let fillColor = color.colorWithAlphaComponent(0.5)
        fillColor.setFill()
        
        // draw them
        let currentContext = NSGraphicsContext.currentContext()?.CGContext
        CGContextAddPath(currentContext, cgPath)
        CGContextDrawPath(currentContext,.FillStroke)
    }


    //
    // GRID LINES
    //
    
    let gridLineLabelAttributes:[String:AnyObject] = [ NSForegroundColorAttributeName: NSColor(calibratedWhite:0.6, alpha:1.0),NSFontAttributeName: NSFont(name:"Menlo", size:10.0)! ]
    
    func drawGridLines( ) {
        // GRIDLINES
        
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        // VERTICAL (TIME) GRIDLINES
        for tLine in ScopeViewMath.timeGridLines {
            // line
            tLine.color.setStroke()
            let path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, tLine.lineCoord, 0)
            CGPathAddLineToPoint(path, nil, tLine.lineCoord, frame.height)
            CGContextAddPath(context, path)
            CGContextStrokePath(context)
            // label
            if let lineLabel = tLine.label {
                let stringSize = lineLabel.sizeWithAttributes(gridLineLabelAttributes)
                lineLabel.drawAtPoint(NSPoint(x:tLine.lineCoord, y:frame.height-stringSize.height), withAttributes: gridLineLabelAttributes)
            }
        }
        
        // HORIZONTAL (VOLTAGE) GRIDLINES
        for vLine in ScopeViewMath.voltageGridLines {
            //line
            vLine.color.setStroke()
            let path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, 0, vLine.lineCoord)
            CGPathAddLineToPoint(path, nil, frame.width, vLine.lineCoord)
            CGContextAddPath(context, path)
            CGContextStrokePath(context)
//            NSRectFill(NSRect(x: 0, y: vLine.lineCoord, width: frame.width, height: 1))
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
        
        // let the boss know we're drawing...
        if let del = notifications {
            del.drawingWillBegin()
        }
        
        // grid lines
        drawGridLines()
        
        // curves
        for ch in 0..<channels.count {
            if ( channels[ch].displayProperties.visible == true ) {
                ScopeViewMath.setSampleDisplayTransform(channels[ch].displayProperties.offset,
                                                        scaling: channels[ch].displayProperties.scaling)
                drawSamples_minmax_inplace(ch)
                ScopeViewMath.clearSampleDisplayTransform()
            }
        }
        
        // selection rectangle
        drawSelection()
        
        // let the boss know our work here is done.
        if let del = notifications {
            del.drawingHasFinished()
        }
        
    }
}
