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
    
    // scan the USB bus for MSP432s.  returns an array of tuples, each containing
    // a rx device filename and a tx device filename.
    func scanForDevices( ) throws -> [USBDevice] {
        
        /*
         here's what this does:
         1) get a dictionary of potential devices
         2) get an iterator that will iterate through those devices
         3) go through the iterator.
         
        */
        
        // 1) get matching dictionary
        // this used to be kIOSerialBSDServiceValue
        let dictionary:NSMutableDictionary = IOServiceMatching( kIOSerialBSDServiceValue )
        if ( dictionary.count == 0 ) {
            throw USBScannerError.ScanFailed(msg: "Couldn't get matching dictionary." )
        }
        
        // refine that dictionary to only match usbmodems.
        dictionary.setValue( "usbmodem", forKey: kIOTTYBaseNameKey )
        // refine further to only match usbmodem number 1.
        dictionary.setValue( CONFIG_SINGLECHANNEL_DEVICE, forKey: kIOTTYSuffixKey )
        
        // 2) get iterator
        let kReturnSuccess:kern_return_t = 0
        var kReturn:kern_return_t = kReturnSuccess
        var iterator:io_iterator_t = 0
        kReturn = IOServiceGetMatchingServices( kIOMasterPortDefault, dictionary, &iterator )
        if ( kReturn != kReturnSuccess ) {
            throw USBScannerError.ScanFailed( msg:"IOServiceGetMatchingServices() error.")
        }
        
        // 3) go through the iterator, extracting information, and putting it into the array.
        var usbDevices:[USBDevice] = []
        while ( true ) {
            var object:io_object_t = 0
            object = IOIteratorNext( iterator )
            if ( object == 0 ) {
                break
            }
            let deviceName:String = (IORegistryEntryCreateCFProperty( object, kIOTTYDeviceKey, kCFAllocatorDefault, 0).takeUnretainedValue()) as! String
            let deviceCallout:String = (IORegistryEntryCreateCFProperty( object, kIOCalloutDeviceKey, kCFAllocatorDefault, 0).takeUnretainedValue()) as! String
            usbDevices.append( (name: deviceName, deviceFile: deviceCallout) )
        }
        
        // Final error condition.  Caller figures this one out.
        if ( usbDevices.count == 0 ) {
            return []
        }
        
        // No error.  Report!
        print( "Found the following USB serial devices:" )
        for device in usbDevices {
            print( "\(device)" )
        }
        
        return usbDevices

    }
    
    init() {
        
    }
}