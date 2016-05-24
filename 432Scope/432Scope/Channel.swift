//
//  Channel.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/1/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
import Cocoa

protocol ChannelNotifications {
    func channelHasNewData(sender:Channel) // new samples have been processed and stored in this channel's buffer
    func channelTriggerChanged(sender:Channel) // this channel's trigger setup has changed
}

typealias ChannelDisplayProperties = (traceColor:NSColor, visible:Bool, offset:Voltage, scaling:Double)

class Channel : TriggerNotifications, DecoderNotifications {
    
    //
    // DECODER NOTIFICATION
    //
    
    var isDrawable:Bool = false
    
    func decoderPacketFinished() {
        if let svc = notifications {
            isDrawable = true
            svc.channelHasNewData(self)
        }
    }

    
    //
    // TRIGGERING - once a trigger is installed, triggerEventDetected gets called when there's an event.
    //
    
    var hasTrigger:Bool {
        get {
            if sampleBuffer.trigger == nil {
                return false
            }
            return true
        }
    }
    
    func installTrigger( newTrigger:Trigger? ) {
        print("----Channel.installTrigger")
        
        // whatever the deal is, values stored in these are no longer relevant.
        newestTriggerEvent = nil
        
        if newTrigger == nil {
            // remove the trigger.
            sampleBuffer.trigger = nil
        } else {
            // install the new one
            sampleBuffer.trigger = newTrigger
        }
        
        notifications?.channelTriggerChanged(self)
    }
    
    // the basic notification handler
    func triggerEventDetected( event:TriggerEvent ) {
        newestTriggerEvent = event
    }
    
    // compute interesting things based on trigger events
    private(set) var newestTriggerEvent:TriggerEvent? = nil
    
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
        
        let minimumSampleIndex = UInt((-visibleRangeHalfSpan).asSampleIndex())
        for i in 1...events.count {
            // we have to do a little index-flipping math to count down, because the newest timestamps are at the end of the array.
            let index = events.count - i
            let age = currentTime &- events[index]
            if ( age > minimumSampleIndex ) {
                return SampleIndex(age).asTime()
            }
        }
        return nil
    }
    
    //
    // DISPLAY PROPERTIES
    //
    
    var displayProperties:ChannelDisplayProperties = (
        traceColor: TraceColorGenerator.getColor(),
        visible: true,
        offset: 0.0,
        scaling: 1.0
    )
    
    //
    // FUNDAMENTALS
    //
    
    // this sends out "drawable" notifications when a new data packet is through processing.
    var notifications:ChannelNotifications? = nil
    
    // the signal chain
    private(set) var transceiver:Transceiver? = nil
    private(set) var decoder:Decoder? = nil
    private(set) var sampleBuffer = SampleBuffer()
    
    private(set) var isChannelOn:Bool = false
    
    private(set) var device:USBDevice? = nil;
    
    var name:String {
        if ( device == nil ) {
            return "i am a channel without a device."
        }
        return device!.deviceFile
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
    
    init( device:USBDevice, sampleRateInHertz:Int, bufferLengthInSeconds:Int ) throws {
        self.device = device
        
        // create a sample buffer ...
        let bufferCapacity:Int = sampleRateInHertz * bufferLengthInSeconds
        sampleBuffer = SampleBuffer(capacity: bufferCapacity, clearValue: Voltage(0.0).asSample() )
        print("----Channel.init() created \(bufferCapacity)-deep sample buffer")
        
        // and a decoder ...
        decoder = Decoder(sampleBuffer: sampleBuffer)
        decoder!.notifications = self
        
        // and a transceiver.
        try transceiver = Transceiver(deviceFilePath: device.deviceFile, decoder: decoder!)
        
        print( "Channel(): \(device.deviceFile) open." )
        
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

