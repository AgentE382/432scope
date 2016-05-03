#ifndef LED_H
#define LED_H

/*
 * msp432 launchpad LED defines
 */

void InitializeLEDs( );

/*
 * a red LED on P1.0
 */

#define LED1_PORT					P1
#define LED1_BIT					BIT0
#define SET_LED1_AS_AN_OUTPUT		LED1_PORT->DIR |= LED1_BIT
#define TURN_ON_LED1				LED1_PORT->OUT |= LED1_BIT
#define TURN_OFF_LED1				LED1_PORT->OUT &= ~LED1_BIT
#define TOGGLE_LED1					LED1_PORT->OUT ^= LED1_BIT

/*
 * red on P2.0
 */

#define LEDR_PORT					P2
#define LEDR_BIT					BIT0
#define SET_LEDR_AS_AN_OUTPUT		LEDR_PORT->DIR |= LEDR_BIT
#define TURN_ON_LEDR				LEDR_PORT->OUT |= LEDR_BIT
#define TURN_OFF_LEDR				LEDR_PORT->OUT &= ~LEDR_BIT
#define TOGGLE_LEDR					LEDR_PORT->OUT ^= LEDR_BIT

/*
 * green on P2.1
 */

#define LEDG_PORT					P2
#define LEDG_BIT					BIT1
#define SET_LEDG_AS_AN_OUTPUT		LEDG_PORT->DIR |= LEDG_BIT
#define TURN_ON_LEDG				LEDG_PORT->OUT |= LEDG_BIT
#define TURN_OFF_LEDG				LEDG_PORT->OUT &= ~LEDG_BIT
#define TOGGLE_LEDG					LEDG_PORT->OUT ^= LEDG_BIT

/*
 * blue on P2.2
 */

#define LEDB_PORT					P2
#define LEDB_BIT					BIT2
#define SET_LEDB_AS_AN_OUTPUT		LEDB_PORT->DIR |= LEDB_BIT
#define TURN_ON_LEDB				LEDB_PORT->OUT |= LEDB_BIT
#define TURN_OFF_LEDB				LEDB_PORT->OUT &= ~LEDB_BIT
#define TOGGLE_LEDB					LEDB_PORT->OUT ^= LEDB_BIT

#endif
