/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    source_aghfp_data.h

DESCRIPTION
    handles the Hfp features

NOTES

*/

#ifndef _SOURCE_AGHFP_DATA_H_
#define _SOURCE_AGHFP_DATA_H_

#include <csrtypes.h>
#include <stdlib.h>
#include <audio_plugin_if.h>
#include <aghfp.h>
#include <sink.h>
#include "source_aghfp.h"


/*************************************************************************
NAME
    aghfp_source_data_init

DESCRIPTION
    Functions called to read the config variables from the config data.

RETURNS
    void

*/
void  aghfp_source_data_init(void );

/*************************************************************************
NAME
    aghfp_source_data_get_syncpkt_types

DESCRIPTION
    Returns the value of sync_pkt_types variable.

RETURNS
    The value of the variable 'sync_pkt_types' which is derived from the values of the 
    member variables of the structure sync_packet.The value of these member structure
    variables is initialized in the module xml file of AGHFP.

*/
uint16  aghfp_source_data_get_syncpkt_types(void);

/*************************************************************************
NAME
    aghfp_source_data_create_syncPkt_types

DESCRIPTION
     Creates the variable named sync_pkt_types from sco_packet,esco_packet and 
     edr_packet structure variables.

RETURNS
    void

***************************************************************************/
void aghfp_source_data_create_syncpkt_types(void);
        /*************************************************************************
NAME
    Source_Get_a2dp_max_connection_retries

DESCRIPTION
    Helper function to get the maximum number of connection retries whenever aghfp 
    connection fails..

RETURNS
    The maximum connection retries as read from the config block.

**************************************************************************/
uint16 aghfp_get_max_connection_retries(void);
        /*************************************************************************
NAME
    aghfp_get_profile_Value

DESCRIPTION
    Helper function to get the supported HFP profile .

RETURNS
    The current profile which is configured in the config block. The possible values:
    0 = HFP_PROFILE_DISABLED,
    1 = HFP_PROFILE_1_6,
    2 = HFP_PROFILE_1_7
    
**************************************************************************/
AGHFP_PROFILE_T aghfp_get_profile_Value(void);
/*************************************************************************
NAME
    aghfp_get_connection_failed_timer

DESCRIPTION
    Helper function to Get the AGHFP Connection Failed timer.

RETURNS
    The value as configured in the module xml file of  AGHFP.

**************************************************************************/
uint16 aghfp_get_connection_failed_timer(void);
/*************************************************************************
NAME
    aghfp_set_connection_failed_timer

DESCRIPTION
    Helper function to set the AGHFP Connection Failed timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool aghfp_set_connection_failed_timer(uint16 timeout);
#endif
