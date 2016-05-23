//
//  Trigger.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/8/16.
//
//

import Foundation

//
// How to make a new type of trigger:
//
// - derive from Trigger class.
// - make an initializer.
//      - it must call super.init(capacity:Int) at the end
// - override processSample.
//      - if processSample gets an edge event, call super.eventHappened.
//      - if no event, call super.eventDidNotHappen.

//
// BASE CLASS
//

// This notification gets sent out when an event is detected.  Base class handles this.

protocol TriggerNotifications {
    func triggerEventDetected( event:TriggerEvent )
}

class Trigger {
    
    var notifications:TriggerNotifications
    
    //
    // EVENT TIMEKEEPING ARRAY
    //
    
    private(set) var currentTimestamp:UInt = 0
    private(set) var eventTimestamps:[UInt] = []
    private var capacity:Int = 0 // this is really the age of the oldest timestamp we need to preserve.
    
    private var lastEventTimestamp:UInt? {
        get {
            let eventCount = eventTimestamps.count
            if ( eventCount == 0 ) {
                return nil
            }
            return eventTimestamps[eventCount-1]
        }
    }
    
    private func recordTimestamp(latencyCorrection:UInt) {
        eventTimestamps.append(currentTimestamp &- latencyCorrection)
        
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
    private func eventHappened(newSample:Sample, triggerLatency:UInt) {
        updateMinMax(newSample)
        var samplesSinceLastEvent:Int? = nil
        if ( lastEventTimestamp != nil ) {
            samplesSinceLastEvent = Int((currentTimestamp &- triggerLatency) &- lastEventTimestamp!)
        }
        notifications.triggerEventDetected( TriggerEvent(
                timestamp: currentTimestamp &- triggerLatency,
                periodLowestSample: periodMin,
                periodHighestSample: periodMax,
                samplesSinceLastEvent: samplesSinceLastEvent
            ))
        recordTimestamp(triggerLatency)
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
    
    init( capacity:Int, notifications:TriggerNotifications ) {
        self.capacity = capacity
        self.notifications = notifications
    }
    
    func processSample( sample:Sample ) {
        // this should be overridden
        print("---trigger.processSample SHOULD NOT BE GETTING CALLED.")
    }
}

struct TriggerEvent {
    
    // A trigger class must set these before sending the event along
    var timestamp:UInt
    var periodLowestSample:Sample
    var periodHighestSample:Sample
    var samplesSinceLastEvent:Int?
    
    var periodVoltageRange:VoltageRange {
        get {
            return VoltageRange(min:periodLowestSample.asVoltage(), max:periodHighestSample.asVoltage())
        }
    }
    
    init() {
        timestamp = 0
        periodLowestSample = 0
        periodHighestSample = 0
        samplesSinceLastEvent = nil
    }
    
    init( timestamp:UInt, periodLowestSample:Sample, periodHighestSample:Sample, samplesSinceLastEvent:Int? ) {
        self.timestamp = timestamp
        self.periodLowestSample = periodLowestSample
        self.periodHighestSample = periodHighestSample
        self.samplesSinceLastEvent = samplesSinceLastEvent
    }
}

//
// DERIVED CLASSES (the actual triggers)
//

// This one is a rising edge filter with an averaging filter, optional auto-level

class RisingEdgeTrigger: Trigger {
    
    private(set) var triggerLevel:Sample
    private(set) var autoLevel:Bool
    private var sampleFilter:FastSampleAveragingFilter
    private var autoLevelFilter:AveragingFilter<Sample>
    
    init(triggerLevel:Voltage, autoLevel:Bool, filterDepth:UInt, notifications:TriggerNotifications) {
        self.triggerLevel = triggerLevel.asSample()
        self.autoLevel = autoLevel
        self.sampleFilter = FastSampleAveragingFilter(depthExponent: filterDepth, initialAverage: Voltage(0.0).asSample())
        self.autoLevelFilter = AveragingFilter<Sample>(bufferSize: Int(exp2(Double(filterDepth))),
            startingAverage: triggerLevel.asSample())
        // setting capacity to CONFIG_SAMPLERATE means we'll only watch the latest second of events.  this will be a problem for <1Hz signals.
        super.init(capacity: CONFIG_SAMPLERATE, notifications: notifications)
    }
    
    enum RisingEdgeTriggerState {
        case ExpectingRise
        case ExpectingFall
    }
    
    private var triggerState:RisingEdgeTriggerState = .ExpectingFall
    
    override func processSample(sample: Sample) {
        
        // filtering
        let newValue = sampleFilter.filter(sample)
        
        // edge detection FSM
        var nextState:RisingEdgeTriggerState
        var edgeTestResult:Bool = false
        
        switch triggerState {
        case .ExpectingRise:
            if (newValue > triggerLevel ) {
                // got one. that's an event.
                edgeTestResult = true
                nextState = .ExpectingFall
            } else {
                // still waiting.
                nextState = .ExpectingRise
            }
            break
        case .ExpectingFall:
            if ( newValue < triggerLevel ) {
                // we're back below the level.
                nextState = .ExpectingRise
            } else {
                // still above the threshold.
                nextState = .ExpectingFall
            }
            break
        }
        
        if edgeTestResult {
            // okay we got a trigger event.  figure out the filter latency ...
            var latency:UInt = 0
            for i in 0..<sampleFilter.bufferSize {
                if (sampleFilter.getItemByAge(Int(i)) < triggerLevel) {
                    latency = i
                    break
                }
            }
            // auto-level adjustment for the next period ...
            if ( autoLevel ) {
                triggerLevel = autoLevelFilter.filter((super.periodMax + super.periodMin) / 2)
            }
            super.eventHappened(sample, triggerLatency: latency)
        } else {
            super.eventDidNotHappen(sample)
        }
        
        triggerState = nextState
    }
    
}

