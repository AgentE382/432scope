//
//  Decoder.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/30/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation


/*
 After Receiver has brought in from the UART and split it up into packets, it goes here
 where we convert it from whatever weird compressed format into sample values.
*/

class Decoder {

    // wiring
    var sampleBuffer:SampleBuffer? = nil
    
    private(set) var packetSize:Int? = nil;
    private var gcdDecoderQueue:dispatch_queue_t? = nil

    init( packetSizeInBytes ps:Int, sampleBuffer sb:SampleBuffer ) {
        self.packetSize = ps
        self.sampleBuffer = sb
        gcdDecoderQueue = dispatch_queue_create("decoderQueue", DISPATCH_QUEUE_SERIAL)
    }
    
    func newPacketArrived( packet:NSData ) {
        dispatch_async( gcdDecoderQueue!, {
            
            //
            // PACKET DECOMPRESSION CODE STARTS HERE!
            //
            
            // for now it's just raw 16 bit samples.
            
//            print( "new packet arrived: \(packet.length) bytes" )
        
            var aNewSample:Sample = 0
            var i:Int = 0
            while ( i < packet.length ) {
                packet.getBytes(&aNewSample, range: NSRange(location: i, length: 2))
                self.sampleBuffer!.storeNewSample(aNewSample)
                i += 2
            }
            
            //
            // THAT'S ALL, FOLKS
            //
        })
    }

}