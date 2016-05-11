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
    
    @IBOutlet weak var nstfChannelName: NSTextField!
    @IBOutlet weak var nstfVolts: NSTextField!
    @IBOutlet weak var colorWell: NSColorWell!
    @IBOutlet weak var nstfReadingType: NSTextField!
    var voltmeterDisplayState:VoltmeterDisplayState = .Disabled
    
    @IBAction func colorWellAction(sender: NSColorWell) {
        if let ch = channel {
            ch.displayColor = sender.color
        }
    }
    
    func disableHeaderSection( ) {
        nstfVolts.stringValue = "-----"
        colorWell.enabled = false
        nstfReadingType.stringValue = "-----"
        voltmeterDisplayState = .Disabled
    }
    
    func enableHeaderSection( ) {
        colorWell.enabled = true
        if let ch = channel {
            colorWell.color = ch.displayColor
        }
        voltmeterDisplayState = .Instantaneous
        nstfReadingType.stringValue = "(Instant)"
    }
    
    //
    // TRIGGER SECTION
    //
    
    @IBOutlet weak var popupTriggerType: NSPopUpButton!
    @IBOutlet weak var textLevelEntryBox: NSTextField!
    @IBOutlet weak var labelFrequencyDisplay: NSTextField!
    
    enum FrequencyDisplayState {
        case Disabled
        case Enabled
    }
    
    var frequencyDisplayState:FrequencyDisplayState = .Disabled

    @IBAction func triggerTypeSelected(sender: NSPopUpButton) {
        print("triggerTypeSelected")
        if let selection = sender.titleOfSelectedItem {
            switch ( selection ) {
                case "None":
                    channel!.setTrigger( nil )
                    textLevelEntryBox.enabled = false
                    frequencyDisplayState = .Disabled
                    voltmeterDisplayState = .Instantaneous
                    nstfReadingType.stringValue = "(Instant)"
                    break;
                case "Rising Edge":
                    textLevelEntryBox.enabled = true
                    let level = (textLevelEntryBox.objectValue as! Double)
                    channel!.setTrigger(Voltage(level))
                    frequencyDisplayState = .Enabled
                    voltmeterDisplayState = .PeakToPeak
                    nstfReadingType.stringValue = "(Peak-to-Peak)"
                    break;
            default:
                break;

            }
        }
    }
    
    @IBAction func triggerLevelChanged(sender: NSTextField) {
        if let ch = channel {
            let level = textLevelEntryBox.objectValue as! Double
            ch.setTrigger(Voltage(level))
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
        labelFrequencyDisplay.stringValue = "(Instant)"
        frequencyDisplayState = .Disabled
    }
    
    //
    // DISPLAY FUNCTION
    //
    
    func updateDisplay( ) {
        switch (voltmeterDisplayState) {
        case .Disabled:
            nstfVolts.stringValue = "(-----)"
            break;
        case .Instantaneous:
            nstfVolts.stringValue = channel!.getInstantaneousVoltage().asString() ///getVoltageAsString(channel!.getInstantaneousVoltage())
            break;
        case .PeakToPeak:
            let ptp = channel!.periodMax - channel!.periodMin
            nstfVolts.stringValue = ptp.asString() //getVoltageAsString(ptp)
            break;
        }
        
        switch (frequencyDisplayState) {
        case .Disabled:
            labelFrequencyDisplay.stringValue = "(-----)"
            break
        case .Enabled:
            labelFrequencyDisplay.stringValue = channel!.triggerFrequency.asString() //getFrequencyAsString(channel!.triggerFrequency)
            break
        }
    }
    
    //
    // CHANNEL SETUP AND CONTROLLER INIT
    //
    
    var uiTimer:NSTimer? = nil
    var channel:Channel? = nil
    
    func loadChannel( newChannel:Channel ) {
        // if there's already a channel on this view, get rid of it
        if ( channel != nil ) {
            unloadCurrentChannel()
        }
        // load in the new one ...
        channel = newChannel
        
        // update channel name.
        nstfChannelName.stringValue = channel!.getName()
        
        // start UI timer!
        uiTimer = NSTimer.scheduledTimerWithTimeInterval(12/CONFIG_DISPLAY_REFRESH_RATE, target: self, selector: #selector(updateDisplay), userInfo: nil, repeats: true)
        uiTimer!.tolerance = 0.005
        print( "ChannelViewController loaded \(channel!.getName())." )
        
        // switch it on!
        do { try channel!.channelOn() }
        catch { print("Channel loaded but wouldn't switch on.") }
        
        enableHeaderSection()
        enableTriggerSection()

    }
    
    func unloadCurrentChannel( ) {
        print( "----ChannelViewController.unloadCurrentChannel" )
        if ( channel == nil ) {
            // actually we don't have to do anything, there's no channel loaded
            return
        }
        // if the channel is on, stop it first.
        if ( channel!.isChannelOn == true ) {
            do { try channel!.channelOff() }
            catch { print( "Unloading the previous channel failed.  Great." ) }
        }
        // stop the UI timer
        uiTimer!.invalidate()
        uiTimer = nil
        
        disableControls()
    }
    
    func disableControls( ) {
        disableHeaderSection()
        disableTriggerSection()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ChannelViewController.channelDidLoad")
        // Do view setup here.
        
        // we've loaded, but there's no channel attached yet, so disable controls
        disableControls()
    }
    
}
