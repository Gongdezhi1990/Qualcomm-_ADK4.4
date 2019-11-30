/****************************************************************************
Copyright (c) 2018 Qualcomm Technologies International, Ltd.

FILE NAME
    local_device_state.c

DESCRIPTION
    State machine for local_device
*/

#include "local_device_state.h"
#include "local_device_app.h"
#include "local_device_ble_tx_power.h"
#include "local_device_cl.h"

#include <panic.h>
#include <stdlib.h>

typedef enum
{
    uninitialised,
    initialising,
    initialised
} local_device_state_t;

static local_device_state_t local_device_state = uninitialised;

/******************************************************************************/
static void localDeviceStateUninitialised(local_device_event_t event, local_device_event_data_t* data)
{
    switch(event)
    {
        case init_request_event:
            localDeviceAppSetTask(data->init_request.app_task);
            localDeviceClReadBleAdvertisingTxPower();
            local_device_state = initialising;
            break;
        
        case destroy_request_event:
            /* Nothing to destroy yet */
            break;
        
        default:
            Panic();
            break;
    }
}

/******************************************************************************/
static void localDeviceStateInitialising(local_device_event_t event, local_device_event_data_t* data)
{
    switch(event)
    {
        case ble_tx_power_ready_event:
            localDeviceBleTxPowerReading(data->ble_tx_power_ready.tx_power);
            localDeviceAppSendInitCfm();
            local_device_state = initialised;
            break;
        
        case destroy_request_event:
            localDeviceAppSetTask(NULL);
            localDeviceBleTxPowerReset();
            local_device_state = uninitialised;
            break;
        
        default:
            Panic();
            break;
    }
}

/******************************************************************************/
static void localDeviceStateInitialised(local_device_event_t event, local_device_event_data_t* data)
{
    switch(event)
    {
        case ble_tx_power_read_request_event:
            localDeviceBleTxPowerGetRequest(&data->ble_tx_power_read_request.tx_power);
            break;
        
        case destroy_request_event:
            localDeviceAppSetTask(NULL);
            localDeviceBleTxPowerReset();
            local_device_state = uninitialised;
            break;
        
        default:
            Panic();
            break;
    }
}

/******************************************************************************/
void localDeviceStateHandleEvent(local_device_event_t event, local_device_event_data_t* data)
{
    switch(local_device_state)
    {
        case uninitialised:
            localDeviceStateUninitialised(event, data);
            break;
        
        case initialising:
            localDeviceStateInitialising(event, data);
            break;
        
        case initialised:
            localDeviceStateInitialised(event, data);
            break;
        
        default:
            Panic();
            break;
    }
}
