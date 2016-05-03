#ifndef DEBOUNCE_H
#define DEBOUNCE_H

// in mS, how often the Debounce() function is called per switch-we-are-debouncing.
#define DEBOUNCE_CALL_INTERVAL 1

typedef enum { High, Low } SwitchStatus;
typedef enum { ExpectHigh, ValidateHigh, ExpectLow, ValidateLow } DebounceState;

typedef struct {
	// hardware details
	uint8_t* switchPort;
	unsigned char switchBit;
	SwitchStatus activeLevel;
	unsigned int activateBounceTime;
	unsigned int deactivateBounceTime;

	// FSM
	DebounceState debounceState;
	SwitchStatus currentValidOutput;
	void (*activateCallback)( );
	void (*deactivateCallback)( );

	// internal
	int validationCounter;
} SwitchDebouncer;

SwitchStatus Debounce( SwitchDebouncer* sd );

#endif
