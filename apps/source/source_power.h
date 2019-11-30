/*****************************************************************
Copyright (c) 2011 - 2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_power.h

DESCRIPTION
    Handles power readings when running as a self powered device.    

*/


#ifndef _SOURCE_POWER_H_
#define _SOURCE_POWER_H_


/* VM headers */
#include <csrtypes.h>
#include "source_private.h"

/* structure used to hold the power table entries */
typedef struct
{
    unsigned unused:8;
    unsigned aghfp_entries:4;
    unsigned a2dp_entries:4;
    lp_power_table powertable[1];
} POWER_TABLE_T;

/***************************************************************************
Function definitions
****************************************************************************
*/

#ifdef INCLUDE_POWER_READINGS

/****************************************************************************
NAME    
    power_init

DESCRIPTION
    Initialises the power manager.
 
*/
#ifdef INCLUDE_POWER_READINGS
void power_init(void);
#else
#define power_init() ((void)(0))
#endif

#endif /* INCLUDE_POWER_READINGS */


/****************************************************************************
NAME    
    power_is_charger_connected
    
DESCRIPTION
      This function checks  if the charger is connected  or not

RETURNS
    TRUE, if the charger is connected.
    FALSE, if otherwise.
    
*/
bool power_is_charger_connected(void);
/****************************************************************************
NAME    
    power_get_a2dp_number_of_entries

DESCRIPTION
    This function gets the a2dp number of entries as initialized from the xml file.

RETURNS
    The number of A2DP entries read from the config block section.
    
*/
uint8 power_get_a2dp_number_of_entries(void);
/****************************************************************************
NAME    
    power_get_aghfp_number_of_entries

DESCRIPTION
    This function gets the aghfp number of entries as initialized from the xml file.

RETURNS
    The number of AGHFP entries read from the config block section.
    
*/
uint8 power_get_aghfp_number_of_entries(void);
/****************************************************************************
NAME    
    power_get_a2dp_power_table

DESCRIPTION
    This function gets the address of the a2dp power table entries.

RETURNS
    The pointer to the structure variable a2dp_powertable
    
*/
lp_power_table  *power_get_a2dp_power_table(void);
/****************************************************************************
NAME    
    power_get_aghfp_power_table

DESCRIPTION
    This function gets the address of the aghfp power table entries.

RETURNS
    The pointer to the structure variable aghfp_powertable
    
*/
lp_power_table  *power_get_aghfp_power_table(void);

#endif /* _SOURCE_POWER_H_ */


