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
    
    func disableHeaderSection( ) {
        voltmeterDisplayState = .Disabled
        labelVoltmeter.stringValue = "-----"
        colorWell.enabled = false
        labelReadingType.stringValue = "-----"
    }
    
    func enableHeaderSection( ) {
        colorWell.enabled = true
        if let ch = channel {
            colorWell.color = ch.traceColor
        }
        voltmeterDisplayState = .Instantaneous
        labelReadingType.stringValue = "(Instant)"
    }
    
    func updateHeaderSection( ) {
        switch (voltmeterDisplayState) {
        case .Instantaneous:
            labelVoltmeter.stringValue = channel!.sampleBuffer.getNewestSample().asVoltage().asString()
            break
        case .PeakToPeak:
            let ptp = channel!.triggerPeriodVoltageRange.span
            labelVoltmeter.stringValue = ptp.asString()
            break
        default:
            break
        }
    }
    
    //
    // TRIGGER SECTION
    //
    
    enum FrequencyDisplayState {
        case Disabled
        case Enabled
    }
    var frequencyDisplayState:FrequencyDisplayState = .Disabled
    
    @IBOutlet weak var popupTriggerType: NSPopUpButton!
    @IBOutlet weak var textLevelEntryBox: NSTextField!
    @IBOutlet weak var labelFrequencyDisplay: NSTextField!
    
    @IBAction func triggerTypeSelected(sender: NSPopUpButton) {
        if let selection = sender.titleOfSelectedItem {
            switch ( selection ) {
                
                case "None":
                    channel!.installNoTrigger()
                    textLevelEntryBox.enabled = false
                    frequencyDisplayState = .Disabled
                    voltmeterDisplayState = .Instantaneous
                    labelFrequencyDisplay.stringValue = "-----"
                    labelReadingType.stringValue = "(Instant)"
                    break;
                
                case "Rising Edge":
                    textLevelEntryBox.enabled = true
                    let level = (textLevelEntryBox.objectValue as! Double)
                    channel!.installRisingEdgeTrigger(Voltage(level))
                    frequencyDisplayState = .Enabled
                    voltmeterDisplayState = .PeakToPeak
                    labelReadingType.stringValue = "(Peak-to-Peak)"
                    break;
                
            default:
                break;
            }
        }
    }
    
    @IBAction func triggerLevelChanged(sender: NSTextField) {
        if let ch = channel {
            if let level = (textLevelEntryBox.objectValue as? Double) {
                // we successfully got a Double out of the text box.
                ch.installRisingEdgeTrigger(Voltage(level))
            }
        }
    }
    
    func enableTriggerSection( ) {
        popupTriggerType.enabled = true
    }
    
    func disableTriggerSection( ) {
        popupTriggerType.enabled = false
        popupTriggerType.selectItemWithTitle("None")
        textLevelEntryBox.objectValue = Double(0.0)
        textLevelEntryBox.enabled = false
        labelFrequencyDisplay.stringValue = "-----"
        frequencyDisplayState = .Disabled
    }

    func updateTriggerSection( ) {
        switch (frequencyDisplayState) {
        case .Enabled:
            labelFrequencyDisplay.stringValue = channel!.triggerFrequency.asString()
            break
        default:
            break
        }
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

    }
    
    //
    // MASTER - stuff that applies to the entire view
    //
    
    var uiTimer:NSTimer = NSTimer()
    
    func updateDisplay( ) {
        updateHeaderSection()
        updateTriggerSection()
    }

    func startFrameTimer( ) {
        // 5 FPS for now
        uiTimer = NSTimer.scheduledTimerWithTimeInterval(0.2, target: self, selector: #selector(updateDisplay), userInfo: nil, repeats: true)
        uiTimer.tolerance = 0.08
    }
    
    func stopFrameTimer( ) {
        uiTimer.invalidate()
    }
    
    func enableUI( ) {
        enableHeaderSection()
        enableTriggerSection()
        startFrameTimer()
    }
    
    func disableUI( ) {
        stopFrameTimer()
        disableHeaderSection()
        disableTriggerSection()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ChannelViewController.channelDidLoad")
        // Do view setup here.
        
        // we've loaded, but there's no channel attached yet, so disable controls
        disableUI()
    }
    
}
