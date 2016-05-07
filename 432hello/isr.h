#ifndef ISR_H
#define ISR_H

/* forward declarations of MY handlers :D we'll include this in the file where
 * the interrupt table is declared. */

void ta0ccr0_ISR( );
void ta1ccr0_ISR( );
void port1_ISR( );
void euscia0_ISR( );
void adc_ISR( );

#endif
