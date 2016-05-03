#ifndef UART_H
#define UART_H

void InitializeUart( );

// warning: this DOES NOT CHECK for overflowing the send buffer!!!
// add that soon!
void UartSendData( unsigned char* data, unsigned char length );

void UartSend16Little( unsigned short data );
void UartSend8Aligned16( unsigned char data );

#endif
