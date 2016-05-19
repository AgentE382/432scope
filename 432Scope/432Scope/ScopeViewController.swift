//
//  ScopeViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class ScopeViewController: NSViewController, ChannelNotifications, ScopeImageViewNotifications {
    
    //
    // VIEW MODE CONTROLS - the actual state enum is in ScopeViewMath.
    //

    @IBOutlet weak var radioViewModeTrigger: NSButton!
    @IBOutlet weak var radioViewModeTimeline: NSButton!
    @IBOutlet weak var radioViewModeStop: NSButton!
    @IBOutlet weak var popupTriggerSelector: NSPopUpButton!
    
    @IBAction func viewModeSelected(sender: NSButton) {
        switch (sender) {
        case radioViewModeTrigger:
            enterTriggerMode()
            break
        case radioViewModeTimeline:
            enterTimelineMode()
            break
        case radioViewModeStop:
            enterStopMode()
            break
        default:
            print("viewModeSelected: who said that?!?")
            break
        }
        updateViewModeControls()
    }
    
    @IBAction func triggerSelected(sender: NSPopUpButton) {
        let chName = popupTriggerSelector.titleOfSelectedItem!
        var newChan:Channel? = nil
        for ch in channels {
            if chName == ch.name {
                newChan = ch
                break
            }
        }
        guard newChan != nil else {
            print("somehow you selected a trigger on a channel that doesn't exist.")
            return
        }
//        print("scope view mode set to Trigger(\(newChan!.name)")
        ScopeViewMath.scopeImageViewDisplayState = .Trigger(newChan!)
    }
    
    func updateViewModeControls() {
        print("----updateViewModeControls()")
        
        // enumerate possible triggers
        var selectableTriggers:[String] = []
        for ch in channels {
            if ( ch.hasTrigger ) {
                selectableTriggers.append(ch.name)
            }
        }
 //       print("there are \(selectableTriggers.count) selectable triggers.")
        
        // populate the trigger menu, preserving selection if possible
        let previousSelection = popupTriggerSelector.titleOfSelectedItem
        popupTriggerSelector.removeAllItems()
        popupTriggerSelector.addItemsWithTitles(selectableTriggers)
        
        if ( selectableTriggers.count > 0 ) {
            // there are selectable triggers
            if previousSelection != nil {
                // try to restore the previous selection
                let prevSelIndex = popupTriggerSelector.indexOfItemWithTitle(previousSelection!)
                if ( prevSelIndex != -1 ) {
                    // it exists. restore it.
                    popupTriggerSelector.selectItemAtIndex(prevSelIndex)
                } else {
                    // it doesn't exist. our selection was pulled out from under us. go to timeline mode.
                    enterTimelineMode()
                    updateViewModeControls()
                    return
                }
            }
            radioViewModeTrigger.enabled = true
        } else {
            // there are no selectable triggers, so disable trigger mode.
            radioViewModeTrigger.enabled = false
        }
        
        switch (ScopeViewMath.scopeImageViewDisplayState) {
        case .Stop:
            radioViewModeStop.state = NSOnState
            popupTriggerSelector.enabled = false
            break
        case .Timeline:
            radioViewModeTimeline.state = NSOnState
            popupTriggerSelector.enabled = false
            break
        case .Trigger(let ch):
            if (selectableTriggers.count == 0) {
                // we were in trigger mode but now the valid triggers seem to have disappeared. get out.
                enterTimelineMode()
                updateViewModeControls()
                return
            }
            radioViewModeTrigger.state = NSOnState
            popupTriggerSelector.enabled = true
            popupTriggerSelector.selectItemWithTitle(ch.name)
            break
        }
    }
    
    func enterStopMode() {
        // save current state?
        
        // turn off the channels
        for ch in channels {
            if ( ch.isChannelOn == false ) {
                continue
            }
            do { try ch.channelOff() }
            catch { print("ERROR: couldn't switch off \(ch.name)") }
        }
        
        // start the drawing timer
        startDrawingTimer()
        
        ScopeViewMath.scopeImageViewDisplayState = .Stop
    }
    
    func enterTimelineMode() {
        // make sure drawing timer is off
        stopDrawingTimer()
        
        // make sure channels are on
        for ch in channels {
            if ( ch.isChannelOn == true ) {
                continue
            }
            do { try ch.channelOn() }
            catch { print("ERROR: couldn't switch on \(ch.name)") }
        }
        
        ScopeViewMath.scopeImageViewDisplayState = .Timeline
    }
    
    func enterTriggerMode() {
        // make sure channels are on
        for ch in channels {
            if ( ch.isChannelOn == true ) {
                continue
            }
            do { try ch.channelOn() }
            catch { print("ERROR: couldn't switch on \(ch.name)" ) }
        }
        
        // make sure drawing timer is off
        stopDrawingTimer()
        
        // get the channel we're gonna trigger on
        popupTriggerSelector.enabled = true
        let selectedName = popupTriggerSelector.titleOfSelectedItem!
        var selectedChannel:Channel? = nil
        for ch in channels {
            if ch.name == selectedName {
                selectedChannel = ch
                break
            }
        }
        guard selectedChannel != nil else {
            print("enterTriggerMode: SUPER ULTRA WTF")
            enterStopMode()
            return
        }
        
//        print("entering trigger mode on \(selectedChannel!.name)")
        ScopeViewMath.scopeImageViewDisplayState = .Trigger(selectedChannel!)
    }
    
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
            let dVoltage = dY.asVoltageDiff()
            let newVVRange = VoltageRange(min: ScopeViewMath.vvRange.min + dVoltage,
                                          max: ScopeViewMath.vvRange.max + dVoltage)
            let dTime = dX.asTimeDiff()
            let newTVRange = TimeRange(newest: ScopeViewMath.tvRange.newest + dTime,
                                       oldest: ScopeViewMath.tvRange.oldest + dTime)
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
    func channelHasNewData(sender:Channel) {
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
    
    func channelTriggerChanged(sender: Channel) {
        updateViewModeControls()
    }
    
    //
    // DRAWING / ScopeImageViewNotifications
    //
    
    func drawingWillBegin() {
        // freeze the channels
        for ch in channels {
            ch.sampleBuffer.suspendWrites()
        }
        
        switch (ScopeViewMath.scopeImageViewDisplayState) {
        case .Stop:
            break
        case .Timeline:
            // glue the time viewable range to the newest.
            if ( ScopeViewMath.tvRange.newest != 0 ) {
                let viewWidth = ScopeViewMath.tvRange.span
                let newTVRange = TimeRange(newest: 0, span: viewWidth)
                ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
            }
            break
        case .Trigger(let ch):
            // we need to adjust the view around the trigger on ch.
            if let newCenter = ch.getTriggeredCenterTime(ScopeViewMath.tvRange.halfSpan) {
                var newTVRange = ScopeViewMath.tvRange
                newTVRange.center = newCenter
                ScopeViewMath.update(nil, vvRange: nil, tvRange: newTVRange)
            }
            break
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
    // A FRAME RATE GENERATOR for when the data stream is stopped
    //
    
    private var drawingTimer = NSTimer()
    
    func startDrawingTimer( ) {
        drawingTimer.invalidate()
        drawingTimer = NSTimer.scheduledTimerWithTimeInterval((1/CONFIG_DISPLAY_REFRESH_RATE), target: self, selector: #selector(drawFrame), userInfo: nil, repeats: true)
    }
    
    func stopDrawingTimer( ) {
        drawingTimer.invalidate()
    }
    
    //
    // INIT and BASICS
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
        ScopeViewMath.update(scopeImage.frame.size, vvRange: VoltageRange(min:-5, max:5), tvRange: TimeRange(newest:0.0, oldest:0.05))
        
        // subscribe to the ScopeImageViewNotifications ...
        scopeImage!.notifications = self
        
        // initial view mode control states
        radioViewModeTimeline.state = NSOnState
        radioViewModeTrigger.enabled = false
        popupTriggerSelector.enabled = false
    }
    
    deinit {
        print( "----ScopeViewController.deinit" )
    }
}
