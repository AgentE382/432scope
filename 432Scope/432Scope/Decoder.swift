//
//  Decoder.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/30/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation


/*
 After Transceiver has brought in from the UART and split it up into packets, it goes here where we convert it from whatever weird compressed format into sample values.
 
 This class also sends out a notification when it's done decoding and storing a packet, so that frames can be triggered based on that info.
*/

protocol DecoderNotifications {
    func decoderPacketFinished()
}

class Decoder {

    private var sampleBuffer:SampleBuffer? = nil
    var notifications:DecoderNotifications? = nil
    
    init( sampleBuffer sb:SampleBuffer) {
        self.sampleBuffer = sb
    }
    
    func newPacketArrived( packet:NSData ) {
        
            //
            // PACKET DECOMPRESSION CODE STARTS HERE!
            //
        
        // for now it's just raw 16 bit samples.
        var aNewSample:Sample = 0
        var i:Int = 0
        while ( i < packet.length ) {
            packet.getBytes(&aNewSample, range: NSRange(location: i, length: 2))
            self.sampleBuffer!.storeNewSample(aNewSample)
            i += 2
        }
        
        // let the boss know our work here is done.
        if let boss = notifications {
            boss.decoderPacketFinished()
        }
            
            //
            // THAT'S ALL, FOLKS
            //
    }

}
