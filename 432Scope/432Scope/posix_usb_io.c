//
//  posix_usb_io.c
//  432scope
//
//  Created by Nicholas Cordle on 4/29/16.
//  Copyright © 2016 Nicholas Cordle. All rights reserved.
//

#include "posix_usb_io.h"

#include <fcntl.h>
#include <unistd.h>

#include <sys/ioctl.h>
#include <IOKit/serial/ioss.h> // for the non-trad baud rates

// AAAAH this is nasty but whatever.
int c_get_posix_file_descriptor( const char* filename ) {
    // don't need O_NONBLOCK because we're using /dev/cu.*
    return open( filename, O_RDWR | O_NOCTTY );//| O_NONBLOCK );
}

int c_close_posix_file_descriptor( int fd ) {
    return close( fd );
}

int c_ioctl_set_crazy_baud_rate( int fd ) {
    speed_t nonstandard_baud_rate = 3000000;
    return ioctl( fd, IOSSIOSPEED, &nonstandard_baud_rate );
}