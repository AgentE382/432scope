#include <msp.h>
#include "led.h"

void InitializeLEDs( )
{
	SET_LED1_AS_AN_OUTPUT;
	SET_LEDR_AS_AN_OUTPUT;
	SET_LEDG_AS_AN_OUTPUT;
	SET_LEDB_AS_AN_OUTPUT;
	TURN_OFF_LED1;
	TURN_OFF_LEDR;
	TURN_OFF_LEDG;
	TURN_OFF_LEDB;
}
