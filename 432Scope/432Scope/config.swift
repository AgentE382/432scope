//
//  config.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
import Cocoa

/*
 Global constants, build config ...
 */

// The display frame rate!
let CONFIG_DISPLAY_REFRESH_RATE:Double = 20

// If you really want that pixel-perfect look .....
let CONFIG_DISPLAY_ENABLE_ANTIALIASING:Bool = true

// Scope View grid colors
let colorBackground = NSColor(calibratedWhite: 0.0, alpha: 1.0)
let colorGridLine = NSColor(calibratedWhite: 0.2, alpha: 1.0)
let colorGroundLine = NSColor(calibratedWhite: 0.6, alpha: 1.0)

// make this higher for more drastic zooms
let CONFIG_DISPLAY_MAGNFICATION_FACTOR:Double = 1.2

// outer Scope View voltage limits
let CONFIG_DISPLAY_VOLTAGE_LIMITS:(min:Voltage, max:Voltage) = (-20, 20)

// minimum and maximum voltage display spans (zoom levels!)
let CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS:(min:Voltage, max:Voltage) = (0.1, CONFIG_DISPLAY_VOLTAGE_LIMITS.max - CONFIG_DISPLAY_VOLTAGE_LIMITS.min)

// grid line spacing at the largest possible visible span.
let CONFIG_DISPLAY_TIME_GRID_CONSTANT:CGFloat = 80
let CONFIG_DISPLAY_VOLTAGE_GRID_CONSTANT:CGFloat = 50

// The UART baud rate
let CONFIG_BAUDRATE:Int = 3000000

// the range of voltages the analog front end can accept
let CONFIG_AFE_VOLTAGE_RANGE:(min:Double, max:Double) = (-15.0, 15.0)

// the max bound that voltage range will get mapped to by the ADC.
let CONFIG_SAMPLE_MAX_VALUE:Sample = 16383 // 2^14-1

// TODO: build more intelligent device detection.  this is dumb.
let CONFIG_SINGLECHANNEL_DEVICE:String = "00000001"

// the 432's sample rate, in Hertz
let CONFIG_SINGLECHANNEL_SAMPLERATE:Int = 10000

// the buffer length, in seconds
let CONFIG_BUFFER_LENGTH:Int = 10

// the range of times that can be displayed on screen.
let CONFIG_DISPLAY_TIME_LIMITS:(newest:Time, oldest:Time) = (0.0, Time(CONFIG_BUFFER_LENGTH))

// the minimum and maximum time spans (zoom levels)
let CONFIG_DISPLAY_TIME_SPAN_LIMITS:(min:Time, max:Time) = (0.001, Time(CONFIG_BUFFER_LENGTH))




//
// NOW I'm using that stuff to compute some sane read and packet sizes.
// The packet size in particular will have to change when there's compression.
// But these should be decent for raw 16-bit samples.
//

// Internal sample and voltage formats.
typealias Sample = UInt16
typealias Voltage = Double

// sizeof(sample)
let CONFIG_SAMPLE_SIZE:Int = sizeof(Sample)

// some helpers ...
func roundDoubleUpToNearestSampleSize(value:Double) -> Int {
    let fractionNum = value / Double(CONFIG_SAMPLE_SIZE)
    let roundedNum = Int(ceil(fractionNum))
    return roundedNum * CONFIG_SAMPLE_SIZE
}

func clampToUInt8Range( value:Int ) -> UInt8 {
    if ( value < 0 ) {
        return UInt8(0)
    }
    if ( value > 255 ) {
        return UInt8(255)
    }
    return UInt8(value)
}

func clampValue<T:Comparable>( inout value:T, bounds:(min:T, max:T) ) {
    // if the bounds are messed up, you (caller) can go to hell.  behavior undefined.  actually it'll just return bounds.max.  but go to hell anyway.
    if ( value < bounds.min ) {
        value = bounds.min
        return
    }
    if ( value > bounds.max ) {
        value = bounds.max
        return
    }
}

let CONFIG_INCOMING_DATA_BYTES_PER_SECOND:Int = CONFIG_SINGLECHANNEL_SAMPLERATE * CONFIG_SAMPLE_SIZE

let CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME:Double = Double(CONFIG_INCOMING_DATA_BYTES_PER_SECOND)/CONFIG_DISPLAY_REFRESH_RATE

// The decoder packet size also in bytes.
let CONFIG_DECODER_PACKET_SIZE:Int = roundDoubleUpToNearestSampleSize(CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME)

// The POSIX read length in bytes
let CONFIG_POSIX_READ_LENGTH:UInt8 = clampToUInt8Range(CONFIG_DECODER_PACKET_SIZE)

func getVoltageAsString( voltage:Voltage ) -> String {
    if ( abs(voltage) < 0.001 ) {
        // display micro volts
        let displayNumber = voltage * 1000
        return String(format:"%3.4f", displayNumber) + " \u{03BC}V"
    }
    if ( abs(voltage) < 1 ) {
        // display millivolts
        let displayNumber = voltage * 1000
        return String(format:"%3.4f", displayNumber) + " mV"
    }
    return String(format:"%.4f", voltage) + " V"
}

func getTimeAsString( time:Time ) ->String {
    if ( abs(time) < 0.001 ) {
        // display micro
        let displayNumber = time * 1000
        return String(format:"%3.4f", displayNumber) + " \u{03BC}S"
    }
    if ( abs(time) < 1 ) {
        // display milli
        let displayNumber = time * 1000
        return String(format:"%3.4f", displayNumber) + " mS"
    }
    return String(format:"%.4f", time) + " S"
}



