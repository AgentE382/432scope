//
//  AppDelegate.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var mvc:MainViewController? = nil
    
    let scanner = USBScanner()
    var channels:[Channel] = []

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        print("----applicationDidFinishLaunching" )
        
        
        // print constants for diag:
/*        print("--UI")
        print("display frame rate: \(CONFIG_DISPLAY_REFRESH_RATE)")
        print("--TRANSCEIVER")
        print("incoming sample rate: \(CONFIG_SINGLECHANNEL_SAMPLERATE) Hz")
        print("incoming data rate: \(CONFIG_INCOMING_DATA_BYTES_PER_SECOND) Bps")
        print("bytes per display frame: \(CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME)")
        print("decoder packet size: \(CONFIG_DECODER_PACKET_SIZE)")
        print("posix read length: \(CONFIG_POSIX_READ_LENGTH)")
 
        print("here we go...")*/
        
        
        // circular array test
/*        let length = 10
        let elementsToStore = 15
        var testArray = CircularArray<Int>(capacity:length, repeatedValue: -1)
        
        for i in 0...elementsToStore {
            testArray.storeNewEntry(i)
        }
        
        let sliceCount = 20
        let sliceLength = 15
        for i in 0..<sliceLength {
            print( "[\(testArray.getSubArray(0, last:i))" )
        }
        
        print(" test over. ")*/
        
        
        // load system colors to use as channel colors, removing black and white
        let appleColorList = NSColorList(named: "Apple")
        let scopeTraceColors = NSColorList(name: "Scope Trace Colors" )
        // remove black and white
        for color in appleColorList!.allKeys {
            if ( color == "Black" || color == "White" ) {
                continue
            }
            scopeTraceColors.insertColor((appleColorList?.colorWithKey(color))!, key: color, atIndex: 0)
        }
        let channelColorKeys = scopeTraceColors.allKeys
        let channelColorCount = channelColorKeys.count
        
        
        
        
        // idiot check, make sure a main view controller exists.
        if ( mvc == nil ) {
            print( "i have no mvc! EEEEEEK" )
            omgKillTheApp()
        }
    
        
        // the channel creation try-catch of doom
        do {
            
            let devices = try scanner.betterScan()
            // scan for USB devices ...
            if ( devices.count == 0 ) {
                print( "No devices found." )
                omgKillTheApp()
            }
            
            // pass those channels along to the view controllers.
            for i in 0..<devices.count {
                // try to open some channels ...
                let newChannel = try Channel(device: devices[i], sampleRateInHertz: CONFIG_SINGLECHANNEL_SAMPLERATE, bufferLengthInSeconds: CONFIG_BUFFER_LENGTH)
                
                channels.append(newChannel)
                channels[i].displayColor = scopeTraceColors.colorWithKey(channelColorKeys[i%channelColorCount])!
                mvc?.channelIsReady(channels[i])
            }
            
            
            
        } catch TransceiverError.OpenFailed( let msg ) {
            print( msg )
        } catch {
            print( "Something stupid happened.  Goodbye." )
        }
    }
    
    func omgKillTheApp() {
        NSApplication.sharedApplication().terminate(nil)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
        print("----applicationWillTerminate")
        do {
            for channel in channels {
                try channel.channelOff()
                try channel.transceiver!.closeTerminal()
            }
        } catch {
            print( "Something stupid happened.  Goodbye." )
        }
    }


}

