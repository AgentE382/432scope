//
//  Trigger.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation


protocol TriggerNotifications {
    func triggerEventDetected( event:TriggerEvent )
}

class Trigger {
    
    var notifications:TriggerNotifications?
    
    //
    // EVENT TIMEKEEPING ARRAY
    //
    
    private(set) var currentTimestamp:UInt = 0
    private(set) var eventTimestamps:[UInt] = []
    private var capacity:Int = 0 // this is really the age of the oldest timestamp we need to preserve.
    
    private func recordTimestamp() {
        eventTimestamps.append(currentTimestamp)
        
        // while we're at it, cull any really old ones.
        for _ in 0..<eventTimestamps.count {
            let age = currentTimestamp &- eventTimestamps[0]
            if (age >= UInt(capacity)) {
                eventTimestamps.removeAtIndex(0)
            }
        }
    }
    
    //
    // MINMAX TRACKING
    //
    
    private var periodMin:Sample = Sample.max
    private var periodMax:Sample = Sample.min
    
    private func resetMinMax( ) {
        periodMin = Sample.max
        periodMax = Sample.min
    }
    
    private func updateMinMax(newSample:Sample) {
        if (newSample < periodMin) {
            periodMin = newSample
        }
        if (newSample > periodMax) {
            periodMax = newSample
        }
    }
    
    //
    // WHAT HAPPENS WHEN AN EVENT IS DETECTED
    //
    
    // derived classes should call this when they detect an event to store it in the timekeeping array.
    private func eventHappened(newSample:Sample) {
        updateMinMax(newSample)
        recordTimestamp()
        notifications!.triggerEventDetected(TriggerEvent(timestamp: currentTimestamp, periodLowestSample: periodMin, periodHighestSample: periodMax))
        resetMinMax()
        currentTimestamp = currentTimestamp &+ 1
    }

    // derived classes should call this when they have gotten a new sample and determined it was NOT a trigger event.
    private func eventDidNotHappen(newSample:Sample) {
        // update the minmax
        updateMinMax(newSample)
        // increment the clock
        currentTimestamp = currentTimestamp &+ 1
    }
    
    //
    // INIT AND BASE CLASS FUNCTIONS TO OVERRIDE
    //
    
    init() {
        print( "---trigger.init DON'T DO THIS" )
    }
    
    init( capacity:Int ) {
        print( "---trigger.init capacity:\(capacity)" )
        self.capacity = capacity
    }
    
    func processSample( sample:Sample ) {
        // this should be overridden
        print("---trigger.processSample SHOULD NOT BE GETTING CALLED.")
    }
}



class RisingEdgeTrigger: Trigger {
    var level:Int
    
    init( capacity:Int, level:Int ) {
        print("---risingEdgeTrigger capacity:\(capacity) level:\(level)")
        self.level = level
        super.init(capacity: capacity)
    }
    
    //
    // event detection FSM
    //
    
    enum RisingEdgeTriggerState {
        case ExpectingRise
        case ExpectingFall
    }
    
    var triggerState:RisingEdgeTriggerState = .ExpectingRise
    
    override func processSample(newSample:Sample) {
        var nextState:RisingEdgeTriggerState = .ExpectingRise
        var outcomeOfTest:Int = 0
        
        // we have to cast it because level is an Int.  Level is an int because it may be desirable to set a trigger level outside the channel's range.
        
        switch (triggerState) {
            
        case .ExpectingRise: // voltage has been under level and we're waiting for it to go up
            if ( newSample < level ) {
                // it's not up yet.
                nextState = .ExpectingRise
            }
            if ( newSample >= level ) {
                // got one!
                nextState = .ExpectingFall
                outcomeOfTest = 1
            }
            break
            
        case .ExpectingFall:
            if ( newSample < level ) {
                // it fell. reset ...
                nextState = .ExpectingRise
            }
            if ( newSample >= level ) {
                // still high
                nextState = .ExpectingFall
            }
            break
        }
        
        // store the result, advance the state
        triggerState = nextState
        
        if ( outcomeOfTest == 1 ) {
            // we detected an event. send it off and reset
            eventHappened(newSample)
        } else {
            eventDidNotHappen(newSample)
        }
    }
}


struct TriggerEvent {
    var timestamp:UInt
    var periodLowestSample:Sample
    var periodHighestSample:Sample
    
    init() {
        timestamp = 0
        periodLowestSample = 0
        periodHighestSample = 0
    }
    
    init( timestamp:UInt, periodLowestSample:Sample, periodHighestSample:Sample ) {
        self.timestamp = timestamp
        self.periodLowestSample = periodLowestSample
        self.periodHighestSample = periodHighestSample
    }
}
