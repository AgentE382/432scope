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
    // SAMPLE PLOTTING
    //
    
    func drawSamplesPointArray(ch:Int) {
        // default view performance: 22%ish
        
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
    
    func drawSample_CoreGraphics(chIndex:Int) {
        // about the same so far.
        
        // around 350k samples on screen, CPU usage is 100% with all the drawing code commmented out, JUST
        // the array pull happening.  So the array pull becomes an issue at large view spans.

        
        let ch = channels[chIndex]
        ch.traceColor.setStroke()
        
        // get the samples, their count, their spacing, starting X ...
        let samples = ch.sampleBuffer.getSampleRange(ScopeViewMath.tvRange)
        let sampleXSpacing:CGFloat = frame.width / CGFloat(samples.count)
        let pixelWidthInSamples:CGFloat = CGFloat(samples.count) / frame.width
        var xPosition = frame.width
        
        Swift.print("samples on screen: \(samples.count)\t\t sampleXSpacing: \(sampleXSpacing)\t\tpixelWidthInSamples: \(pixelWidthInSamples)")

        
        let currentContext = NSGraphicsContext.currentContext()?.CGContext
        let cgPath = CGPathCreateMutable()
        
        CGPathMoveToPoint(cgPath, nil, xPosition, samples[0].asCoordinate())
        
        for i in 1..<samples.count {
            xPosition -= sampleXSpacing
            CGPathAddLineToPoint(cgPath, nil, xPosition, samples[i].asCoordinate())

        }

        CGContextAddPath(currentContext, cgPath)
        CGContextStrokePath(currentContext)
        
    }
    
    func drawSample_minmax(chIndex:Int) {
        // about the same so far.
        
        // around 350k samples on screen, CPU usage is 100% with all the drawing code commmented out, JUST
        // the array pull happening.  So the array pull becomes an issue at large view spans.

        
        let ch = channels[chIndex]
        ch.traceColor.setStroke()
        var fillColor = ch.traceColor.colorWithAlphaComponent(0.5)
        fillColor.setFill()
        
        // get the samples, their count, their spacing, starting X ...
        let samples = ch.sampleBuffer.getSampleRange(ScopeViewMath.tvRange)
        let pixelWidthInSamples:CGFloat = CGFloat(samples.count) / frame.width
        
        Swift.print("\nsamples on screen: \(samples.count)\t\tpixelWidthInSamples: \(pixelWidthInSamples)")
        
        //
        // MATH HELPERS for minmax-based drawing
        //
        func getLocalMinMax(startingIndex:Int, sampleCount:Int) -> (min:Sample, max:Sample) {
            if (sampleCount <= 1) {
                return (min:samples[startingIndex], max:samples[startingIndex])
            }
            var min:Sample = Sample.max
            var max:Sample = Sample.min
            for i in startingIndex..<(startingIndex+sampleCount) {
                if (samples[i] < min) {
                    min = samples[i]
                }
                if (samples[i] > max) {
                    max = samples[i]
                }
            }
            return (min:min, max:max)
        }
        
        let currentContext = NSGraphicsContext.currentContext()?.CGContext
        

        
        // these are used to keep track of where we are in the sample buffer
        var frameStartIndex:CGFloat = 0;
        let frameSampleCount:Int = Int(ceil(pixelWidthInSamples))
        
        // set up the CGPath object we'll use for drawing ...
        let cgPath = CGPathCreateMutable()
        CGPathMoveToPoint(cgPath, nil, frame.width, samples[0].asCoordinate())

         // get all the local Min/Max'es
        var minmaxes:[(min:Sample, max:Sample)] = []
        minmaxes.reserveCapacity(Int(ceil(frame.width)))
        for _ in 0..<Int(frame.width) {
            minmaxes.append(getLocalMinMax(Int(floor(frameStartIndex)), sampleCount: frameSampleCount))
            frameStartIndex += pixelWidthInSamples
        }
  
        // create a path that traces all the values
        var currentXPixel = frame.width
        for local in minmaxes {
            CGPathAddLineToPoint(cgPath, nil, currentXPixel, local.max.asCoordinate())
            currentXPixel -= 1
        }
        for local in minmaxes.reverse() {
            currentXPixel += 1
            CGPathAddLineToPoint(cgPath, nil, currentXPixel, local.min.asCoordinate())
        }
        
        CGContextAddPath(currentContext, cgPath)
        CGContextDrawPath(currentContext,.FillStroke)
    }
    
    func drawSamples_minmax_inplace(chIndex:Int) {
        // THE PURPOSE OF THIS FUNCTION is to start from the one above it, and
        // get rid of the giant memcpy by using the new functions in SampleBuffer.
        
        // NOW we're getting somewhere.  up to 600k samples on screen.
        
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
        ch.traceColor.setStroke()
        let fillColor = ch.traceColor.colorWithAlphaComponent(0.5)
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
        
        // let the boss know we're drawing...
        if let del = notifications {
            del.drawingWillBegin()
        }
        
        // grid lines
        drawGridLines()
        
        // curves
        for ch in 0..<channels.count {
//            drawSample_minmax(ch)
            drawSamples_minmax_inplace(ch)
        }
        
        // let the boss know our work here is done.
        if let del = notifications {
            del.drawingHasFinished()
        }
        
    }
}
