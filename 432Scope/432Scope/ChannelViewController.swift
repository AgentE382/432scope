//
//  ChannelViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class ChannelViewController: NSViewController {

    // header: channel name, big readout, color picker
    @IBOutlet weak var nstfChannelName: NSTextField!
    @IBOutlet weak var nstfVolts: NSTextField!
    @IBOutlet weak var colorWell: NSColorWell!

    func updateVoltmeter( ) {
        nstfVolts.stringValue = getVoltageAsString(channel!.getInstantaneousVoltage())
    }
    
    @IBAction func colorWellAction(sender: NSColorWell) {
        if ( channel == nil ) {
            return
        }
        channel!.displayColor = sender.color
    }
    
    // trigger controls
    @IBOutlet weak var radioTriggerNone: NSButton!
    @IBOutlet weak var radioTriggerRising: NSButton!
    @IBOutlet weak var editableTriggerLevel: NSTextField!
    
    @IBAction func radioButtonActivated(sender: NSButton) {
        if ( sender == radioTriggerNone ) {
            print("setting trigger nil")
            editableTriggerLevel.enabled = false
            channel!.setTrigger(nil)
        }
        if ( sender == radioTriggerRising) {
            print("setting rising edge trigger 0V")
            //editableTriggerLevel.enabled = true
            channel!.setTrigger(0.0)
        }
    }
    
    @IBAction func levelFieldActivated(sender: NSTextField) {
        print("levelFieldActivated")
        let number = sender.objectValue as! Double
        print("\(number)")
    }
    
    
    
    
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

        // color well
        colorWell.enabled = true
        colorWell.color = channel!.displayColor
        
        // start UI timer!
        uiTimer = NSTimer.scheduledTimerWithTimeInterval(5/CONFIG_DISPLAY_REFRESH_RATE, target: self, selector: #selector(updateVoltmeter), userInfo: nil, repeats: true)
        uiTimer!.tolerance = 0.005
        print( "ChannelViewController loaded \(channel!.getName())." )
        
        // switch it on!
        do { try channel!.channelOn() }
        catch { print("Channel loaded but wouldn't switch on.") }
        
        // enable the radio buttons
        radioTriggerNone.enabled = true
        radioTriggerRising.enabled = true
        radioTriggerNone.state = NSOnState
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
        colorWell.enabled = false
        radioTriggerNone.enabled = false
        radioTriggerRising.enabled = false
        editableTriggerLevel.enabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ChannelViewController.channelDidLoad")
        // Do view setup here.
        
        // we've loaded, but there's no channel attached yet, so disable controls
        disableControls()
        
        editableTriggerLevel.objectValue = Double(0.0)
    }
    
}
