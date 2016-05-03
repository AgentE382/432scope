#include <msp.h>
#include "uart.h"
#include "led.h"
#include "periodic_send_test.h"

// 256 so that the indexes will roll over properly.
// from their point of view, this is circular.
unsigned char uartTxBuffer[256];
unsigned char uartTxQueueIndex = 0;
unsigned char uartTxSendIndex = 0;

void InitializeUart( )
{
	// zero out the buffer because ... i'm not really sure why.  shouldn't matter.
	unsigned int i;
	for ( i=0; i<256; i++ ) {
		uartTxBuffer[i] = 0;
	}

	// RX: P1.2		TX: P1.3
	// give eUSCI_A0 control of the rx and tx ports
	P1->SEL1 &= ~(BIT2 + BIT3);
	P1->SEL0 |= (BIT2 + BIT3);

	// reset
	EUSCI_A0->CTLW0 = EUSCI_A_CTLW0_SWRST;

	// choose clock source
	EUSCI_A0->CTLW0 |= EUSCI_A_CTLW0_SSEL__SMCLK;

	// set baud rate. right now it's 460800
	EUSCI_A0->BRW = 1;									// BRx
	EUSCI_A0->MCTLW = (0x0 << EUSCI_A_MCTLW_BRS_OFS) | 	// BRSx
			(10 << EUSCI_A_MCTLW_BRF_OFS) | 				// BRFx
			(1 );										// S16

	// restart
	EUSCI_A0->CTLW0 &= ~EUSCI_A_CTLW0_SWRST;

	// receive interrupt enable.
	EUSCI_A0->IE |= EUSCI_A_IE_RXIE;

	// module interrupt enable in NVIC
	NVIC->ISER[0] |= ( 1 << EUSCIA0_IRQn );
}

inline void Uart_StartSend( )
{
	EUSCI_A0->IE |= EUSCI_A_IE_TXIE;
	EUSCI_A0->IFG |= EUSCI_A_IFG_TXIFG;
	TURN_ON_LEDG;
}

void UartSendData( unsigned char* data, unsigned char length )
{
	unsigned char i;
	for ( i=0; i<length; i++ ) {
		uartTxBuffer[uartTxQueueIndex] = data[i];
		uartTxQueueIndex++;
	}
	Uart_StartSend( );
}

void UartSend16Little( unsigned short data )
{
	// send 16 bits, LSByte first.
	uartTxBuffer[uartTxQueueIndex] = data & 0x00FF;
	uartTxQueueIndex++;
	uartTxBuffer[uartTxQueueIndex] = data >> 8;
	uartTxQueueIndex++;
	Uart_StartSend( );
}

void UartSend8Aligned16( unsigned char data )
{
	// send 8 bits, padded so the laptop will understand them on a 16-bit word boundary.
	uartTxBuffer[uartTxQueueIndex] = data;
	uartTxQueueIndex++;
	uartTxBuffer[uartTxQueueIndex] = 0;
	uartTxQueueIndex++;
	Uart_StartSend( );
}

#define UARTRX_START_TRANSMISSION 's'
#define UARTRX_STOP_TRANSMISSION 'p'

inline void Uart_ProcessReceivedByte( unsigned char incoming )
{
	switch ( incoming ) {
	case UARTRX_START_TRANSMISSION:
		StartPST( );
		break;
	case UARTRX_STOP_TRANSMISSION:
		StopPST( );
		break;
	default:break;
	}
}

void euscia0_ISR( )
{
	switch ( EUSCI_A0->IV ) {
	case 0:
		break;
	case 2: // RX
		TURN_ON_LEDR;
		Uart_ProcessReceivedByte( EUSCI_A0->RXBUF );
		TURN_OFF_LEDR;
		break;
	case 4: // TX
		// if this is the end, shut down the interrupt and bail.
		if ( uartTxSendIndex == uartTxQueueIndex ) {
			EUSCI_A0->IE &= ~EUSCI_A_IE_TXIE;
			TURN_OFF_LEDG;
			break;
		}
		EUSCI_A0->TXBUF = ( EUSCI_A_TXBUF_TXBUF_MASK & uartTxBuffer[uartTxSendIndex] );
		uartTxSendIndex++;
		break;
	default:
		break;
	}
}

/*


void UartSendByte( unsigned char byte )
{
	uartTxBuffer[0] = byte;
	uartTxBuffer[1] = '\0';
	Uart_StartSend( );
}

void UartSend16( unsigned short data )
{
	// intel macs expect LSByte first!!!!
	uartTxBuffer[0] = ( data & 0x00FF );
	uartTxBuffer[1] = data >> 8;
	uartTxBuffer[2] = '\0';
	Uart_StartSend( );
}

void UartSendData( unsigned char* data )
{
	// copy the data into our local place ...
	unsigned char counter = 0;
	while ( data[counter] != '\0' ) {
		uartTxBuffer[counter] = data[counter];
		counter++;
	}
	uartTxBuffer[counter] = '\0';

	// set the buffer index to 0 and enable the transmitter interrupt.
	Uart_StartSend( );
}

*/
