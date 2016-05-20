//
//  ChannelViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class ChannelViewController: NSViewController {

    //
    // HEADER SECTION
    //
    
    enum VoltmeterDisplayState {
        case Disabled
        case Instantaneous
        case PeakToPeak
    }
    var voltmeterDisplayState:VoltmeterDisplayState = .Disabled
    
    @IBOutlet weak var labelDeviceName: NSTextField!
    @IBOutlet weak var labelVoltmeter: NSTextField!
    @IBOutlet weak var labelReadingType: NSTextField!
    @IBOutlet weak var colorWell: NSColorWell!

    @IBAction func colorWellAction(sender: NSColorWell) {
        if let ch = channel {
            ch.traceColor = sender.color
        }
    }
    
    //
    // NEW CONTROLS
    //
    
    @IBOutlet weak var checkboxVisible: NSButton!
    
    @IBAction func checkboxVisibleClicked(sender: NSButton) {
    }
    
    @IBOutlet weak var textfieldOffset: NSTextField!
    @IBOutlet weak var textfieldScaling: NSTextField!
    @IBOutlet weak var stepperOffset: NSStepper!
    @IBOutlet weak var stepperScaling: NSStepper!
    
    
    @IBOutlet weak var radioNoTrigger: NSButton!
    @IBOutlet weak var radioRisingEdge: NSButton!
    
    @IBAction func radioTriggerSelected(sender: NSButton) {
    }
    
    
    @IBOutlet weak var textfieldRisingEdgeLevel: NSTextField!
    @IBOutlet weak var stepperRisingEdgeLevel: NSStepper!
    @IBOutlet weak var checkboxRisingEdgeLevelAuto: NSButton!
    @IBOutlet weak var sliderRisingEdgeFilter: NSSlider!
    
    @IBAction func checkboxRisingEdgeLevelAutoClicked(sender: NSButton) {
    }
    
    
    
    
    //
    // UPDATE CONTROLS STATE
    //
    
    func updateControlState() {
        print("---updateControlState")
    }
    
    //
    // UPDATE READINGS
    //

    func updateReadings( ) {
        switch (voltmeterDisplayState) {
        case .Instantaneous:
            labelVoltmeter.stringValue = channel!.sampleBuffer.getNewestSample().asVoltage().asString()
            break
        case .PeakToPeak:
            labelVoltmeter.stringValue = "fixme."
            break
        default:
            break
        }
    }

    // The timer for that ...
    var updateReadingsTimer:NSTimer = NSTimer()

    func startUpdateReadingsTimer( ) {
        // 10 FPS for now.
        updateReadingsTimer = NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(updateReadings), userInfo: nil, repeats: true)
        updateReadingsTimer.tolerance = 0.08
    }
    
    func stopUpdateReadingsTimer( ) {
        updateReadingsTimer.invalidate()
    }
    
    //
    // CHANNEL SETUP
    //
    
    var channel:Channel? = nil
    
    func loadChannel( newChannel:Channel ) throws {
        // if there's already a channel on this view, get rid of it
        if ( channel != nil ) {
            try unloadCurrentChannel()
        }
        
        // load in the new one ...
        channel = newChannel
        
        // update channel name.
        labelDeviceName.stringValue = channel!.name
        
        // switch it on!
        try channel!.channelOn()
        
        // start the UI
        enableUI()
    }
    
    func unloadCurrentChannel( ) throws {
        if ( channel == nil ) {
            // actually we don't have to do anything, there's no channel loaded
            return
        }
        
        disableUI()
        
        // if the channel is on, stop it first.
        if ( channel!.isChannelOn == true ) {
            try channel!.channelOff()
        }
        
        channel = nil
    }
    
    // these are master start/stop for the entire UI.  Everything more granular than that is in updateControls or updateReadings.
    
    func enableUI( ) {

        // HEADER SECTION

        colorWell.enabled = true
        if let ch = channel {
            colorWell.color = ch.traceColor
        }
        voltmeterDisplayState = .Instantaneous
        labelReadingType.stringValue = "(Instant)"
        
        // done. start the timer.
        startUpdateReadingsTimer()
    }
    
    func disableUI( ) {
        stopUpdateReadingsTimer()
        
        // HEADER SECTION - voltmeter, frequency meter, color picker, that stuff
        
        voltmeterDisplayState = .Disabled
        labelVoltmeter.stringValue = "-----"
        colorWell.enabled = false
        labelReadingType.stringValue = "-----"
    }
    
    //
    // MASTER - stuff that applies to the entire view
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ChannelViewController.channelDidLoad")
        // Do view setup here.
        
        // we've loaded, but there's no channel attached yet, so disable controls
        disableUI()
    }
    
}
