//
//  USBScanner.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
//import IOKit

typealias USBDevice = (name:String, deviceFile:String)

class USBScanner {
    
    // MSP432P401R Launchpad vendor and product IDs
    let idVendor = 0x451
    let idProduct = 0xBEF3
    
    // better scan!  multi channel!
    func initialDeviceScan( ) throws -> [USBDevice] {
        
        // pretty much anything breaking in the initial device scan is classified AppFatal
        var returnVal:kern_return_t = kIOReturnSuccess
        
        let dictionary:NSMutableDictionary = IOServiceMatching( "IOUSBHostInterface" )
        dictionary.setValue(idVendor, forKey: "idVendor")
        dictionary.setValue(idProduct, forKey: "idProduct" )
        dictionary.setValue(1, forKey:"bConfigurationValue" )
        dictionary.setValue(1, forKey:"bInterfaceNumber")
//        print ("dictionary: \(dictionary)")
        
        // get an iterator to matches on the dictionary.  This should giv
        var iterator:io_iterator_t = 0
        returnVal = IOServiceGetMatchingServices( kIOMasterPortDefault, dictionary, &iterator )
        guard returnVal == kIOReturnSuccess else {
            throw Error.AppFatal("USBScanner: IOServiceGetMatchingServices() error")
        }
        
        var deviceArray:[USBDevice] = []
        // go through the really ugly IORegistry tree
        while ( true ) {
            let usbObject = IOIteratorNext( iterator )
            if (usbObject == 0) {
                // we're at the end of the dictionary matches.
                break
            }
            
            // get this interface's product name.  it's a part of the USBDevice type.  maybe we'll care about that someday.
            let productName = (IORegistryEntryCreateCFProperty(usbObject, "Product Name", kCFAllocatorDefault, 0)).takeUnretainedValue() as! String

            // get an iterator to this interface's subdevices
            var subIterator:io_iterator_t = 0
            returnVal = IORegistryEntryCreateIterator( usbObject, kIOServicePlane, UInt32(kIORegistryIterateRecursively), &subIterator)
            guard returnVal == kIOReturnSuccess else {
                throw Error.AppFatal("USBScanner.initalDeviceScan: found a device but couldn't get iterator to subdevice. (IORegistryEntryCreateIterator returned error)")
            }
            
            // go through this interface's subdevices, looking for the IOSerialBSDClient (modem device), and adding them to deviceArray.
            while (true ) {
                let subObject = IOIteratorNext(subIterator)
                if (subObject == 0) {
                    break;
                }
                let nameUnsafe = UnsafeMutablePointer<io_name_t>.alloc(1)
                returnVal = IORegistryEntryGetName(subObject, UnsafeMutablePointer(nameUnsafe))
                guard returnVal == kIOReturnSuccess else {
                    throw Error.AppFatal("USBScanner.initialDeviceScan: IORegistryEntryGetName returned an error")
                }
                let nameString = String.fromCString(UnsafePointer(nameUnsafe))
                nameUnsafe.dealloc(1)
//                print("---\(nameString!)")
                if ( nameString == "IOSerialBSDClient" ) {
                    let calloutDevice = (IORegistryEntryCreateCFProperty( subObject, kIOCalloutDeviceKey, kCFAllocatorDefault, 0).takeUnretainedValue()) as! String
//                    print ("------\(calloutDevice)")
                    deviceArray.append( (name: productName, deviceFile: calloutDevice) )
                }
            }
        }
        return deviceArray
    }
    
    init() {
    }
}



