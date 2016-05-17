//
//  ScopeViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

enum DrawingModeState {
    case Raw
    case Triggered
}

class ScopeViewController: NSViewController, ChannelNotifications, ScopeImageViewNotifications {
    
    
    //
    // ZOOM BUTTONS
    //
    
    @IBOutlet weak var nsbZoomOutX: NSButton!
    @IBOutlet weak var nsbZoomInX: NSButton!
    @IBOutlet weak var nsbZoomOutY: NSButton!
    @IBOutlet weak var nsbZoomInY: NSButton!

    @IBAction func buttonZoomOutX(sender: AnyObject) {
        let newTVRange = zoomX(ScopeViewMath.tvRange, magnification: 1.2)
        ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
    }
    
    @IBAction func buttonZoomInX(sender: AnyObject) {
        let newTVRange = zoomX(ScopeViewMath.tvRange, magnification: 1/1.2)
        ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
    }
    
    @IBAction func buttonZoomOutY(sender: AnyObject) {
        let newVVRange = zoomY(ScopeViewMath.vvRange, magnification: 1.2)
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: nil)
    }
    
    @IBAction func buttonZoomInY(sender: AnyObject) {
        let newVVRange = zoomY(ScopeViewMath.vvRange, magnification: 1/1.2)
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: nil)
    }

    //
    // PAN / ZOOM with mouse and multitouch
    //
    
    // PINCH-TO-ZOOM
    override func magnifyWithEvent(event: NSEvent) {
        let magnification = 1.0-event.magnification
        let newTVRange = zoomX(ScopeViewMath.tvRange, magnification: magnification)
        let newVVRange = zoomY(ScopeViewMath.vvRange, magnification: Voltage(magnification))
        ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
    }
    
    // MOUSE WHEEL: view pan. Cmd+mousewheel zooms.
    override func scrollWheel(event:NSEvent) {
        let dX = event.scrollingDeltaX
        let dY = event.scrollingDeltaY
        let modifierFlags = event.modifierFlags
        if (modifierFlags.contains( .CommandKeyMask )) {
            // we are zooming
            let xMagnifier = (dX / 100) + 1.0
            let yMagnifier = (dY / 100) + 1.0
            let newTVRange = zoomX(ScopeViewMath.tvRange, magnification: Time(xMagnifier))
            let newVVRange = zoomY(ScopeViewMath.vvRange, magnification: Voltage(yMagnifier))
            ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
        } else {
            // we are panning
            let dVoltage = dY.asVoltageDiff() // Translate.graphicsDeltaToVoltage(dY)
            let newVVRange = VoltageRange(min: ScopeViewMath.vvRange.min + dVoltage,
                                          max: ScopeViewMath.vvRange.max + dVoltage)
            let dTime = dX.asTimeDiff() // Translate.graphicsDeltaToTime(dX)
            let newTVRange = TimeRange(newest: ScopeViewMath.tvRange.newest + dTime,
                                       oldest: ScopeViewMath.tvRange.oldest + dTime)
            // just a pan so only a few updates are needed
            ScopeViewMath.update(nil, vvRange: newVVRange, tvRange: newTVRange)
        }
    }
    
    //
    // MOUSE DRAG EVENTS: not sure what to do with these yet.
    //
    
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
    // ZOOM CALCULATORS
    //
    
    func zoomX(rangeToZoom:TimeRange, magnification:Time) -> TimeRange {
        let center = rangeToZoom.center
        let span = rangeToZoom.span * magnification
        return TimeRange(center: center, span: span)
    }
    
    func zoomY(rangeToZoom:VoltageRange, magnification:Voltage) -> VoltageRange {
        let center = rangeToZoom.center
        let span = rangeToZoom.span * magnification
        return VoltageRange(center: center, span: span)
    }

    //
    // CHANNEL SETUP
    //
    
    var channels:[Channel] = []
    
    func loadChannel( newChannel:Channel ) {
        // update the channels
        newChannel.notifications = self
        channels += [newChannel]
        scopeImage.channels = self.channels
    }
    
    // this is the notification from channel that it has completed a new packet.
    func channelHasNewData() {
        // look through all the channels, and if they're all drawable, trigger a frame
        for ch in channels {
            if (!ch.isDrawable) {
                return
            }
        }
        // we got here, so everything's drawable. draw, then reset.
        drawFrame()
        for ch in channels {
            ch.isDrawable = false
        }
    }
    
    //
    // DRAWING / ScopeImageViewNotifications
    //
    
    func drawingWillBegin() {
        // freeze the channels, recalc view math if necessary depending on state
        for ch in channels {
            ch.sampleBuffer.suspendWrites()
        }
    }
    
    func drawFrame( ) {
        scopeImage.needsDisplay = true
    }
    
    func drawingHasFinished() {
        // unfreeze the channels
        for ch in channels {
            ch.sampleBuffer.resumeWrites()
        }
    }
    
    //
    // INIT, BASICS
    //
    
    @IBOutlet weak var scopeImage: ScopeImageView!
    
    // this is the callback for window resize notifications.
    func viewFrameChanged(notification:NSNotification) {
        ScopeViewMath.update(scopeImage.frame.size, vvRange: nil, tvRange: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ScopeViewController.viewDidLoad")
    
        // subscribe to window resize notifications
        NSNotificationCenter.defaultCenter().addObserverForName(NSViewFrameDidChangeNotification, object: nil, queue: nil, usingBlock: {n in
            self.viewFrameChanged(n)
        })
        
        // scope view math stuff
        ScopeViewMath.initializeViewMath()
        ScopeViewMath.update(scopeImage.frame.size, vvRange: nil, tvRange: nil)
        
        // subscribe to the ScopeImageViewNotifications ...
        scopeImage!.notifications = self
    }
    
    deinit {
        print( "----ScopeViewController.deinit" )
    }
}
