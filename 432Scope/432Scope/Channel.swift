//
//  Channel.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/1/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
import Cocoa

class Channel : TriggerDelegate {
    
    //
    // TRIGGERING
    //
    
    func getTriggeredCenterTime( visibleRangeHalfSpan:Time ) -> Time? {
        // if there's actually no trigger attached, this isn't gonna work ...
        guard sampleBuffer.trigger != nil else {
            return nil
        }
        
        // if there's a trigger but no events yet, same deal ...
        let events = sampleBuffer.trigger!.eventTimestamps
        let currentTime = sampleBuffer.trigger!.currentTimestamp
        guard events.count > 0 else {
            return nil
        }

        let minimumSampleAge = UInt(visibleRangeHalfSpan.asSampleIndex())
  //      print ("\nvisibleRangeHalfSpan: \(visibleRangeHalfSpan)\t\tminimumSampleAge: \(minimumSampleAge)")
        

        for i in 1...events.count {
            let index = events.count - i
            let age = currentTime &- events[index]
            if ( age > minimumSampleAge ) {
   //             print("---ACCEPTED \(age)")
                return SampleIndex(age).asTime()
            } else {
//                print("---rejected age \(age)")
            }
        }
        
        return nil
    }
    
    // ChannelViewController can call these to set up whatever trigger it wants
    func installNoTrigger() {
        sampleBuffer.trigger = nil
        lastTriggerEvent = nil
    }
    
    func installRisingEdgeTrigger( triggerLevel:Voltage ) {
        sampleBuffer.trigger = RisingEdgeTrigger(capacity: CONFIG_SAMPLERATE*CONFIG_BUFFER_LENGTH, channelToNotify: self as TriggerDelegate, level:triggerLevel.asSample() )
        lastTriggerEvent = nil
    }
    
    private var lastTriggerEvent:TriggerEvent? = nil
    
    func triggerEventDetected( event:TriggerEvent ) {
        if let lastEvent = lastTriggerEvent {
            // there's been a prior event to compare this new one to, so we can compute frequency.
            let period = event.timestamp - lastEvent.timestamp
            triggerFrequency = Frequency(CONFIG_SAMPLERATE) / Frequency(period)
        }
        lastTriggerEvent = event
        print("\(event)")
    }
    
    // Information the ChannelViewController and others will probably want to know.
    private(set) var triggerFrequency:Frequency = 0.0
    
    var triggerPeriodVoltageRange:VoltageRange {
        get {
            guard lastTriggerEvent != nil else {
                return VoltageRange(min:0, max:0)
            }
            return VoltageRange(min: lastTriggerEvent!.periodLowestSample.asVoltage(), max: lastTriggerEvent!.periodHighestSample.asVoltage())
        }
    }
    
    //
    // FUNDAMENTALS
    //
    
    // display parameters
    var traceColor = TraceColorGenerator.getColor()
    
    // the signal chain
    var transceiver:Transceiver? = nil
    var decoder:Decoder? = nil
    var sampleBuffer = SampleBuffer()
    
    // might need to know these externally.
    private(set) var isChannelOn:Bool = false
    
    // might need to know these internally.
    var device:USBDevice? = nil;
    
    init( device:USBDevice, sampleRateInHertz:Int, bufferLengthInSeconds:Int ) throws {
        self.device = device
        
        // create a sample buffer ...
        let bufferCapacity:Int = sampleRateInHertz * bufferLengthInSeconds
        sampleBuffer = SampleBuffer(capacity: bufferCapacity, clearValue: Voltage(0.0).asSample() )
        print("----Channel.init() created \(bufferCapacity)-deep sample buffer")
        
        // and a decoder ...
        decoder = Decoder(packetSizeInBytes: CONFIG_DECODER_PACKET_SIZE, sampleBuffer: sampleBuffer )
        
        // and a transceiver.
        try transceiver = Transceiver(deviceFilePath: device.deviceFile, decoder: decoder!)
        
        print( "Channel(): \(device.deviceFile) open." )
        
    }
    
    func channelOn( ) throws {
        transceiver!.flush()
        sampleBuffer.clearAllSamples( Voltage(0.0).asSample() )
        try transceiver!.send("Start")
        isChannelOn = true
    }
    
    func channelOff( ) throws {
        isChannelOn = false
        try transceiver!.send("Stop")
        transceiver!.flush()
    }
    
    deinit {
        print( "----Channel.deinit" )
        if (transceiver != nil ) {
            do { try transceiver!.closeTerminal()
            } catch let msg {
                print(msg)
                print("Channel deinit: closeTerminal failed.")
            }
        }
    }
    
    //
    // FRONTEND
    //
    
    var name:String {
        if ( device == nil ) {
            return "i am a channel without a device."
        }
        return device!.deviceFile
    }
}

//
// This thing just wraps up the trace color assignments.
//

class TraceColorGenerator {
    private static var counter:Int = 0
    private static var scopeTraceColors:NSColorList? = nil
    private static var channelColorKeys:[String] = []
    
    class func getColor( ) -> NSColor {
        // we need to generate the color list first time this is called.
        if (scopeTraceColors == nil) {
            createColorList()
        }
        
        let index = counter % channelColorKeys.count
        let color = scopeTraceColors!.colorWithKey(channelColorKeys[index])
        counter += 1
        return color!
    }
    
    private class func createColorList( ) {
        // create a list of colors to use as default channel trace colors, removing black and white
        let appleColorList = NSColorList(named: "Apple")
        scopeTraceColors = NSColorList(name: "Scope Trace Colors" )
        for color in appleColorList!.allKeys {
            if ( color == "Black" || color == "White" ) {
                continue
            }
            scopeTraceColors!.insertColor((appleColorList?.colorWithKey(color))!, key: color, atIndex: 0)
        }
        channelColorKeys = scopeTraceColors!.allKeys
    }
}

