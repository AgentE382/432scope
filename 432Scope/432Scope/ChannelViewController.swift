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
    @IBOutlet weak var labelFrequencyMeter: NSTextField!
    @IBOutlet weak var colorWell: NSColorWell!

    @IBAction func colorWellAction(sender: NSColorWell) {
        if let ch = channel {
            ch.displayProperties.traceColor = sender.color
        }
    }
    
    //
    // DISPLAY CONTROLS
    //
    
    // visibility
    @IBOutlet weak var checkboxVisible: NSButton!
    
    @IBAction func checkboxVisibleClicked(sender: NSButton) {
        if sender.state == NSOnState {
            channel!.displayProperties.visible = true
        }
        if sender.state == NSOffState {
            channel!.displayProperties.visible = false
        }
        updateControlState()
    }
    
    // offset
    var offsetValue:Double = 0
    @IBOutlet weak var textfieldOffset: NSTextField!
    @IBOutlet weak var stepperOffset: NSStepper!
    
    @IBAction func offsetValueChanged(sender: AnyObject) {
        channel!.displayProperties.offset = offsetValue
    }
    
    // scaling
    var scalingValue:Double = 1.0
    @IBOutlet weak var textfieldScaling: NSTextField!
    @IBOutlet weak var stepperScaling: NSStepper!
    
    @IBAction func scalingValueChanged(sender: AnyObject) {
        channel!.displayProperties.scaling = scalingValue
    }
    
    //
    // TRIGGER CONTROLS
    //
    
    @IBOutlet weak var radioNoTrigger: NSButton!
    @IBOutlet weak var radioRisingEdge: NSButton!
    
    @IBAction func radioTriggerSelected(sender: NSButton) {
        switch sender {
        case radioNoTrigger:
            channel!.installTrigger(nil)
            break
        case radioRisingEdge:
            installRisingEdgeTrigger()
            break
        default:
            break
        }
        updateControlState()
    }
    
    //
    // RISING EDGE TRIGGER CONTROLS, INSTALLER
    //
    
    // level controls
    var risingEdgeLevelValue:Voltage = 0.0
    @IBOutlet weak var textfieldRisingEdgeLevel: NSTextField!
    @IBOutlet weak var stepperRisingEdgeLevel: NSStepper!
    @IBAction func risingEdgeLevelChanged(sender: AnyObject) {
        installRisingEdgeTrigger()
        updateControlState()
    }
    
    // level auto controls
    @IBOutlet weak var checkboxRisingEdgeLevelAuto: NSButton!
    @IBAction func checkboxRisingEdgeLevelAutoClicked(sender: NSButton) {
        installRisingEdgeTrigger()
        updateControlState()
    }
    
    // filter slider
    var risingEdgeFilterDepthValue:Int = 4
    @IBOutlet weak var sliderRisingEdgeFilter: NSSlider!
    @IBAction func sliderRisingEdgeFilterAction(sender: NSSlider) {
        installRisingEdgeTrigger()
        updateControlState() 
    }
    
    func installRisingEdgeTrigger() {
        // auto level tracking?
        var auto:Bool
        if (checkboxRisingEdgeLevelAuto.state == NSOnState) {
            auto = true
            // initial level?  let's average the last second of samples.
            let initialPeriodSamples = channel!.sampleBuffer.getSampleRange(TimeRange(newest:0.0, oldest:1.0))
            var initialPeriodTotal:Sample = 0
            for sample in initialPeriodSamples {
                initialPeriodTotal += sample
            }
            initialPeriodTotal /= initialPeriodSamples.count
            risingEdgeLevelValue = initialPeriodTotal.asVoltage()
        } else {
            auto = false
        }
        
        channel!.installTrigger(RisingEdgeTrigger(triggerLevel: risingEdgeLevelValue, autoLevel: auto, filterDepth: UInt(risingEdgeFilterDepthValue), notifications: channel!))
        
        print("Rising Edge Trigger: level = \(risingEdgeLevelValue)\t\tauto = \(auto)\t\tfilter depth = \(risingEdgeFilterDepthValue)")

    }
    
    //
    // UPDATE CONTROLS STATE
    //
    
    func updateControlState() {
        
        // DISPLAY control section enables / disables
        switch (channel!.displayProperties.visible) {
        case true:
            checkboxVisible.state = NSOnState
            textfieldOffset.enabled = true
            stepperOffset.enabled = true
            textfieldScaling.enabled = true
            stepperScaling.enabled = true
            break
        case false:
            checkboxVisible.state = NSOffState
            textfieldOffset.enabled = false
            stepperOffset.enabled = false
            textfieldScaling.enabled = false
            stepperScaling.enabled = false
            break
        }
        
        // is there a trigger installed? make sure the radio buttons reflect that
        if let trigger = channel!.sampleBuffer.trigger {
            voltmeterDisplayState = .PeakToPeak
            // yes. what kind?
            switch "\(trigger.dynamicType)" {
            case "RisingEdgeTrigger":
                radioRisingEdge.state = NSOnState
                break
            default:
                break
            }
        } else {
            // no trigger installed.
            voltmeterDisplayState = .Instantaneous
            radioNoTrigger.state = NSOnState
        }
        
        // RISING EDGE TRIGGER stuff
        
        if let trigger = channel!.sampleBuffer.trigger as? RisingEdgeTrigger {
            // it's a rising edge so the auto level checkbox should be enabled
            checkboxRisingEdgeLevelAuto.enabled = true
            // is autolevel actually selected?
            if ( trigger.autoLevel == true ) {
                // yes, manual is auto.  the value is a Reading now.
                checkboxRisingEdgeLevelAuto.state = NSOnState
                textfieldRisingEdgeLevel.enabled = false
                stepperRisingEdgeLevel.enabled = false
            } else {
                // no, level is set manually.
                checkboxRisingEdgeLevelAuto.state = NSOffState
                textfieldRisingEdgeLevel.enabled = true
                stepperRisingEdgeLevel.enabled = true
                // set the displayed level here.
                risingEdgeLevelValue = trigger.triggerLevel.asVoltage()
                textfieldRisingEdgeLevel.stringValue = "\(risingEdgeLevelValue)"
                stepperRisingEdgeLevel.stringValue = "\(risingEdgeLevelValue)"
            }

            // filter slider control
            sliderRisingEdgeFilter.enabled = true

        } else {
            // there's no rising edge trigger so disable this whole section
            checkboxRisingEdgeLevelAuto.enabled = false
            textfieldRisingEdgeLevel.enabled = false
            stepperRisingEdgeLevel.enabled = false
            sliderRisingEdgeFilter.enabled = false
        }
        
        // voltmeter
        switch (voltmeterDisplayState) {
        case .Disabled:
            break
        case .Instantaneous:
            labelReadingType.stringValue = "(Instant)"
            break
        case .PeakToPeak:
            labelReadingType.stringValue = "(Peak-to-peak)"
            break
        }
    }
    
    //
    // UPDATE READINGS
    //
    
    private var voltmeterReadingFilter = AveragingFilter<Voltage>(bufferSize: CONFIG_DISPLAY_CHANNELVIEW_FILTER_DEPTH, startingAverage: 0.0)
    private var frequencyMeterReadingFilter = AveragingFilter<Frequency>(bufferSize: CONFIG_DISPLAY_CHANNELVIEW_FILTER_DEPTH, startingAverage: 100)
    
    func updateReadings( ) {
        
        // voltmeter: display instant or peak-to-peak ...
        switch (voltmeterDisplayState) {
        case .Instantaneous:
            let newestInstantVoltage = voltmeterReadingFilter.filter(channel!.sampleBuffer.getNewestSample().asVoltage())
            labelVoltmeter.stringValue = newestInstantVoltage.asString()
            break
        case .PeakToPeak:
            if let event = channel!.newestTriggerEvent {
                let newestPtPVoltage = event.periodVoltageRange.span
                labelVoltmeter.stringValue = voltmeterReadingFilter.filter(newestPtPVoltage).asString()
            }
            break
        default:
            break
        }
        
        // frequency meter
        if let period = channel!.newestTriggerEvent?.samplesSinceLastEvent {
            let newFrequency:Frequency = Frequency(CONFIG_SAMPLERATE) / Frequency(period)
            labelFrequencyMeter.stringValue = frequencyMeterReadingFilter.filter(newFrequency).asString()
        }
        
        // if there's an auto-level trigger, update that reading ...
        if let trigger = channel!.sampleBuffer.trigger as? RisingEdgeTrigger {
            if (trigger.autoLevel) {
                risingEdgeLevelValue = trigger.triggerLevel.asVoltage()
                textfieldRisingEdgeLevel.stringValue = "\(risingEdgeLevelValue)"
                stepperRisingEdgeLevel.stringValue = "\(risingEdgeLevelValue)"
            }
        }
        
    }

    // The timer for that ...
    var updateReadingsTimer:NSTimer = NSTimer()

    func startUpdateReadingsTimer( ) {
        updateReadingsTimer = NSTimer.scheduledTimerWithTimeInterval(1/CONFIG_DISPLAY_CHANNELVIEW_REFRESH_RATE, target: self, selector: #selector(updateReadings), userInfo: nil, repeats: true)
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

        // HEADER SECTION - color well, voltmeter, freq meter

        colorWell.enabled = true
        if let ch = channel {
            colorWell.color = ch.displayProperties.traceColor
        }
        voltmeterDisplayState = .Instantaneous
        labelReadingType.stringValue = "(Instant)"
        labelFrequencyMeter.stringValue = "-----"
        
        // done. start the timer.
        updateControlState()
        startUpdateReadingsTimer()
    }
    
    func disableUI( ) {
        stopUpdateReadingsTimer()
        
        // HEADER SECTION - voltmeter, frequency meter, color picker, that stuff
        
        voltmeterDisplayState = .Disabled
        labelVoltmeter.stringValue = "-----"
        colorWell.enabled = false
        labelReadingType.stringValue = "-----"
        labelFrequencyMeter.stringValue = "-----"
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
