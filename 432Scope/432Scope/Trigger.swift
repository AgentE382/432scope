//
//  Trigger.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation

protocol ChannelDelegate {
    func triggerEventDetected( samplesSinceLastTrigger:Int )
}

class Trigger {
    
    private(set) var triggerEventBuffer = CircularArray<Bool>()
    private(set) var channelToNotify:ChannelDelegate?
    
    init() {
        print( "---trigger.init DON'T DO THIS" )
    }
    
    init( capacity:Int, channelToNotify:ChannelDelegate ) {
        print( "---trigger.init capacity:\(capacity)" )
        triggerEventBuffer = CircularArray<Bool>(capacity: capacity, repeatedValue: false)
        self.channelToNotify = channelToNotify
    }
    
    func processSample( sample:Sample ) {
        // this should be overridden
        print("---trigger.processSample SHOULD NOT BE GETTING CALLED.")
    }
}



class RisingEdgeTrigger: Trigger {
    var level:Sample
    
    init( capacity:Int, channelToNotify:ChannelDelegate, level:Sample ) {
        print("---risingEdgeTrigger capacity:\(capacity) level:\(level)")
        self.level = level
        super.init(capacity: capacity, channelToNotify: channelToNotify)
    }
    
    //
    // event detection FSM
    //
    
    enum RisingEdgeTriggerState {
        case ExpectingRise
        case ExpectingFall
    }
    
    var triggerState:RisingEdgeTriggerState = .ExpectingRise
    
    override func processSample(sample:Sample) {
        var nextState:RisingEdgeTriggerState = .ExpectingRise
        var outcomeOfTest:Bool = false
        
        switch (triggerState) {
            
        case .ExpectingRise: // voltage has been under level and we're waiting for it to go up
            if ( sample < level ) {
                // it's not up yet.
                nextState = .ExpectingRise
            }
            if ( sample >= level ) {
                // got one!
                nextState = .ExpectingFall
                outcomeOfTest = true
                channelToNotify!.triggerEventDetected(-1)
            }
            break
            
        case .ExpectingFall:
            if ( sample < level ) {
                // it fell. reset ...
                nextState = .ExpectingRise
            }
            if ( sample >= level ) {
                // still high
                nextState = .ExpectingFall
            }
            break
        }
        
        // store the result, advance the state
        triggerEventBuffer.storeNewEntry(outcomeOfTest)
        triggerState = nextState
    }
}
