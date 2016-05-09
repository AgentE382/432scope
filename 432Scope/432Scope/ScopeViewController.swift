//
//  ScopeViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class ScopeViewController: NSViewController {
    
    //
    // INTERFACE CONNECTIONS
    //
    
    @IBOutlet weak var scopeImage: ScopeImageView!
    @IBOutlet weak var nsbZoomOutX: NSButton!
    @IBOutlet weak var nsbZoomInX: NSButton!
    @IBOutlet weak var nsbZoomOutY: NSButton!
    @IBOutlet weak var nsbZoomInY: NSButton!

    @IBAction func buttonZoomOutX(sender: AnyObject) {
        let newTVRange = zoomX( Time(CONFIG_DISPLAY_MAGNFICATION_FACTOR) )
        ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
    }
    
    @IBAction func buttonZoomInX(sender: AnyObject) {
        let newTVRange = zoomX( Time(1/CONFIG_DISPLAY_MAGNFICATION_FACTOR) )
        ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
    }
    
    @IBAction func buttonZoomOutY(sender: AnyObject) {
        let newVVRange = zoomY( Voltage(CONFIG_DISPLAY_MAGNFICATION_FACTOR))
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: nil)
    }
    
    @IBAction func buttonZoomInY(sender: AnyObject) {
        let newVVRange = zoomY( Voltage(1/CONFIG_DISPLAY_MAGNFICATION_FACTOR))
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: nil)
    }
    
    //
    // NSRESPONDER / EVENT HANDLING OVERRIDES
    //
    
    // PINCH-TO-ZOOM
    override func magnifyWithEvent(event: NSEvent) {
        // the cocoa event handling guide suggests adding this to 1.0 to create a mag factor, looks pretty good.
        let magnification = 1.0-event.magnification
        let newTVRange = zoomX(Time(magnification))
        let newVVRange = zoomY(Voltage(magnification))
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
    }
    
    // MOUSE WHEEL: view pan. Cmd+mousewheel zooms.
    override func scrollWheel(event:NSEvent) {
        let dX = event.scrollingDeltaX
        let dY = event.scrollingDeltaY
        let modifierFlags = event.modifierFlags
        if (modifierFlags.contains( .CommandKeyMask )) {
            // we are zooming zoom
            let xMagnifier = (dX / 100) + 1.0
            let yMagnifier = (dY / 100) + 1.0
            let newTVRange = zoomX(Time(xMagnifier))
            let newVVRange = zoomY(Voltage(yMagnifier))
            ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
        } else {
            // we are panning pan
            let dVoltage = Translate.graphicsDeltaToVoltage(dY)
            let newVVRange = VoltageRange(min: ScopeViewMath.vvRange.min + dVoltage,
                                          max: ScopeViewMath.vvRange.max + dVoltage)
            let dTime = Translate.graphicsDeltaToTime(dX)
            let newTVRange = TimeRange(newest: ScopeViewMath.tvRange.newest + dTime,
                                       oldest: ScopeViewMath.tvRange.oldest + dTime)
            // just a pan so only a few updates are needed
            ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
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
    
    func zoomX( magnification:Time ) -> TimeRange {
        // get the center point and *new* half-span
        let halfSpan = ((ScopeViewMath.tvRange.oldest - ScopeViewMath.tvRange.newest) / 2) * magnification
        let center = (ScopeViewMath.tvRange.oldest + ScopeViewMath.tvRange.newest) / 2
        
        // compute a new range
        return TimeRange(newest: center-halfSpan, oldest: center+halfSpan)

    }
    
    func zoomY( magnification:Voltage ) -> VoltageRange {
        // get center point, new half-span
        let halfSpan = ( (ScopeViewMath.vvRange.max - ScopeViewMath.vvRange.min) / 2) * magnification
        let center = ( ScopeViewMath.vvRange.max + ScopeViewMath.vvRange.min ) / 2
        
        // update voltageVisibleRange
        return VoltageRange(min: center - halfSpan, max: center + halfSpan )
    }

    //
    // TIMER / NOTIFICATION HANDLERS
    //
    
    func frameRateTick( ) {
        scopeImage.setNeedsDisplay()
    }
    
    func viewFrameChanged(notification:NSNotification) {
        // window resized, so the image size has changed.
        ScopeViewMath.update(scopeImage.frame.size, vvRange: nil, tvRange: nil)
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
        drawTimer = NSTimer.scheduledTimerWithTimeInterval(scopeRefreshRate, target: self, selector: #selector(frameRateTick), userInfo: nil, repeats: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ScopeViewController.viewDidLoad")
        
        // WHAT HAPPENS HERE:
        // initialize ScopeViewMath stuff
        // register to receive window resize notification
        // send an initial image size to the view math system
        
        ScopeViewMath.initializeViewMath()
    
        // let us know when the window gets resized.
        NSNotificationCenter.defaultCenter().addObserverForName(NSViewFrameDidChangeNotification, object: nil, queue: nil, usingBlock: {n in
            self.viewFrameChanged(n)
        })
        
        ScopeViewMath.update(scopeImage.frame.size, vvRange: nil, tvRange: nil)
    }
    
    deinit {
        print( "----ScopeViewController.deinit" )
    }
}
