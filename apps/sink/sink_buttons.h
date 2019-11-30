/*
Copyright (c) 2004 - 2016 Qualcomm Technologies International, Ltd.
*/

/*!
@file
@ingroup sink_app
*/
#ifndef SINK_BUTTONS_H
#define SINK_BUTTONS_H

#include "sink_buttonmanager.h"

/* For Gordon/Rick and Crescendo Vreg and Charger are handled by Apps P1. */

#define VREG_PIN    (24)
#define CHG_PIN     (25)

    /*the mask values for the charger pins*/
#define VREG_PIN_MASK ((uint32)1 << VREG_PIN)
#define CHG_PIN_MASK ((uint32)1 << CHG_PIN)

    /*the mask values for the charger pin events*/
#define CHARGER_VREG_VALUE ( (uint32)((PsuGetVregEn()) ? VREG_PIN_MASK:0 ) )
#define CHARGER_CONNECT_VALUE ( (uint32)( (powerManagerIsChargerConnected())  ? CHG_PIN_MASK:0 ) )

#define DOUBLE_PRESS 2
#define TRIPLE_PRESS 3

/****************************************************************************
DESCRIPTION
 Initialises the button event 
*/
void ButtonsInit (  void ) ;

/****************************************************************************
DESCRIPTION
 Initialise the PIO hardware.

 Initialises the button hardware.mapping physical input numbers to produce
 masks and initialising all the PIOs.
*/
void ButtonsInitHardware ( void ) ;

/****************************************************************************
DESCRIPTION
 	Called after the configuration has been read and will trigger buttons events
    if a pio has been pressed or held whilst the configuration was still being loaded
    , i.e. the power on button press    
*/
void ButtonsCheckForChangeAfterInit( void );

/****************************************************************************
DESCRIPTION
 	this function remaps the capacitive sensor and pio bitmask into an input assignment
    pattern specified by pskey user 10, this allows buttons to be triggered from 
    pios of anywhere from 0 to 31 and capacitive sensor 0 to 5

*/ 
uint32 ButtonsTranslate(uint16 CapacitiveSensorState, pio_common_allbits *PioState);


/*!
    this function remaps an input assignment into a capacitive sensor or pio bitmask
    pattern specified by the configuration.

    A pointer to the mask variable to be returned is supplied as a parameter.
    
    @param[in,out] mask pointer to the pio_common_allbits to initialise and return
    @param[in] event_config The event configuration being translated
    @param include_capacitive_sensor Whether capacitive sensor inputs are included in the translation
*/
pio_common_allbits *ButtonsTranslateInput(pio_common_allbits *mask, 
                                          const event_config_type_t *event_config, bool include_capacitive_sensor);



#endif
