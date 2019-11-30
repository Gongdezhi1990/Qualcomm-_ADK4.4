/****************************************************************************
Copyright (c) 2014 - 2015 Qualcomm Technologies International, Ltd.

FILE NAME
    sink_ble_advertising.c

DESCRIPTION
    BLE Advertising functionality
*/

#include "sink_ble_advertising.h"


#include "sink_ble.h"
#include "sink_gatt_device.h"
#include "sink_gatt_server_battery.h"
#include "sink_gatt_server_lls.h"
#include "sink_gatt_server_tps.h"
#include "sink_gatt_server_ias.h"
#include "sink_gatt_server_hrs.h"
#ifdef ACTIVITY_MONITORING
#include "sink_gatt_server_rscs.h"
#include "sink_gatt_server_logging.h"
#include "gatt_logging_server_uuids.h"
#endif
#include "sink_gatt_server_dis.h"
#include "sink_debug.h"
#include "sink_development.h"
#include "sink_utils.h"
#include "sink_configmanager.h"
#include "sink_ba.h"
#include "sink_ba_ble_gap.h"

#include <connection.h>
#include <gatt.h>
#include <local_device.h>

#include <csrtypes.h>
#include <stdlib.h>
#include <string.h>


#ifdef GATT_ENABLED


/* Macro for BLE AD Data Debug */
#ifdef DEBUG_BLE
#include <stdio.h>
#define BLE_AD_INFO(x) DEBUG(x)
#define BLE_AD_INFO_STRING(name, len) {unsigned i; for(i=0;i<len;i++) BLE_AD_INFO(("%c", name[i]));}
#define BLE_AD_ERROR(x) DEBUG(x) TOLERATED_ERROR(x)
#else
#define BLE_AD_INFO(x)
#define BLE_AD_INFO_STRING(name, len)
#define BLE_AD_ERROR(x)
#endif

#ifndef MIN
#define MIN(a, b)   ((a < b) ? a : b)
#endif 

#define MODE_TO_MASK(mode)  (1 << mode)

#define SIZE_UUID16                         (2)
#define AD_FIELD_LENGTH(data_length)        (data_length + 1)
#define USABLE_SPACE(space)                 ((*space) > AD_DATA_HEADER_SIZE ? (*space) - AD_DATA_HEADER_SIZE : 0)
 
#define SERVICE_DATA_LENGTH(num_services)   (num_services * OCTETS_PER_SERVICE)
#define NUM_SERVICES_THAT_FIT(space)        (USABLE_SPACE(space) / OCTETS_PER_SERVICE)

#define WRITE_AD_DATA(ad_data, space, value) \
{ \
    *ad_data = value; \
    BLE_AD_INFO(("0x%02x ", *ad_data)); \
    ad_data++; \
    (*space)--; \
}

/******************************************************************************/
static bool reserveSpaceForLocalName(uint8* space, uint16 name_length)
{
    uint8 required_space = MIN(name_length, MIN_LOCAL_NAME_LENGTH);
    
    if((*space) >= required_space)
    {
        *space -= required_space;
        return TRUE;
    }
    return FALSE;
}

/******************************************************************************/
static void restoreSpaceForLocalName(uint8* space, uint16 name_length)
{
    *space += MIN(name_length, MIN_LOCAL_NAME_LENGTH);
}

/******************************************************************************/
static uint8* setupFlagsAdData(uint8* ad_data, uint8* space, adv_discoverable_mode_t mode, ble_gap_read_name_t reason)
{
    uint16 flags = 0;

    if(reason == ble_gap_read_name_broadcasting || reason == ble_gap_read_name_associating)
        flags = BLE_FLAGS_DUAL_HOST;

    if (mode == adv_discoverable_mode_general)
        flags |= BLE_FLAGS_GENERAL_DISCOVERABLE_MODE;
    else if (mode == adv_discoverable_mode_limited)
        flags |= BLE_FLAGS_LIMITED_DISCOVERABLE_MODE;

    /* According to CSSv6 Part A, section 1.3 "FLAGS" states: 
        "The Flags data type shall be included when any of the Flag bits are non-zero and the advertising packet 
        is connectable, otherwise the Flags data type may be omitted"
     */
    if(flags)
    {
        BLE_AD_INFO(("AD Data: flags = ["));
        
        ad_data = bleAddHeaderToAdData(ad_data, space, FLAGS_DATA_LENGTH, ble_ad_type_flags);
        WRITE_AD_DATA(ad_data, space, flags);
        
        BLE_AD_INFO(("]\n"));
    }
    return ad_data;
}

/******************************************************************************/
static uint8* updateServicesAdData(uint8* ad_data, uint8* space)
{ 
    if (sinkGattBatteryServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("BAS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_BATTERY_SERVICE);
    }

    if (sinkGattLinkLossServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("LLS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_LINK_LOSS);
    }

    if (sinkGattTxPowerServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("TPS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_TX_POWER);
    }

    if (sinkGattImmAlertServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("IAS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_IMMEDIATE_ALERT);
    }

    if (sinkGattHeartRateServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("HRS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_HEART_RATE);
    }

#ifdef ACTIVITY_MONITORING
    if (sinkGattRSCServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("RSCS"));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_RUNNING_SPEED_AND_CADENCE);
    }
    // Advertising of 128 bit UUIDS is not currently supported by the Sink App
/*
    if (sinkGattLoggingServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("LOGGING"));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_LOGGING);
    }
*/
#endif

    if (sinkGattDeviceInfoServiceEnabled() && (*space))
    {
        BLE_AD_INFO(("DIS "));
        ad_data = bleAddServiceUuidToAdData(ad_data, space, GATT_SERVICE_UUID_DEVICE_INFORMATION);
    }
    
    return ad_data;
}

/******************************************************************************/
static uint16 getNumberOfServersEnabled(void)
{
    uint16 num_services = 0;

    if (sinkGattBatteryServiceEnabled())
        num_services++;

    if (sinkGattLinkLossServiceEnabled())
        num_services++;

    if (sinkGattTxPowerServiceEnabled())
        num_services++;

    if (sinkGattImmAlertServiceEnabled())
        num_services++;

    if (sinkGattHeartRateServiceEnabled())
        num_services++;

#ifdef ACTIVITY_MONITORING
    if (sinkGattRSCServiceEnabled())
        num_services++;
// We must not add this until 128 bit UUIDs are supported in Sink App!
//    if (sinkGattLoggingServiceEnabled())
//        num_services++;
#endif

    if (sinkGattDeviceInfoServiceEnabled())
        num_services++;

    return num_services;
}

/******************************************************************************/
static uint8* setupServicesAdData(uint8* ad_data, uint8* space, ble_gap_read_name_t reason)
{
    if(reason == ble_gap_read_name_broadcasting || reason == ble_gap_read_name_advertising_broadcasting)
    {
        /* Add the broadcaster variant IV service data */
        ad_data = setupBroadcasterIvServiceData(ad_data, space);
        if(reason == ble_gap_read_name_broadcasting)
            return ad_data;
    }

    if(reason == ble_gap_read_name_associating)
    {
        /* Set up receiver association service data */
        ad_data = setupReceiverAssociationServiceData(ad_data, space);
    }
    else
    {
        uint16 num_services = getNumberOfServersEnabled();
        uint8 num_services_that_fit = NUM_SERVICES_THAT_FIT(space);

        if (num_services && num_services_that_fit)
        {
            uint8 service_data_length;
            uint8 service_field_length;
            uint8 ad_tag = ble_ad_type_complete_uuid16;
        
            /* Is there enough room to store the complete list of services defined for the device? */
            if(num_services > num_services_that_fit)
            {
                /* Advertise incomplete list */
                ad_tag = ble_ad_type_more_uuid16;
                num_services = num_services_that_fit; 
            }
        
            /* Setup AD data for the services */
            BLE_AD_INFO(("AD Data: services = ["));
            service_data_length = SERVICE_DATA_LENGTH(num_services);
            service_field_length = AD_FIELD_LENGTH(service_data_length);
            ad_data = bleAddHeaderToAdData(ad_data, space, service_field_length, ad_tag);
        
            /* Add UUID of enabled services to advertising list */
            ad_data = updateServicesAdData(ad_data, space);
        
            BLE_AD_INFO(("]\n"));
        }
    }
    /* return the advertising data counter as next available index based on configured number of services */
    return ad_data;
}

/******************************************************************************/
static uint8* setupLocalNameAdvertisingData(uint8 *ad_data, uint8* space, uint16 size_local_name, const uint8 * local_name)
{
    uint8 name_field_length;
    uint8 name_data_length = size_local_name;
    uint8 ad_tag = ble_ad_type_complete_local_name;
    uint8 usable_space = USABLE_SPACE(space);

    if((name_data_length == 0) || usable_space <= 1)
        return ad_data;
    
    if(name_data_length > usable_space)
    {
        ad_tag = ble_ad_type_shortened_local_name;
        name_data_length = usable_space;
    }
    
    BLE_AD_INFO(("AD Data: local name = ["));
    
    name_field_length = AD_FIELD_LENGTH(name_data_length);
    ad_data = bleAddHeaderToAdData(ad_data, space, name_field_length, ad_tag);
    
    /* Setup the local name advertising data */
    memmove(ad_data, local_name, name_data_length);
    BLE_AD_INFO_STRING(ad_data, name_data_length);
    ad_data += name_data_length;
    *space -= name_data_length;
    
    BLE_AD_INFO(("]\n"));
    return ad_data;
}


/******************************************************************************/
uint8* bleAddHeaderToAdData(uint8* ad_data, uint8* space, uint8 size, uint8 type)
{
    WRITE_AD_DATA(ad_data, space, size);
    WRITE_AD_DATA(ad_data, space, type);
    
    return ad_data;
}

/******************************************************************************/
uint8* bleAddServiceUuidToAdData(uint8* ad_data, uint8* space, uint16 uuid)
{
    *ad_data = (uuid & 0xFF);
    *(ad_data + 1) = (uuid >> 8);
    
    BLE_AD_INFO(("0x%02x%02x ", ad_data[1], ad_data[0]));
    ad_data += SIZE_UUID16;
    *space -= SIZE_UUID16;
    
    return ad_data;
}

/******************************************************************************/
void bleSetupAdvertisingData(uint16 size_local_name, const uint8 *local_name, adv_discoverable_mode_t mode, ble_gap_read_name_t reason)
{
    uint8 space = MAX_AD_DATA_SIZE_IN_OCTETS * sizeof(uint8);
    uint8 *ad_start = malloc(space);

    if(ad_start)
    {
        uint8* ad_head = ad_start;
        bool name_space_reserved;
        
        ad_head = setupFlagsAdData(ad_head, &space, mode, reason);
        

        name_space_reserved = reserveSpaceForLocalName(&space, size_local_name);
        
        ad_head = setupServicesAdData(ad_head, &space, reason);
        
        if(name_space_reserved)
            restoreSpaceForLocalName(&space, size_local_name);
        
        ad_head = setupLocalNameAdvertisingData(ad_head, &space, size_local_name, local_name);
        
        ConnectionDmBleSetAdvertisingDataReq(ad_head - ad_start, ad_start);

        free (ad_start);
    }
}

/******************************************************************************/
void bleHandleSetAdvertisingData(const CL_DM_BLE_SET_ADVERTISING_DATA_CFM_T * cfm)
{
    ble_gap_event_t event;
    
    BLE_AD_INFO(("CL_DM_BLE_SET_ADVERTISING_DATA_CFM [%x]\n", cfm->status));
    
    if (cfm->status != success)
    {
        BLE_AD_ERROR(("  Failed!\n"));
    }

    /* Send GAP event after set of advertising data */
    event.id = ble_gap_event_set_advertising_complete;
    event.args = NULL;
    sinkBleGapEvent(event);
}


#endif /* GATT_ENABLED */
