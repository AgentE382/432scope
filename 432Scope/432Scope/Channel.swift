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
    
    func setTrigger( triggerLevel:Voltage? ) {
        if let level = triggerLevel {
            sampleBuffer.trigger = RisingEdgeTrigger(capacity: CONFIG_SAMPLERATE*CONFIG_BUFFER_LENGTH, channelToNotify: self as TriggerDelegate, level:level.asSample() )
        } else {
            sampleBuffer.trigger = nil
        }
    }
    
    private var periodMinSample:Sample = 0
    private var periodMaxSample:Sample = 0
    private var periodLengthInSamples:Int = 0
    
    var periodMin:Voltage {
        get {
            return periodMinSample.asVoltage()
        }
    }
    
    var periodMax:Voltage {
        get {
            return periodMaxSample.asVoltage()
        }
    }
    
    var triggerFrequency:Frequency {
        get {
            return Frequency(CONFIG_SAMPLERATE)/Frequency(periodLengthInSamples)
        }
    }
    
    func triggerEventDetected( event:TriggerEvent ) {
        periodMinSample = event.periodMin
        periodMaxSample = event.periodMax
        periodLengthInSamples = event.periodLengthInSamples
    }
    
    // display parameters
    var displayColor = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
    
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
        try transceiver!.send("Stop")
        transceiver!.flush()
        isChannelOn = false
    }
    
    deinit {
        print( "----Channel.deinit" )
        if (transceiver != nil ) {
            do { try transceiver!.closeTerminal()
            } catch {
                print("Channel deinit: closeTerminal failed.")
            }
        }
    }
    
    //
    // FRONTEND
    //
    
 /*   func getTimeRangeMinMax( timeRange:TimeRange ) -> (min:Sample, max:Sample) {
        let indexRange = translateTimeRangeToSampleIndices(timeRange)
        return sampleBuffer.getLocalMinMax(indexRange)
    }*/
    
    func getName( ) -> String {
        if ( device == nil ) {
            return "i am a channel without a device."
        }
        return device!.deviceFile
    }
    
    func getInstantaneousVoltage( ) -> Voltage {
        return sampleBuffer.getNewestSample().asVoltage()
    }
    
    func getSampleRange( timeRange:TimeRange ) -> Array<Sample> {
        let sampleIndices = timeRange.asSampleIndexRange()
        return sampleBuffer.getSubArray(sampleIndices)
    }
    
    //
    // INTERNAL HELPERS
    //
    
 /*
    func translateSampleToVoltage( sample:Sample ) -> Voltage {
        let rval:Voltage = Voltage(sample) * scaleFactorSampleToVoltage
        return rval + voltageScaleOffset
    }*/
}



