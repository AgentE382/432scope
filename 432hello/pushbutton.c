#include <msp.h>
#include "pushbutton.h"
#include "led.h"
#include "debounce.h"
#include "uart.h"
#include "periodic_send_test.h"

// button debouncer structs
SwitchDebouncer button1Debouncer;
SwitchDebouncer button2Debouncer;

// convenience
#define ENABLE_TIMER_A_INTERRUPT 	TIMER_A0->CCTL[0] &= ~TIMER_A_CCTLN_CCIFG; TIMER_A0->CCTL[0] |= TIMER_A_CCTLN_CCIE
#define DISABLE_TIMER_A_INTERRUPT	TIMER_A0->CCTL[0] &= ~TIMER_A_CCTLN_CCIE

// forward declarations
void InitializeTimerA0( );

// These get called when something happens to the button.
void Button1Pressed( )
{
	// the button is down, so tell the port to watch for a low-to-high.
	P1->IES &= ~BUTTON1_BIT;

	/*
	 *  NOW do whatever it is button 1 presses should do.
	 */
}

void Button1Released( )
{
	// the button is up so tell P1 to look for a high-to-low.
	P1->IES |= BUTTON1_BIT;

	/*
	 * do whatever button1releases do.
	 */
}

void Button2Pressed( )
{
	// the button is LOW so now we need to watch for a low-to-high.
	P1->IES &= ~BUTTON2_BIT;

	/*
	 * do whatever button2presses do.
	 */

	StartPST( );
}

void Button2Released( )
{
	// the button is HIGH so we need to watch for a high-to-low.
	P1->IES |= BUTTON2_BIT;

	/*
	 * do whatever button2releases do.
	 */
	StopPST( );
}

void InitializeButtons( )
{
	// get both button bits in one place.
	unsigned char bit = BUTTON1_BIT + BUTTON2_BIT;

	// get the debounce timer rolling.
	InitializeTimerA0( );

	/* Debounce FSM setup.
	 *
	 * { port, bit, activeLevel, activateBounceTime, deactivateBounceTime,
	 * debounceState, currentValidOutput, activateCallback, deactivateCallback,
	 * validationCounter }
	 */
	button1Debouncer = (SwitchDebouncer) {
		(uint8_t*) &(P1->IN), BUTTON1_BIT, Low, BUTTON_PRESS_BOUNCE_TIME, BUTTON_RELEASE_BOUNCE_TIME,
		ExpectHigh, Low, Button1Pressed, Button1Released,
		0
	};
	button2Debouncer = (SwitchDebouncer) {
		(uint8_t*) &(P1->IN), BUTTON2_BIT, Low, BUTTON_PRESS_BOUNCE_TIME, BUTTON_RELEASE_BOUNCE_TIME,
		ExpectHigh, Low, Button2Pressed, Button2Released,
		0
	};

	// set pin to input
	P1->DIR &= ~bit;

	// enable resistor
	P1->REN |= bit;

	// set resistor to pull-up
	P1->OUT |= bit;

	// edge-select: high-to-low
	P1->IES |= bit;

	// clear and enable the port interrupt
	P1->IFG &= ~bit;
	P1->IE |= bit;

	// module-level interrupt enable in NVIC for Port 1
	// PORT1_IRQn = 35 so this goes in NVIC->ISER[1]
	NVIC->ISER[1] |= 1 << (PORT1_IRQn - 32);
}

void InitializeTimerA0( )
{
	// This is a 1ms timer for debouncing.
	// it assumes 12 MHz SMCLK.

	// Stop
	TIMER_A0->CTL = TIMER_A_CTL_MC_0;

	// Set source, divider, and clear
	TIMER_A0->CTL = TIMER_A_CTL_SSEL__SMCLK |
			TIMER_A_CTL_ID__1;
	TIMER_A0->EX0 &= ~( TIMER_A_EX0_IDEX_MASK );
	TIMER_A0->CTL |= TIMER_A_CTL_CLR;

	// Set CCR0 and interrupt enable
//	TIMER_A0->CCTL[0] &= ~TIMER_A_CCTLN_CCIFG;
//	TIMER_A0->CCTL[0] |= TIMER_A_CCTLN_CCIE;
	TIMER_A0->CCR[0] = 12000;

	// enable TA0 module interrupts in NVIC
	NVIC->ISER[0] = 1 << ((TA0_0_IRQn) & 31);

	// Start in UP mode.
	TIMER_A0->CTL |= TIMER_A_CTL_MC__UP;
}

void port1_ISR( )
{
	switch ( P1->IV ) {
	case 0: // nothing pending
		break;
	case 2: // P1.0
		break;
	case 4: // P1.1, button 1
		if ( button1Debouncer.debounceState == ExpectHigh ) {
			// this means we got a possible press, we need to go to ValidateHigh, set the timer...
			button1Debouncer.debounceState = ValidateHigh;
			button1Debouncer.validationCounter = button1Debouncer.activateBounceTime;
			// turn on Timer A so debounce will get called.
			ENABLE_TIMER_A_INTERRUPT;
			break;
		}
		if ( button1Debouncer.debounceState == ExpectLow ) {
			// this means we got a possible release. go to validatelow, set the timer
			button1Debouncer.debounceState = ValidateLow;
			button1Debouncer.validationCounter = button1Debouncer.deactivateBounceTime;
			// turn on Timer A
			ENABLE_TIMER_A_INTERRUPT;
			break;
		}
		break;
	case 6: // P1.2
		break;
	case 8: // P1.3
		break;
	case 10: // P1.4 button 2
		if ( button2Debouncer.debounceState == ExpectHigh ) {
			// this means we got a possible press, we need to go to ValidateHigh, set the timer...
			button2Debouncer.debounceState = ValidateHigh;
			button2Debouncer.validationCounter = button2Debouncer.activateBounceTime;
			// turn on Timer A so debounce will get called.
			ENABLE_TIMER_A_INTERRUPT;
			break;
		}
		if ( button2Debouncer.debounceState == ExpectLow ) {
			// this means we got a possible release. go to validatelow, set the timer
			button2Debouncer.debounceState = ValidateLow;
			button2Debouncer.validationCounter = button2Debouncer.deactivateBounceTime;
			// turn on Timer A
			ENABLE_TIMER_A_INTERRUPT;
			break;
		}
		break;
	case 12: // P1.5
		break;
	case 14: // P1.6
		break;
	case 16: // P1.7
		break;
	default: break;
	}
}

void ta0ccr0_ISR( )
{
	// clear the interrupt flag
	TIMER_A0->CCTL[0] &= ~TIMER_A_CCTLN_CCIFG;

	// call debounce on any buttons in a validate state
	if ( (button1Debouncer.debounceState == ValidateHigh) ||
			(button1Debouncer.debounceState == ValidateLow ) ) {
		Debounce( &button1Debouncer );
	}
	if ( (button2Debouncer.debounceState == ValidateHigh) ||
			(button2Debouncer.debounceState == ValidateLow ) ) {
		Debounce( &button2Debouncer );
	}

	// now if NEITHER button is in a validate state, we can deactivate
	// the timer A interrupt.
	volatile DebounceState b1DS, b2DS;
	b1DS = button1Debouncer.debounceState;
	b2DS = button2Debouncer.debounceState;
	if ( (b1DS != ValidateHigh) &&
			(b1DS != ValidateLow) &&
			(b2DS != ValidateHigh) &&
			(b2DS != ValidateLow) )
	{
		DISABLE_TIMER_A_INTERRUPT;
	}
}
