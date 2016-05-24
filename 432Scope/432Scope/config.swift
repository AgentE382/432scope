//
//  config.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
import Cocoa

//
// DISPLAY
//

// The trace display (ScopeViewController) frame rate!
let CONFIG_DISPLAY_REFRESH_RATE:Double = 20

// Scope View grid colors
let CONFIG_DISPLAY_SCOPEVIEW_BACKGROUND_COLOR = NSColor(calibratedWhite: 0.0, alpha: 1.0)
let CONFIG_DISPLAY_SCOPEVIEW_GRIDLINE_COLOR = NSColor(calibratedWhite: 1.0, alpha: 0.2)
let CONFIG_DISPLAY_SCOPEVIEW_GROUNDLINE_COLOR = NSColor(calibratedWhite: 1.0, alpha: 1.0)

// scope view scrolling limits
let CONFIG_DISPLAY_TIME_LIMITS = TimeRange(newest:0, oldest:-10)
let CONFIG_DISPLAY_VOLTAGE_LIMITS = VoltageRange(min:-20, max:20)

// scope view zooming limits
let CONFIG_DISPLAY_TIME_SPAN_LIMITS:(min:Time, max:Time) = (0.001, CONFIG_DISPLAY_TIME_LIMITS.span)
let CONFIG_DISPLAY_VOLTAGE_SPAN_LIMITS:(min:Voltage, max:Voltage) = (0.1, CONFIG_DISPLAY_VOLTAGE_LIMITS.span)

// grid line spacing constant.  This is essentially the minimum space between gridlines.
let CONFIG_DISPLAY_TIME_GRID_CONSTANT:CGFloat = 80
let CONFIG_DISPLAY_VOLTAGE_GRID_CONSTANT:CGFloat = 50

// channel view reading rate in FPS, and depth of the filter on those readings
let CONFIG_DISPLAY_CHANNELVIEW_REFRESH_RATE:Double = 10
let CONFIG_DISPLAY_CHANNELVIEW_FILTER_DEPTH:Int = 16

//
// I/O
//

// The UART baud rate
let CONFIG_BAUDRATE:Int = 3000000

// how many Bytes come through the UART per sample (this value is used to compute read lengths)
let CONFIG_INCOMING_SAMPLE_SIZE_IN_BYTES:Int = 2

// the 432's sample rate, in Hertz
let CONFIG_SAMPLERATE:Int = 100000

// the length of time to store in the sample buffers
let CONFIG_BUFFER_LENGTH:Int = 10

// the range of voltages the analog front end can accept
let CONFIG_AFE_VOLTAGE_RANGE = VoltageRange(min:-15.0, max:15.0)

// the max bound that voltage range will get mapped to by the ADC.
let CONFIG_SAMPLE_MAX_VALUE:Sample = 16383 // 2^14-1



//
// NOW I'm using that stuff to compute some other constants.  Don't configure these directly.
//

let CONFIG_SAMPLEPERIOD:Time = 1.0/Time(CONFIG_SAMPLERATE)

let CONFIG_INCOMING_BYTES_PER_SECOND:Int = CONFIG_SAMPLERATE * CONFIG_INCOMING_SAMPLE_SIZE_IN_BYTES

let CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME:Double = Double(CONFIG_INCOMING_BYTES_PER_SECOND)/CONFIG_DISPLAY_REFRESH_RATE

// The decoder packet size also in bytes.
let CONFIG_DECODER_PACKET_SIZE:Int = roundDoubleUpToNearestIncomingSampleBoundary(CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME)

// The POSIX termios.vmin minimum read length in bytes.  At high sample rates, most reads will be much bigger than this anyway.
let CONFIG_POSIX_READ_LENGTH:UInt8 = UInt8(clampToRange(CONFIG_DECODER_PACKET_SIZE, min: 2, max: 254))


func roundDoubleUpToNearestIncomingSampleBoundary(value:Double) -> Int {
    let fractionNum = value / Double(CONFIG_INCOMING_SAMPLE_SIZE_IN_BYTES)
    let roundedNum = Int(ceil(fractionNum))
    return roundedNum * CONFIG_INCOMING_SAMPLE_SIZE_IN_BYTES
}

