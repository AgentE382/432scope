//
//  AppDelegate.swift
//  432Scope
//
//  Created by Nicholas Cordle on 5/2/16.
//
//

import Cocoa

enum Error:ErrorType {
    case AppFatal(String)
    case ChannelFatal(String)
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    // use this object to pass channels along to the UI as they come online
    var mvc:MainViewController? = nil
    
    // keep a scanner object here, in anticipation of hotplug
    let scanner = USBScanner()
    
    // keep successfully init-ed channels here so we can shut them down on a terminate notification.
    var channels:[Channel] = []

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        print("----applicationDidFinishLaunching" )
        
        // print constants for diag:
        print("--CONSTANTS:::")
        print("\tdisplay frame rate: \(CONFIG_DISPLAY_REFRESH_RATE)")
        print("\tincoming sample rate: \(CONFIG_SAMPLERATE) Hz")
        print("\tincoming data rate: \(CONFIG_INCOMING_BYTES_PER_SECOND) Bps")
        print("\tbytes per display frame: \(CONFIG_INCOMING_BYTES_PER_DISPLAY_FRAME)")
        print("\tdecoder packet size: \(CONFIG_DECODER_PACKET_SIZE)")
        print("\tposix read length: \(CONFIG_POSIX_READ_LENGTH)")
        
        // idiot check, make sure a main view controller exists.
        guard mvc != nil else {
            print( "i have no mvc! EEEEEEK" )
            omgKillTheApp()
            return
        }

        // the channel creation try-catch of doom
        do {
            let devices = try scanner.initialDeviceScan()
            print("--DEVICES:::\n\(devices)")
        
            // open channels and pass them to the main view controller
            for i in 0..<devices.count {
                // open a channel for each device.
                do {
                    let newChannel = try Channel(device: devices[i], sampleRateInHertz: CONFIG_SAMPLERATE, bufferLengthInSeconds: CONFIG_BUFFER_LENGTH)
                    try mvc?.loadChannel(newChannel)
                    channels.append(newChannel)
                }
                catch Error.ChannelFatal(let msg) {
                    print("!!! ChannelFatal: \(msg)")
                }
            }

        } catch Error.AppFatal( let msg ) {
            print( "!!! AppFatal: \(msg)")
            omgKillTheApp()
        } catch {
            print( "Something stupid happened.  An unknown error got thrown.  Goodbye." )
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
        print("----applicationWillTerminate ended.")
    }
}

