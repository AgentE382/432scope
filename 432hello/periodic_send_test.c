#include <msp.h>
#include "led.h"
#include "uart.h"
#include "periodic_send_test.h"

#include "sinewave.h"

unsigned char sineWaveIndex = 0;

void InitializePST( )
{
	// This assumes 12 MHz SMCLK.
	// Baud is set to 3 Mbps
	// Transmits at 10 kHz

	// Stop
	TIMER_A1->CTL = TIMER_A_CTL_MC_0;

	// Set source, divider, and clear
	TIMER_A1->CTL = TIMER_A_CTL_SSEL__SMCLK | // SMCLK = 12 MHz
			TIMER_A_CTL_ID__8;
	TIMER_A1->EX0 &= ~( TIMER_A_EX0_IDEX_MASK ); // clear the extended divider
	//TIMER_A1->EX0 |= TIMER_A_EX0_TAIDEX_7; // extended divide-by-8
	TIMER_A1->CTL |= TIMER_A_CTL_CLR;
	TIMER_A1->CCR[0] = 150;

	// enable TA0 module interrupts in NVIC
	NVIC->ISER[0] = 1 << ((TA1_0_IRQn) & 31);

	// Start in UP mode.
	TIMER_A1->CTL |= TIMER_A_CTL_MC__UP;
}

void StartPST( )
{
	// interrupt enable
	TIMER_A1->CCTL[0] &= ~TIMER_A_CCTLN_CCIFG;
	TIMER_A1->CCTL[0] |= TIMER_A_CCTLN_CCIE;
	TURN_ON_LED1;
}

void StopPST( )
{
	// interrupt disable
	TIMER_A1->CCTL[0] &= ~TIMER_A_CCTLN_CCIE;
	TURN_OFF_LED1;
}

void ta1ccr0_ISR( )
{
	// clear the interrupt flag
	TIMER_A1->CCTL[0] &= ~TIMER_A_CCTLN_CCIFG;

	// send some sample data across the UART for the mac app to interpret.
	UartSend16Little( gSineWave[sineWaveIndex] << 6 );
	sineWaveIndex+=2;
	if ( sineWaveIndex >= 100 ) {
		sineWaveIndex = 0;
	}

//	UartSendData("NDC\n", 4);
}

