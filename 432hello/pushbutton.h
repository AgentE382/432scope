#ifndef PUSHBUTTON_H
#define PUSHBUTTON_H

#include "debounce.h"

/*
 * This is for the msp432p401r Launchpad.
 * Pushbuttons on P1.1 and P1.4 are active-low.
 * This code uses Timer A0 for debouncing.
 */

#define BUTTON1_BIT						BIT1
#define BUTTON2_BIT						BIT4

#define BUTTON_PRESS_BOUNCE_TIME		10
#define BUTTON_RELEASE_BOUNCE_TIME		20

extern SwitchDebouncer button1Debouncer;
extern SwitchDebouncer button2Debouncer;

void InitializeButtons( );

#endif
