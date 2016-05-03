#include <msp.h>
#include "debounce.h"

/*
 * we invert ActiveLow signals in this instantaneous reader so that
 * I don't have to think about that again.
 */
inline SwitchStatus Instantaneous( SwitchDebouncer* sd )
{
	static unsigned char inputStatus;
	static SwitchStatus activeLevel;

	inputStatus = *(sd->switchPort) & sd->switchBit;
	activeLevel = sd->activeLevel;

	if ( (inputStatus == 0) && (activeLevel == Low) ) {
		return High;
	}
	if ( (inputStatus != 0) && (activeLevel == High) ) {
		return High;
	}

	return Low;
}

SwitchStatus Debounce( SwitchDebouncer* sd )
{
	SwitchStatus instantaneous;
	DebounceState nextState;

	instantaneous = Instantaneous( sd );

	switch ( sd->debounceState ) {
	case ExpectHigh:
		if ( instantaneous == High ) {
			// button may be pressed. go to validatehigh, set the timer
			nextState = ValidateHigh;
			sd->validationCounter = sd->activateBounceTime;
		} else {
			// nothing's happening.
			nextState = ExpectHigh;
		}
		break;
	case ValidateHigh:
		if ( instantaneous == High ) {
			// it's still high. count down.
			sd->validationCounter -= DEBOUNCE_CALL_INTERVAL;
			if (sd->validationCounter > 0 ) {
				// counter's not expired yet.  stay in validate.
				nextState = ValidateHigh;
			} else {
				// counter has expired, this is a valid high.  go to expectlow, trigger callback.
				nextState = ExpectLow;
				sd->currentValidOutput = High;
				if ( sd->activateCallback != 0 ) {
					sd->activateCallback( );
				}
			}
		} else {
			// it bounced back. go to expecthigh.
			nextState = ExpectHigh;
		}
		break;
	case ExpectLow:
		if ( instantaneous == Low ) {
			// button may be released. go to validatelow, set the timer.
			nextState = ValidateLow;
			sd->validationCounter = sd->deactivateBounceTime;
		} else {
			// nothing's happening.
			nextState = ExpectLow;
		}
		break;
	case ValidateLow:
		if ( instantaneous == Low ) {
			// it still may be low.  count down.
			sd->validationCounter -= DEBOUNCE_CALL_INTERVAL;
			if ( sd->validationCounter > 0 ) {
				// timer's not up yet. stay in validateLow.
				nextState = ValidateLow;
			} else {
				// timer's up, this is a valid low. go to expecthigh, callback...
				nextState = ExpectHigh;
				sd->currentValidOutput = Low;
				if ( sd->deactivateCallback != 0 ) {
					sd->deactivateCallback( );
				}
			}
		} else {
			// it bounced back.  go back to expectlow.
			nextState = ExpectLow;
		}
		break;
	default: break;
	}

	sd->debounceState = nextState;
	return sd->currentValidOutput;
}
