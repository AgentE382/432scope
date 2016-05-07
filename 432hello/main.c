#include "msp.h"
#include "led.h"
#include "pushbutton.h"
#include "uart.h"
#include "periodic_send_test.h"
#include "adc14.h"

/*
 * This project is for testing code that leads to an oscilloscope.
 *
 * WHAT IT DOES:
 * -10 kHz sample rate.
 * -3 Mbps UART.
 *
 * PST monitor:
 * -LED1 indicates active Periodic Send Test.
 *
 * ADC monitor:
 * -LEDB indicates active single-channel-repeat mode.
 *
 * UART monitor:
 * -while transmitting, LED2R indicates RX, LED2G indicates TX
 *
 *
 * WHAT IT USES:
 *
 * DCOCLK = 48 MHz = MCLK
 * SMCLK = /4 = 12 MHz
 * HSMCLK = /2 = 24 MHz
 * Pushbutton ports p1.1 and p1.4 are taken.
 * TimerA0 is taken by the pushbuttons for debounce.
 * TimerA1 controls the periodic send test
 * TimerA2 triggers the ADC
 *
 */

void InitializeAllPorts( );
void InitializeSubClocks( );

void main(void)
{
    WDTCTL = WDTPW | WDTHOLD;           // Stop watchdog timer

    SystemInit( );
    SystemCoreClockUpdate( );
    InitializeSubClocks( );
    InitializeAllPorts( );
    InitializeLEDs( );
    InitializeButtons( );
    InitializeUart( );
 //   InitializePST( );
    InitializeADC( );
    __enable_interrupt();

    while(1){}
}

void InitializeAllPorts( )
{
	// set all ports to output and low.
	P1->DIR = 0xFF;
	P1->OUT = 0x00;
	P2->DIR = 0xFF;
	P2->OUT = 0x00;
	P3->DIR = 0xFF;
	P3->OUT = 0x00;
	P4->DIR = 0xFF;
	P4->OUT = 0x00;
	P5->DIR = 0xFF;
	P5->OUT = 0x00;
	P6->DIR = 0xFF;
	P6->OUT = 0x00;
	P7->DIR = 0xFF;
	P7->OUT = 0x00;
	P8->DIR = 0xFF;
	P8->OUT = 0x00;
	P9->DIR = 0xFF;
	P9->OUT = 0x00;
	P10->DIR = 0xFF;
	P10->OUT = 0x00;
}

void InitializeSubClocks( )
{
	CS->KEY = CS_KEY_VAL;
	// zero out the critical stuff, then set up SMCLK and ACLK.
	CS->CTL1 &= ~( CS_CTL1_SELS_MASK + CS_CTL1_DIVS_MASK
			+ CS_CTL1_SELA_MASK + CS_CTL1_DIVA_MASK
			+ CS_CTL1_DIVHS_MASK );
	CS->CTL1 |= CS_CTL1_SELS__DCOCLK; // source for {H,}SMCLK is DCO, this was default already
	CS->CTL1 |= CS_CTL1_DIVS__4;
//	CS->CTL1 |= CS_CTL1_SELA__VLOCLK; // set up ACLK on ~9.4 kHz VLOCLK
//	CS->CTL1 |= CS_CTL1_DIVA__1;
	CS->CTL1 |= CS_CTL1_DIVHS__2; // this should be 24 MHz
	CS->KEY = 0;
}
