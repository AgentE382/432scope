#ifndef UART_H
#define UART_H

void InitializeUart( );

// warning: this DOES NOT CHECK for overflowing the send buffer!!!
// add that soon!
inline void UartSendData( unsigned char* data, unsigned char length );

inline void UartSend16Little( unsigned short data );
inline void UartSend8Aligned16( unsigned char data );

inline void UartSendString( unsigned char* string ); // NULL TERMINATE!

#endif
