#ifndef PERIODIC_SEND_TEST_H
#define PERIODIC_SEND_TEST_H

/*
 * this module uses timer A1 to send 16bit values across the UART at 10 Hz.
 */

void InitializePST( );
void StartPST( );
void StopPST( );

#endif
