//
//  ScopeViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

var gridCalculatorTwosArray:[Double] = []
var gridCalculatorFivesArray:[Double] = []

func calculateGridArrays( ) {
    var twos:Double = 20
    var fives:Double = 50
    let iterations = 10
    
    for _ in 1...iterations {
        gridCalculatorTwosArray.append( twos )
        gridCalculatorFivesArray.append( fives )
        twos /= 10
        fives /= 10
    }
    
    print("twos: \(gridCalculatorTwosArray)")
    print("fives: \(gridCalculatorFivesArray)")
    print("done")
}

func getBiggerGridSpacing( oldSpacing:Double ) -> Double {
    if ( gridCalculatorTwosArray.contains(oldSpacing) ) {
        return oldSpacing * 2.5
    }
    return oldSpacing * 2
}

func getSmallerGridSpacing( oldSpacing:Double ) -> Double {
    if ( gridCalculatorFivesArray.contains(oldSpacing) ) {
        return oldSpacing / 2.5
    }
    return oldSpacing / 2
}

class ScopeViewController: NSViewController {
    
    //
    // INTERFACE CONNECTIONS
    //
    
    @IBOutlet weak var scopeImage: ScopeImageView!
    @IBOutlet weak var nsbZoomOutX: NSButton!
    @IBOutlet weak var nsbZoomInX: NSButton!
    @IBOutlet weak var nsbZoomOutY: NSButton!
    @IBOutlet weak var nsbZoomInY: NSButton!
    @IBOutlet weak var labelTimeGrid: NSTextField!
    @IBOutlet weak var labelVoltageGrid: NSTextField!

    @IBAction func buttonZoomOutX(sender: AnyObject) {
        zoomX( Time(CONFIG_DISPLAY_MAGNFICATION_FACTOR) )
        recalculateEverything()
    }
    
    @IBAction func buttonZoomInX(sender: AnyObject) {
        zoomX( Time(1/CONFIG_DISPLAY_MAGNFICATION_FACTOR) )
        recalculateEverything()
    }
    
    @IBAction func buttonZoomOutY(sender: AnyObject) {
        zoomY( Voltage(CONFIG_DISPLAY_MAGNFICATION_FACTOR))
        recalculateEverything()
    }
    
    @IBAction func buttonZoomInY(sender: AnyObject) {
        zoomY( Voltage(1/CONFIG_DISPLAY_MAGNFICATION_FACTOR))
        recalculateEverything()
    }
    
    //
    // NSRESPONDER EVENT HANDLING OVERRIDES
    //
    
    // PINCH-TO-ZOOM
    override func magnifyWithEvent(event: NSEvent) {
        // the cocoa event handling guide suggests adding this to 1.0 to create a mag factor, looks pretty good.
        let magnification = event.magnification + 1.0
        zoomX(Time(magnification))
        zoomY(Voltage(magnification))
        recalculateEverything()
    }
    
    // MOUSE WHEEL: view pan. Cmd+mousewheel zooms.
    override func scrollWheel(event:NSEvent) {
        let dX = event.scrollingDeltaX
        let dY = event.scrollingDeltaY
        let modifierFlags = event.modifierFlags
        if (modifierFlags.contains( .CommandKeyMask )) {
            // zoom
            let xMagnifier = (dX / 100) + 1.0
            let yMagnifier = (dY / 100) + 1.0
            zoomX(Time(xMagnifier))
            zoomY(Voltage(yMagnifier))
            recalculateEverything()
        } else {
            // pan
            let dTime = translateGraphicsDeltaToTime(dX)
            tvRange.oldest += dTime
            tvRange.newest += dTime
            clampTimeDisplayRange(&tvRange)
            let dVoltage = translateGraphicsDeltaToVoltage(dY)
            vvRange.min += dVoltage
            vvRange.max += dVoltage
            clampVoltageDisplayRange(&vvRange)
            // just a pan so only a few updates are needed
            updateVisibleRanges()
            recalculateGridPositions()
        }
    }
    
    // MOUSE DRAG EVENTS: not sure what to do with these yet.
    var lastMouseDragPoint:NSPoint? = nil
    override func mouseDragged( theEvent:NSEvent ) {
    }
    
    override func mouseDown( theEvent:NSEvent ) {
        lastMouseDragPoint = NSEvent.mouseLocation()
    }
    
    override func mouseUp( theEvent:NSEvent ) {
        lastMouseDragPoint = nil
    }
    
    //
    // UI HELPERS
    //
    
    func zoomX( magnification:Time ) {
        // get the center point and *new* half-span
        let halfSpan = ((tvRange.oldest - tvRange.newest) / 2) * magnification
        let center = (tvRange.oldest + tvRange.newest) / 2
        
        // update the range, bounds check it
        tvRange = (newest: center-halfSpan, oldest: center+halfSpan)
        clampTimeDisplayRange(&tvRange)
    }
    
    func zoomY( magnification:Voltage ) {
        // get center point, new half-span
        let halfSpan = ( (vvRange.max - vvRange.min) / 2) * magnification
        let center = ( vvRange.max + vvRange.min ) / 2
        
        // update voltageVisibleRange
        vvRange = (min: center - halfSpan, max: center + halfSpan )
        clampVoltageDisplayRange(&vvRange)
    }
    

    //
    // TIMER / NOTIFICATION HANDLERS
    //
    
    func drawTheNextFrame( ) {
        scopeImage.setNeedsDisplay()
    }
    
    // Window resize events go here.
    func viewFrameChanged(notification:NSNotification) {
        recalculateEverything()
    }
    
    //
    // VIEW MATH
    //

    // visibility
    var imageSize = CGSize()
    var vvRange:VoltageRange = (CONFIG_AFE_VOLTAGE_RANGE.min, CONFIG_AFE_VOLTAGE_RANGE.max)
    var tvRange:TimeRange = (0.0, 0.6)
    
    // grid spacings
    var voltageGridSpacing:Voltage = 2
    var timeGridSpacing:Time = 0.25

    // scaling factors which must get recalculated whenever the view changes
    var voltageScaleFactor:Voltage = 0
    var timeScaleFactor:CGFloat = 0
    var yDiffToVoltageScaleFactor:Voltage = 0.01
    var xDiffToTimeScaleFactor:Time = 0.01
    
    func recalculateEverything( ) {
        updateVisibleRanges()
        recalculateScalingFactors()
        recalculateGridSpacing()
        recalculateGridPositions()
    }

    func updateVisibleRanges( ) {
        imageSize = scopeImage.frame.size
        scopeImage.vvRange = vvRange
        scopeImage.tvRange = tvRange
    }
    
    func recalculateScalingFactors( ) {
        imageSize = scopeImage.frame.size
        
        // spans and scaling factors for various conversions
        let voltageSpan = vvRange.max - vvRange.min
        voltageScaleFactor = Voltage(imageSize.height)/voltageSpan
        let timeSpan = tvRange.oldest - tvRange.newest
        timeScaleFactor = imageSize.width / timeSpan
        yDiffToVoltageScaleFactor = voltageSpan / Voltage(imageSize.height)
        xDiffToTimeScaleFactor = timeSpan / Time(imageSize.width)
    }
    
    func recalculateGridPositions( ) {
        scopeImage.timeGridPositions = getTimeGridPositions()
        scopeImage.voltageGridPositions = getVoltageGridPositions()
        scopeImage.groundLineYCoord = translateVoltageToGraphicsY(0.0)
    }
    
    func getTimeGridPositions( ) -> [CGFloat] {
        let firstGridMultiplier = ceil(tvRange.newest / timeGridSpacing)
        var aGridTime = firstGridMultiplier * timeGridSpacing
        var gridCoords:[CGFloat] = []
        while ( aGridTime < tvRange.oldest ) {
            gridCoords.append(translateTimeToGraphicsX(aGridTime))
            aGridTime += timeGridSpacing
        }
        return gridCoords
    }
    
    func getVoltageGridPositions( ) -> [CGFloat] {
        var gridCoords:[CGFloat] = []
        var aGridVoltage = voltageGridSpacing
        while ( aGridVoltage < vvRange.max ) {
            if ( aGridVoltage > vvRange.min ) {
                gridCoords.append(translateVoltageToGraphicsY(aGridVoltage))
            }
            aGridVoltage += voltageGridSpacing
        }
        aGridVoltage = -voltageGridSpacing
        while ( aGridVoltage > vvRange.min ) {
            if ( aGridVoltage < vvRange.max ) {
                gridCoords.append(translateVoltageToGraphicsY(aGridVoltage))
            }
            aGridVoltage -= voltageGridSpacing
        }
        //print( "V spacing: \(voltageGridSpacing)\t\(gridCoords)")
        return gridCoords
    }
    
    func recalculateGridSpacing( ) {
        // store these so at the end we can tell if they're different, and update the labels
        let oldVSpacing = voltageGridSpacing
        // voltage first
        while ( true ) {
            // get a couple of coords at the current spacing.
            let highTest = translateVoltageToGraphicsY(voltageGridSpacing)
            let lowTest = translateVoltageToGraphicsY(0.0)
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
        if ( oldVSpacing != voltageGridSpacing ) {
            // update the label
            labelVoltageGrid.stringValue = getVoltageAsString(voltageGridSpacing) + " /"
        }
        
        // now time
        let oldTSpacing = timeGridSpacing
        while ( true ) {
            // get a couple of coords at the current spacing.
            let highTest = translateTimeToGraphicsX(0)
            let lowTest = translateTimeToGraphicsX(timeGridSpacing)
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
        if ( oldTSpacing != timeGridSpacing ) {
            // update the label
            labelTimeGrid.stringValue = getTimeAsString(timeGridSpacing) + " /"
        }
    }

    func clampVoltageDisplayRange( inout range:(min:Voltage, max:Voltage) ) {
        let originalSpan = range.max - range.min
        // if this span is too big to fit in the limits, just return the limits.
        if ( originalSpan > CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.max ) {
            range = CONFIG_DISPLAY_VOLTAGE_LIMITS
            return
        }
        // if this span is below the minimum span, get a center point and put the minimum span around that.
        if ( originalSpan < CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.min ) {
            let centerPoint = (range.max + range.min) / 2
            let limitRadius = CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS.min / 2
            range.min = centerPoint - limitRadius
            range.max = centerPoint + limitRadius
            return
        }
        // we know the span fits within the bounds, so only one end of the range can possibly be illegal at a time.
        if ( range.min < CONFIG_DISPLAY_VOLTAGE_LIMITS.min ) {
            range.min = CONFIG_DISPLAY_VOLTAGE_LIMITS.min
            range.max = range.min + originalSpan
            return
        }
        if ( range.max > CONFIG_DISPLAY_VOLTAGE_LIMITS.max ) {
            range.max = CONFIG_DISPLAY_VOLTAGE_LIMITS.max
            range.min = range.max - originalSpan
            return
        }
    }
    
    func clampTimeDisplayRange( inout range:(newest:Time, oldest:Time) ) {
        let originalSpan = range.oldest - range.newest
        // if this span is too big to fit in the limits, just return the limits.
        if ( originalSpan > CONFIG_DISPLAY_TIME_SPAN_LIMITS.max ) {
            range = CONFIG_DISPLAY_TIME_LIMITS
            return
        }
        // if this span is below the minimum span, get a center point and put the minimum span around that.
        if ( originalSpan < CONFIG_DISPLAY_TIME_SPAN_LIMITS.min ) {
            let centerPoint = (range.oldest + range.newest) / 2
            let limitRadius = CONFIG_DISPLAY_TIME_SPAN_LIMITS.min / 2
            range.newest = centerPoint - limitRadius
            range.oldest = centerPoint + limitRadius
            return
        }
        // we know the span fits within the bounds, so only one end of the range can possibly be illegal at a time.
        if ( range.newest < CONFIG_DISPLAY_TIME_LIMITS.newest ) {
            range.newest = CONFIG_DISPLAY_TIME_LIMITS.newest
            range.oldest = range.newest + originalSpan
            return
        }
        if ( range.oldest > CONFIG_DISPLAY_TIME_LIMITS.oldest ) {
            range.oldest = CONFIG_DISPLAY_TIME_LIMITS.oldest
            range.newest = range.oldest - originalSpan
            return
        }
    }
    
    //
    // TRANSLATORS
    //
    
    func translateVoltageToGraphicsY( voltage:Voltage ) -> CGFloat {
        var yVal = voltage - vvRange.min
        yVal *= voltageScaleFactor
        return CGFloat(yVal)
    }
    
    func translateGraphicsYToVoltage( yCoord:CGFloat ) -> Voltage {
        let inverseScaling = 1 / voltageScaleFactor
        return (Voltage(yCoord)*inverseScaling)+vvRange.min
    }
    
    func translateTimeToGraphicsX( time:Time ) -> CGFloat {
        var xVal = time - tvRange.newest
        xVal *= timeScaleFactor
        return CGFloat(imageSize.width - xVal);
    }
    
    func translateGraphicsXToTime( xCoord:CGFloat ) -> Time {
        let inverseScaling = 1 / timeScaleFactor
        return (Time(imageSize.width-xCoord)*inverseScaling)+tvRange.newest
    }
    
    func translateGraphicsDeltaToVoltage( yDiff:CGFloat ) -> Voltage {
        return yDiffToVoltageScaleFactor * Voltage(yDiff)
    }
    
    func translateGraphicsDeltaToTime( xDiff:CGFloat ) -> Time {
        return xDiffToTimeScaleFactor * Time(xDiff)
    }
    
    //
    // SETUP
    //
    
    var channels:[Channel] = []
    var scopeRefreshRate:NSTimeInterval = 1/CONFIG_DISPLAY_REFRESH_RATE
    var drawTimer:NSTimer? = nil
    
    func loadChannel( newChannel:Channel ) {
        // stop the drawing timer
        if ( drawTimer != nil ) {
            drawTimer!.invalidate()
            drawTimer = nil
        }
        
        // update the channels
        channels += [newChannel]
        scopeImage.channels = self.channels
        
        // restart the frame rate timer
        drawTimer = NSTimer.scheduledTimerWithTimeInterval(scopeRefreshRate, target: self, selector: #selector(drawTheNextFrame), userInfo: nil, repeats: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ScopeViewController.viewDidLoad")
        
        calculateGridArrays()
    
        // let us know when the window gets resized.
        NSNotificationCenter.defaultCenter().addObserverForName(NSViewFrameDidChangeNotification, object: nil, queue: nil, usingBlock: {n in
            self.viewFrameChanged(n)
        })
        
        recalculateEverything()
    }
    
    deinit {
        print( "----ScopeViewController.deinit" )
    }
}
