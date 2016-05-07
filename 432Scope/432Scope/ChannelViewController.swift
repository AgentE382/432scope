//
//  ChannelViewController.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

class ChannelViewController: NSViewController {

    // UI Outlets
    @IBOutlet weak var nstfChannelName: NSTextField!
    @IBOutlet weak var nstfVolts: NSTextField!
    @IBOutlet weak var checkboxEnabled: NSButton!
    @IBOutlet weak var colorWell: NSColorWell!

    
    var uiTimer:NSTimer? = nil
    
    var channel:Channel? = nil
    
    func updateVoltmeter( ) {
        nstfVolts.stringValue = getVoltageAsString(channel!.getInstantaneousVoltage())
    }
    
    @IBAction func colorWellAction(sender: NSColorWell) {
        if ( channel == nil ) {
            return
        }
        channel!.displayColor = sender.color
    }
    
    @IBAction func enablePressed(sender: AnyObject) {
        do {
            if ( checkboxEnabled.state == NSOnState ) {
                try channel!.channelOn( )
            } else {
                try channel!.channelOff( )
            }
        } catch {
            print( "Something went wrong." )
        }
    }
    
    func loadChannel( newChannel:Channel ) {
        // if there's already a channel on this view, get rid of it
        if ( channel != nil ) {
            unloadCurrentChannel()
        }
        // load in the new one ...
        channel = newChannel
        
        // update channel name.
        nstfChannelName.stringValue = channel!.getName()
        
        // update the enable checkbox
        checkboxEnabled.enabled = true
        if ( channel!.isChannelOn == true ) {
            checkboxEnabled.state = NSOnState
        } else {
            checkboxEnabled.state = NSOffState
        }
        
        // color well
        colorWell.enabled = true
        colorWell.color = channel!.displayColor
        
        // start UI timer!
        uiTimer = NSTimer.scheduledTimerWithTimeInterval(4/CONFIG_DISPLAY_REFRESH_RATE, target: self, selector: #selector(updateVoltmeter), userInfo: nil, repeats: true)
        uiTimer!.tolerance = 0.005
        print( "ChannelViewController loaded \(channel!.getName())." )
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
        checkboxEnabled.enabled = false
        colorWell.enabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("----ChannelViewController.channelDidLoad")
        // Do view setup here.
        
        // we've loaded, but there's no channel attached yet, so disable controls
        disableControls()
    }
    
}
