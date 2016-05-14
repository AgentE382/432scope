//
//  Transceiver.swift
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

import Foundation

/*
 This is the first layer above the /dev/tty.* file.
 
 BIG PICTURE:
 
 -the receiver opens a terminal with a POSIX file descriptor, then turns it into NSFileHandle.
 -reads are triggered by setting up the file descriptor as a dispatch source using Grand Central Dispatch.
 -reads go into a local NSMutableData buffer.
 -when a full Decoder packet length has been read, it is sent to the decoder.
 
 -the transmitter sends one-byte commands.  They're in a dictionary in this file.
 
*/

/* dictionary of one-byte commands to send to the 432 over UART. */
let UART432Commands:[String:UInt8] = [
    "Start"     :       115,           // 's'
    "Stop"      :       112,           // 'p'
]

class Transceiver: NSObject, NSStreamDelegate {
    
    //
    // PROPERTIES
    //

    // Basic stuff: the decoder we send packets to, the file handle, the buffer...
    var decoder:Decoder? = nil
    private var fileHandle:NSFileHandle? = nil
    private var buffer:NSMutableData? = nil
    
    // POSIX I/O stuff
    private var fileDescriptor:Int32? = nil
    private var posixReadLength:UInt8 = CONFIG_POSIX_READ_LENGTH // aka VMIN from termios
    private var originalTermios:termios = termios()

    // Grand Central Dispatch queue for serial I/O
    private var gcdSerialQueue:dispatch_queue_t? = nil
    private var gcdDispatchSource:dispatch_source_t? = nil
    
    
    
    //
    // INIT AND STATUS
    //
    
    init( deviceFilePath:String, decoder:Decoder, posixReadLength prs:UInt8 = CONFIG_POSIX_READ_LENGTH ) throws {
        self.posixReadLength = prs
        self.decoder = decoder
        super.init()
        try self.openTerminal(deviceFilePath: deviceFilePath)
    }
    
    var isOpen:Bool {
            // file handle is the last thing set in openTerminal so this is based on that.
            if ( fileHandle == nil ) {
                return false
            }
            return true
    }

    //
    // INTERNALS
    //
    // openTerminal
    // closeTerminal
    // send
    // flush
    //
    
    func openTerminal( deviceFilePath aPath: String ) throws {
        
        // errors in opening the terminal mean the channel isn't working, so errors here are thrown as ChannelFatal.
        
        // idiot check: is the terminal already open? do we have a decoder?
        if ( isOpen ) {
            throw Error.ChannelFatal("Terminal is already open." )
        }
        if ( decoder == nil ) {
            throw Error.ChannelFatal("No decoder object attached." )
        }
        
        // get a posix style file descriptor ...
        fileDescriptor = c_get_posix_file_descriptor( aPath )
        if ( fileDescriptor == -1 ) {
            fileDescriptor = nil
            throw Error.ChannelFatal("open() error \(errno): \(strerror(errno))")
        }
        
        // clear the NONBLOCK flag. reads will happen in their own thread (dispatch queue) so
        // in fact they -should- block it.
        if ( fcntl( fileDescriptor!, F_SETFL, 0 ) == -1 ) {
            throw Error.ChannelFatal("fcntl() error \(errno): \(strerror(errno))" )
        }
        
        // stash the terminal's original configuration
        if ( tcgetattr( fileDescriptor!, &originalTermios ) == -1 ) {
            throw Error.ChannelFatal("tcgetattr() error \(errno): \(strerror(errno))")
        }
        
        // change a few terminal options
        var newTermios = termios()
        cfmakeraw( &newTermios )
        newTermios.c_cflag =  tcflag_t( CS8 | CREAD | CLOCAL )
        newTermios.c_cc.16 = posixReadLength // VMIN
        newTermios.c_cc.17 = 0 // VTIME
        newTermios.c_ispeed = 300 // gonna override this anyway with IOCTL
        newTermios.c_ospeed = 300
        if ( tcsetattr( fileDescriptor!, TCSANOW, &newTermios ) == -1 ) {
            throw Error.ChannelFatal("tcsetattr() error \(errno): \(strerror(errno))")
        }
        
        // attempting the crazy ioctl call ...
        if ( c_ioctl_set_crazy_baud_rate( fileDescriptor! ) == -1 ) {
            throw Error.ChannelFatal("ioctl() error while setting baud rate\(errno)")
        }
        
        // re-read termios and print out a few things.
        tcgetattr( fileDescriptor!, &newTermios )
/*        print( "Terminal is open on \(aPath)" )
        print( "ispeed: \(cfgetispeed(&newTermios))" )
        print( "ospeed: \(cfgetospeed(&newTermios))" )*/
        
        // create a serial dispatch queue
        gcdSerialQueue = dispatch_queue_create( "serialReadQueue\(aPath)", DISPATCH_QUEUE_SERIAL )
        
        // register this file descriptor as a dispatch source
        gcdDispatchSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, UInt(fileDescriptor!), 0, gcdSerialQueue )
        
        // set up an event handler for our file's dispatch source
        dispatch_source_set_event_handler( gcdDispatchSource!, {
            
            // BEGIN POSIX READ HANDLER
            
            // HOW THIS WORKS:
            // 1) Get the incoming data
            // 2) append it to our mutable buffer
            // 3) packetizer (while true)
            //      -) if buffer size is less than packet size, break.
            //      -) it wasn't, so there's at least one complete packet here.
            //      -) range out the complete packet, send it
            //      -) range out the rest, that is now the buffer.
            // 4) print diag.
            
            // 1-2) Get the incoming, append it to the buffer.
            // (this means create the buffer if it's not there yet.)
            if ( self.buffer == nil ) {
                self.buffer = NSMutableData(data: self.fileHandle!.availableData)
            } else {
                self.buffer!.appendData(self.fileHandle!.availableData)
            }
            
            // 3) The Packetizer!
            var shippedSize:Int = 0
            let packetSize = self.decoder!.packetSize
            while (true) {
                if ( self.buffer!.length < packetSize ) {
                    // we don't yet have a complete packet.
                    break;
                }
                // we have (at least) a complete packet, so ship that off to the decoder.
                let packetRange = NSRange(location: 0, length: packetSize!)
                let nsdPacket = self.buffer!.subdataWithRange( packetRange )
                self.decoder!.newPacketArrived( nsdPacket )
                // add that to the shippedSize count.
                shippedSize += packetSize!
                
                // get the remaining range, make that the new buffer.
                let originalBufferLength = self.buffer!.length
                let newBuffer = self.buffer!.subdataWithRange( NSRange(location: packetSize!, length: originalBufferLength-packetSize!))
                self.buffer = NSMutableData(data:newBuffer)
            }
            
            // 4) diagnostics ...
//            print( "Read: \(dispatch_source_get_data(self.gcdDispatchSource!))\t\t\tShipped: \(shippedSize)\t\tIn Buffer: \(self.buffer!.length)")
            
            // END POSIX READ HANDLER
        })
        
        // get a file handle
        fileHandle = NSFileHandle(fileDescriptor: fileDescriptor!)
        if ( fileHandle == nil ) {
            throw Error.ChannelFatal("Couldn't create NSFileHandle.")
        }
        
        flush()
        
        // Source suspension count is 1 on create, so we must "resume" this source.
        dispatch_resume( gcdDispatchSource! )

    }
    
    func send( nameOfCommandToSend:String ) throws {
        /* failure conditions:
            -terminal isn't open
            -command isn't in the dictionary
            -write says something weird happened
         */
        if ( isOpen == false ) {
            throw Error.ChannelFatal( "Terminal isn't open." );
        }
        var cmdByte:UInt8? = UART432Commands[nameOfCommandToSend]
        if ( cmdByte == nil ) {
            throw Error.ChannelFatal( "Unknown command." )
        }
        // schedule the write on the queue
        dispatch_async(gcdSerialQueue!, {
            let result = write( self.fileDescriptor!, &cmdByte, 1 )
            if ( result == -1 ) {
                print("write() error: \(errno) - \(String.fromCString(strerror(errno))))")
                return
            }
            if ( result != 1 ) {
                print("write() reported incorrect number of bytes sent: \(result)" )
            }
        })
    }
    
    func flush( ) {
        dispatch_sync(gcdSerialQueue!, {
            tcflush( self.fileDescriptor!, TCIOFLUSH )
            self.buffer = nil
        })
    }
    
    func closeTerminal( ) throws {
        if ( isOpen == false ) {
            throw Error.ChannelFatal("This receiver wasn't open." )
        }
        
        // kill the dispatch source.  the queue is suspended automatically as of 10.8
        dispatch_source_cancel( gcdDispatchSource! )
        gcdDispatchSource = nil
        gcdSerialQueue = nil
        
        // reset termios
        if ( tcsetattr( fileDescriptor!, TCSANOW, &originalTermios ) == -1 ) {
            throw Error.ChannelFatal("tcsetattr() error \(errno): \(strerror(errno))")
        }
        
        // kill the file descriptor
        if ( c_close_posix_file_descriptor( fileDescriptor! ) == -1 ) {
            throw Error.ChannelFatal("close() error \(errno): \(String(strerror(errno)))")
        }
        
        fileDescriptor = nil
        fileHandle = nil
        
        print( "Receiver closed." )
 
    }
}


