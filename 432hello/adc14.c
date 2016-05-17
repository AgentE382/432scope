#include <msp.h>
#include "adc14.h"
#include "led.h"
#include "uart.h"

// SMCLK = 12 MHz, no divider.
// some sampling rates:
// 1200 = 10 kHz
// 240 = 50 kHz
// 120 = 100 kHz and that is ~2/3 UART saturation.

#define ADC14_TRIGGER_PERIOD 120
#define ADC14_TRIGGER_RETURN 60



void ADC_InitializeTimerA2( )
{
	// Stop
	TIMER_A2->CTL = TIMER_A_CTL_MC_0;

	// Set source, divider, and clear
	TIMER_A2->CTL |= TIMER_A_CTL_SSEL__SMCLK; // SMCLK = 12 MHz
	TIMER_A2->CTL &= ~( TIMER_A_CTL_ID_MASK );
	TIMER_A2->EX0 &= ~( TIMER_A_EX0_IDEX_MASK ); // clear the extended divider
	// TIMER_A1->EX0 |= TIMER_A_EX0_TAIDEX_7; // extended divider
	TIMER_A2->CTL |= TIMER_A_CTL_CLR;

	TIMER_A2->CCTL[1] |= TIMER_A_CCTLN_OUT;
	TIMER_A2->CCTL[1] |= TIMER_A_CCTLN_OUTMOD_7;

	// the sample rate
	TIMER_A2->CCR[0] = ADC14_TRIGGER_PERIOD;
	// bring the trigger back after this long
	TIMER_A2->CCR[1] = ADC14_TRIGGER_RETURN;

	// we don't want any timer interrupts but if we ever do, here they are:
	// NVIC->ISER[0] = 1 << ((TA2_0_IRQn) & 31);
}

void InitializeADC( )
{
	// set up a timer to trigger the sampling
	ADC_InitializeTimerA2( );

	// turn ENC off so we can modify the registers
	ADC14->CTL0 &= ~ADC14_CTL0_ENC;

	//
	// CTL0 STUFF
	//

	// ADC clock source: HSMCLK @ 24 MHz, no dividers.
	ADC14->CTL0 |= ADC14_CTL0_SSEL__HSMCLK;
	ADC14->CTL0 &= ~ADC14_CTL0_PDIV_MASK;
	ADC14->CTL0 &= ~ADC14_CTL0_DIV_MASK;

	// trigger select: TimerA2
	ADC14->CTL0 |= ADC14_CTL0_SHS_5;

	// pulse mode! ADC will push the sample to MEM0 as soon as its ready, not waiting for the trigger to drop.
	ADC14->CTL0 |= ADC14_CTL0_SHP;

	// multiple-sample-mode. off for now.  we want the ADC to wait for the next trigger.
	ADC14->CTL0 &= ~ADC14_CTL0_MSC;

	// sample-and-hold time for inputs including 15
	ADC14->CTL0 |= ADC14_CTL0_SHT1__32;

	// repeat-single-channel-mode
	ADC14->CTL0 |= ADC14_CTL0_CONSEQ_2;

	//
	// CTL1 STUFF
	//

	// resolution: 14 bit
	ADC14->CTL1 |= ADC14_CTL1_RES__14BIT;

	// df: off.
	ADC14->CTL1 &= ~ADC14_CTL1_DF;

	// REFBURST: off.  keep the power on.
	ADC14->CTL1 &= ~ADC14_CTL1_REFBURST;

	// PWRMOD: power mode should be 00 = normal
	ADC14->CTL1 &= ~ADC14_CTL1_PWRMD_MASK;

	//
	// MCTL STUFF
	//
	// input select: channel A15
	ADC14->MCTL[0] |= ADC14_MCTLN_INCH_15;

	// VREF selection: VR+ = Vcc, VR- = Vss
	ADC14->MCTL[0] &= ~ADC14_MCTLN_VRSEL_MASK;

	// pin function selection (pin 6.0, A15)
	P6->SEL0 |= BIT0;
	P6->SEL1 |= BIT0;



	// adc module interrupt enable
	NVIC->ISER[0] = 1 << ((ADC14_IRQn) & 31);

	// power on
	ADC14->CTL0 |= ADC14_CTL0_ON;
}


void ADC_Go( )
{
	// give it a start address, zero ...
	ADC14->CTL1 &= ~ADC14_CTL1_CSTARTADD_MASK;
	// turn on ENC
	ADC14->CTL0 |= ADC14_CTL0_ENC;
	// start the timer that triggers it
	TIMER_A2->CTL |= TIMER_A_CTL_MC__UP;

	// adc14ifg0 enable
	ADC14->CLRIFGR0 |= BIT0;
	ADC14->IER0 |= BIT0;

	TURN_ON_LEDB;
//	UartSendString("-----DAC GO-----\n\r\0");
}

void ADC_Stop( )
{
	// switch off ENC
	ADC14->CTL0 &= ~ADC14_CTL0_ENC;
	// stop the timer
	TIMER_A2->CTL &= ~TIMER_A_CTL_MC_MASK;
	// interrupt OFF
	ADC14->IER0 &= ~BIT0;

	TURN_OFF_LEDB;
//	UartSendString( "-----DAC STOP-----\n\r\0" );
}

void adc_ISR( )
{
	switch ( ADC14->IV ) {
	case 0x0C:
		UartSend16Little( ADC14->MEM[0] & 0x0000FFFF );
		break;
	default:
		break;
	}

}
