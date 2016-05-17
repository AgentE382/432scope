//
//  posix_usb_io.h
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

#ifndef posix_usb_io_h
#define posix_usb_io_h

#include <stdio.h>
#include <sys/param.h>

#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/usb/USBSpec.h>


#include <IOKit/serial/IOSerialKeys.h>
#include <CoreFoundation/CFDictionary.h>

// swift apparently can't do these yet, so we have to do them here in C.
int c_get_posix_file_descriptor( const char* filename );
int c_close_posix_file_descriptor( int fd );
int c_ioctl_set_crazy_baud_rate( int fd );
 
#endif /* posix_usb_io_h */
