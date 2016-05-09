//
//  Channel.swift
//  432scope
//
//  Created by Nicholas Cordle on 5/1/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
import Cocoa

/*


 */
typealias Time = CGFloat
typealias SampleIndexRange = (newest:Int, oldest:Int)

class Channel {
    
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
    var sampleRateInHertz:Int = 0 // samples per second
    private(set) var bufferLengthInSeconds:Int = 0
    
    init( device:USBDevice, sampleRateInHertz:Int, bufferLengthInSeconds:Int ) throws {
        self.device = device
        self.sampleRateInHertz = sampleRateInHertz
        self.bufferLengthInSeconds = bufferLengthInSeconds
        
        // create a sample buffer ...
        let bufferCapacity:Int = sampleRateInHertz * bufferLengthInSeconds
        sampleBuffer = SampleBuffer(capacity: bufferCapacity, clearValue: groundSampleValue)
        print("----Channel.init() created \(bufferCapacity)-deep sample buffer")
        
        // and a decoder ...
        decoder = Decoder(packetSizeInBytes: CONFIG_DECODER_PACKET_SIZE, sampleBuffer: sampleBuffer )
        
        // and a transceiver.
        try transceiver = Transceiver(deviceFilePath: device.deviceFile, decoder: decoder!)
        
        print( "Channel(): \(device.deviceFile) open." )
        
    }
    
    func channelOn( ) throws {
        transceiver!.flush()
        sampleBuffer.clearAllSamples( groundSampleValue)
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
    
    func getName( ) -> String {
        if ( device == nil ) {
            return "i am a channel without a device."
        }
        return device!.deviceFile
    }
    
    func getInstantaneousVoltage( ) -> Voltage {
        return translateSampleToVoltage(sampleBuffer.getNewestSample())
    }
    
    func getSampleRange( timeRange:TimeRange ) -> Array<Sample> {
        let sampleIndices = translateTimeRangeToSampleIndices(timeRange)
        return sampleBuffer.getSubArray(sampleIndices)
    }
    
    func translateTimeRangeToSampleIndices( timeRange:TimeRange ) -> SampleIndexRange {
        let newestIndex = timeRange.newest * Time(sampleRateInHertz)
        var oldestIndex = timeRange.oldest * Time(sampleRateInHertz)
        if (oldestIndex < 1 ) {
            oldestIndex = 1
        }
        return SampleIndexRange(newest:Int(floor(newestIndex)),
                                oldest:Int(floor(oldestIndex))-1)
    }
    
    //
    // INTERNAL HELPERS
    //
    
    // these are used to translate samples to voltages
    let voltageScaleOffset:Voltage = CONFIG_AFE_VOLTAGE_RANGE.min
    let scaleFactorSampleToVoltage:Voltage = (CONFIG_AFE_VOLTAGE_RANGE.max - CONFIG_AFE_VOLTAGE_RANGE.min) / Voltage(CONFIG_SAMPLE_MAX_VALUE)
    let scaleFactorVoltageToSample:Voltage = Voltage(CONFIG_SAMPLE_MAX_VALUE)/(CONFIG_AFE_VOLTAGE_RANGE.max - CONFIG_AFE_VOLTAGE_RANGE.min)
    
    func translateSampleToVoltage( sample:Sample ) -> Voltage {
        let rval:Voltage = Voltage(sample) * scaleFactorSampleToVoltage
        return rval + voltageScaleOffset
    }
    
    var groundSampleValue:Sample {
        return Sample(translateVoltageToSample(0.0))
    }
    
    // this must return Int so that it can provide a value for voltages that are actually
    // out of range.  it's for the display.
    func translateVoltageToSample( voltage:Voltage ) -> Int {
        let rval:Voltage = voltage - voltageScaleOffset
        // floor this?
        return Int(rval * scaleFactorVoltageToSample)
    }
}



