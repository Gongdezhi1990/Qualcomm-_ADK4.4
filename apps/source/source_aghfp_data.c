/*****************************************************************
Copyright (c)  2017 Qualcomm Technologies International, Ltd.

PROJECT
    source
    
FILE NAME
    source_aghfp_data.c

DESCRIPTION
    It contains AGHFP configuration data and Global data which need to be used by other modules
    
*/

#include <hfp.h>
#include <csrtypes.h>
#include <boot.h>
#include <byte_utils.h>
#include <print.h>
#include <string.h>
#include <stdlib.h>
#include <source_aghfp_data.h>
#include <source_aghfp.h>
#include <Source_aghfp_data_config_def.h>
#include "config_definition.h"
#include <config_store.h>
#include "Source_configmanager.h"
#include "source_private_data_config_def.h"

uint16 sync_pkt_types = 0;

/*************************************************************************
NAME
    aghfp_source_data_init

DESCRIPTION
    Function to Initialise the AGHfp configuration data.

RETURNS
    void

**************************************************************************/
void aghfp_source_data_init(void)
{
    source_aghfp_data_readonly_config_def_t *hfp_config_data = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_AGHFP_DATA_READONLY_CONFIG_BLK_ID, (const void **)&hfp_config_data))
    {
        aghfp_source_init_globaldata(hfp_config_data);
    }
    configManagerReleaseConfig(SOURCE_AGHFP_DATA_READONLY_CONFIG_BLK_ID);
}
/*************************************************************************
NAME
    sourceAGHfpDataCreateSyncPktTypes

DESCRIPTION
     Creates the variable named sync_pkt_types from sco_packet,esco_packet and 
     edr_packet structure variables.

RETURNS
    void

***************************************************************************/
void aghfp_source_data_create_syncpkt_types(void)
{
    sync_packet_config_def_t *sync_packet = NULL;
    if (configManagerGetReadOnlyConfig(SYNC_PACKET_CONFIG_BLK_ID, (const void **)&sync_packet))
    {
        if(sync_packet != NULL)
        {
            sync_pkt_types |= (sync_packet->SCOhv1enable)&0xFFFF;
            sync_pkt_types |= ((sync_packet->SCOhv2enable)<<1)&0xFFFF;
            sync_pkt_types |= ((sync_packet->SCOhv3enable)<<2)&0xFFFF;
            sync_pkt_types |= ((sync_packet->ESCOev3enable)<<3)&0xFFFF;
            sync_pkt_types |= ((sync_packet->ESCOev4enable)<<4)&0xFFFF;
            sync_pkt_types |= ((sync_packet->ESCOev5enable)<<5)&0xFFFF;
            sync_pkt_types |= ((sync_packet->edr2ev3disable)<<6)&0xFFFF;
            sync_pkt_types |= ((sync_packet->edr3ev3disable)<<7)&0xFFFF;
            sync_pkt_types |= ((sync_packet->edr2ev5disable)<<8)&0xFFFF;
            sync_pkt_types |= ((sync_packet->edr3ev5disable)<<9)&0xFFFF;
        }
    }
    configManagerReleaseConfig(SYNC_PACKET_CONFIG_BLK_ID);
}
/*************************************************************************
NAME
    aghfp_source_data_get_syncpkt_types

DESCRIPTION
    Returns the value of sync_pkt_types variable.

RETURNS
    The value of the variable 'sync_pkt_types' which is derived from the values of the 
    member variables of the structure sync_packet.The value of these member structure
    variables is initialized in the module xml file of AGHFP.

***************************************************************************/
uint16 aghfp_source_data_get_syncpkt_types(void)
{
    return sync_pkt_types;
}
/*************************************************************************
NAME
    aghfp_get_max_connection_retries

DESCRIPTION
    Helper function to get the maximum number of connection retries whenever aghfp 
    connection fails..

RETURNS
    The maximum connection retries as read from the config block.

**************************************************************************/
uint16 aghfp_get_max_connection_retries(void)
{
    uint16 aghfp_max_connection_retries = 0;
    source_aghfp_data_readonly_config_def_t *hfp_config_data = NULL;

    if (configManagerGetReadOnlyConfig(SOURCE_AGHFP_DATA_READONLY_CONFIG_BLK_ID, (const void **)&hfp_config_data))
    {
        aghfp_max_connection_retries = hfp_config_data->AGHFPMaxContRetries;
    }
    configManagerReleaseConfig(SOURCE_AGHFP_DATA_READONLY_CONFIG_BLK_ID);
     return aghfp_max_connection_retries;
}
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
AGHFP_PROFILE_T aghfp_get_profile_Value(void)
{       
    AGHFP_PROFILE_T supported_profile_def = HFP_PROFILE_DISABLED;
    
#ifdef MS_LYNC_ONLY_BUILD
    supported_profile_def = HFP_PROFILE_1_7;
#else

    source_aghfp_writable_data_config_def_t *hfp_profile_value = NULL;
    if (configManagerGetReadOnlyConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID, (const void **)&hfp_profile_value))
    {
        supported_profile_def = hfp_profile_value->hfpProfile;
    }
    configManagerReleaseConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID);
    
#endif
    return supported_profile_def;

}
/*************************************************************************
NAME
    source_timers_get_aghfp_connection_failed_timer

DESCRIPTION
    Helper function to Get the AGHFP Connection Failed timer.

RETURNS
    The value as configured in the module xml file of  AGHFP.

**************************************************************************/
uint16 aghfp_get_connection_failed_timer(void)
{
    uint16 AGHFP_Connection_timer = 0;
    source_aghfp_writable_data_config_def_t *aghfp_timer_data;

    if (configManagerGetReadOnlyConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID, (const void **)&aghfp_timer_data))
    {
        AGHFP_Connection_timer = aghfp_timer_data->AGHFPConnectionFailed_s;
    }
    configManagerReleaseConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID);
    return AGHFP_Connection_timer;
}
/*************************************************************************
NAME
    source_timers_set_aghfp_connection_failed_timer

DESCRIPTION
    Helper function to set the AGHFP Connection Failed timer value.

RETURNS
    TRUE is value was set ok, FALSE otherwise.
*/
bool aghfp_set_connection_failed_timer(uint16 timeout)
{
    source_aghfp_writable_data_config_def_t *read_configdata = NULL;
    
    if (configManagerGetWriteableConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID, (void **)&read_configdata, 0))
    {
        read_configdata->AGHFPConnectionFailed_s = timeout ;
        configManagerUpdateWriteableConfig(SOURCE_AGHFP_WRITABLE_DATA_CONFIG_BLK_ID);
        return TRUE;
    }

    return FALSE;
}

