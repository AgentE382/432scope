//
//  USBScanner.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation
//import IOKit

enum USBScannerError: ErrorType {
    case ScanFailed( msg:String )
}

typealias USBDevice = (name:String, deviceFile:String)

class USBScanner {
    
    // better scan!  multi channel!
    func betterScan( ) throws -> [USBDevice] {
        
        // MSP432P401R Launchpad vendor and product IDs
        let idVendor = 0x451
        let idProduct = 0xBEF3
        
        let dictionary:NSMutableDictionary = IOServiceMatching( "IOUSBHostInterface" )
        dictionary.setValue(idVendor, forKey: "idVendor")
        dictionary.setValue(idProduct, forKey: "idProduct" )
        dictionary.setValue(1, forKey:"bConfigurationValue" )
        dictionary.setValue(1, forKey:"bInterfaceNumber")
        print ("dictionary: \(dictionary)")
        
        var iterator:io_iterator_t = 0
        IOServiceGetMatchingServices( kIOMasterPortDefault, dictionary, &iterator )
        print("iterator: \(iterator)")
        
        var deviceArray:[USBDevice] = []
        
        while ( true ) {
            let usbObject = IOIteratorNext( iterator )
            if ( usbObject == 0 ) {
                break
            }
            
            let productName = (IORegistryEntryCreateCFProperty(usbObject, "Product Name", kCFAllocatorDefault, 0)).takeUnretainedValue() as! String
            print("object=\(usbObject)\t\t\(productName)")

            var subIterator:io_iterator_t = 0
            
            IORegistryEntryCreateIterator( usbObject, kIOServicePlane, UInt32(kIORegistryIterateRecursively), &subIterator)
            
            while (true ) {
                let subObject = IOIteratorNext(subIterator)
                if ( subObject == 0 ) {
                    break;
                }
                let nameUnsafe = UnsafeMutablePointer<io_name_t>.alloc(1)
                IORegistryEntryGetName(subObject, UnsafeMutablePointer(nameUnsafe))
                let nameString = String.fromCString(UnsafePointer(nameUnsafe))
                nameUnsafe.dealloc(1)
                print("---\(nameString!)")
                if ( nameString == "IOSerialBSDClient" ) {
                    let calloutDevice = (IORegistryEntryCreateCFProperty( subObject, kIOCalloutDeviceKey, kCFAllocatorDefault, 0).takeUnretainedValue()) as! String
                    print ("------\(calloutDevice)")
                    deviceArray.append( (name: productName, deviceFile: calloutDevice) )
                }
            }
        }
        
        print( deviceArray )
        
        return deviceArray
    }
    
    init() {
    }
}