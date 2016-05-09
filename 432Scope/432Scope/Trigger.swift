//
//  Trigger.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation


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
    var level:Int
    
    init( capacity:Int, channelToNotify:ChannelDelegate, level:Int ) {
        print("---risingEdgeTrigger capacity:\(capacity) level:\(level)")
        self.level = level
        super.init(capacity: capacity, channelToNotify: channelToNotify)
        triggerEvent = TriggerEvent()
    }
    
    //
    // event detection FSM
    //
    
    enum RisingEdgeTriggerState {
        case ExpectingRise
        case ExpectingFall
    }
    
    var triggerState:RisingEdgeTriggerState = .ExpectingRise
    var triggerEvent = TriggerEvent()
    
    func trackTriggerEvent( newSample:Sample ) {
        triggerEvent.periodLengthInSamples += 1
        if ( newSample > triggerEvent.periodMax ) {
            triggerEvent.periodMax = newSample
        }
        if ( newSample < triggerEvent.periodMin ) {
            triggerEvent.periodMin = newSample
        }
    }
    func resetTriggerEvent( ) {
        triggerEvent = TriggerEvent()
    }
    
    override func processSample(newSample:Sample) {
        var nextState:RisingEdgeTriggerState = .ExpectingRise
        var outcomeOfTest:Bool = false
        
        // we have to cast it because level is an Int.  Level is an int because it may be desirable to set a trigger level outside the channel's range.
        let sample = Int(newSample)
        
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
        trackTriggerEvent(newSample)
        
        if ( outcomeOfTest == true ) {
            // we detected an event. send it off and reset
            channelToNotify!.triggerEventDetected(triggerEvent)
            resetTriggerEvent()
        }
    }
}

protocol ChannelDelegate {
    func triggerEventDetected( event:TriggerEvent )
}

struct TriggerEvent {
    var periodLengthInSamples:Int
    var periodMin:Sample
    var periodMax:Sample
    
    init() {
        periodLengthInSamples = 0
        periodMax = Sample.min
        periodMin = Sample.max
    }
}
