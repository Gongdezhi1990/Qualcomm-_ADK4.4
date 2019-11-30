/****************************************************************************
Copyright (c) 2014 - 2015 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    sink_ble_advertising.h

DESCRIPTION
    BLE Advertising functionality
*/

#ifndef _SINK_BLE_ADVERTISING_H_
#define _SINK_BLE_ADVERTISING_H_

#include "sink_ble_gap.h"
#include <connection.h>

#include <csrtypes.h>


#define ADVERTISING gBleData->ble.gap.advertising


#define MAX_AD_DATA_SIZE_IN_OCTETS  (0x1F)   /* AD Data max size = 31 octets (defined by BT spec) */
#define AD_DATA_HEADER_SIZE         (0x02)   /* AD header{Octet[0]=length, Octet[1]=Tag} AD data{Octets[2]..[n]} */
#define OCTETS_PER_SERVICE          (0x02)   /* 2 octets per uint16 service UUID */
#define MIN_LOCAL_NAME_LENGTH       (0x10)   /* Minimum length of the local name being advertised*/

/* Discoverable mode */
typedef enum __adv_discoverable_mode
{
    adv_non_discoverable_mode,
    adv_discoverable_mode_general,
    adv_discoverable_mode_limited
} adv_discoverable_mode_t;


/*******************************************************************************
NAME    
    bleSetupAdvertisingData
    
DESCRIPTION
    Function to setup the BLE Advertising data for the device.
    
PARAMETERS
    size_local_name Length of the local name buffer.
    local_name      Buffer containing the local name.
    mode            Mode
    reason          Reason to set advertising data
RETURN
    None
*/
#ifdef GATT_ENABLED
void bleSetupAdvertisingData(uint16 size_local_name, const uint8 *local_name, adv_discoverable_mode_t mode, ble_gap_read_name_t reason);
#else
#define bleSetupAdvertisingData(size_local_name, local_name, mode, reason) (void(0))
#endif


/*******************************************************************************
NAME    
    bleHandleSetAdvertisingData
    
DESCRIPTION
    Function to handle when BLE advertising data has been registered with CL.
    
PARAMETERS
    cfm     pointer to a CL_DM_BLE_SET_ADVERTISING_DATA_CFM message.
    
RETURN
    None
*/
#ifdef GATT_ENABLED
void bleHandleSetAdvertisingData(const CL_DM_BLE_SET_ADVERTISING_DATA_CFM_T * cfm);
#else
#define bleHandleSetAdvertisingData(cfm) ((void)(0))
#endif

#if defined(GATT_ENABLED) && defined(CUSTOM_BLE_ADVERTISING_ENABLED)
void bleAdvertiseForBredrDiscovery(void);
#else
#define bleAdvertiseForBredrDiscovery() ((void)0)
#endif

/******************************************************************************
NAME    
    bleAddHeaderToAdData
    
DESCRIPTION
    Function to add BLE advertising data header.
    
PARAMETERS
    ad_data    pointer advertisement data buffer
    space       space left in the advertisement buffer
    type         AD type 
    
RETURN
    uint8*      updated pointer of ad_data buffer
*/
uint8* bleAddHeaderToAdData(uint8* ad_data, uint8* space, uint8 size, uint8 type);

/******************************************************************************
NAME    
    bleAddServiceUuidToAdData
    
DESCRIPTION
    Function to add the BLE service UUID in advertisement data.
    
PARAMETERS
    ad_data    pointer advertisement data buffer
    space       space left in the advertisement buffer
    uuid         BLE service UUID
    
RETURN
    uint8*      updated pointer of ad_data buffer
*/
uint8* bleAddServiceUuidToAdData(uint8* ad_data, uint8* space, uint16 uuid);

#endif /* _SINK_BLE_ADVERTISING_H_ */
