/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    source_ahi.c

DESCRIPTION
    Implementation of the Source AHI.

*/
/*!
@file   source_ahi.c
@brief  Implementation of the Source AHI.
*/

#include <string.h>
#include <ps.h>
#include <ahi.h>

#include "ahi_host_usb.h"
#include "ahi_host_spi.h"
#include "source_ahi.h"
#include "source_configmanager.h"
#include "source_led_error.h"


/* PS Key used for Source AHI config. */
#define SOURCE_AHI_CONFIG_PS_KEY                          (CONFIG_AHI)

/* Number of words used in the ps key for Source AHI config. */
#define SOURCE_AHI_CONFIG_ITEMS                           (2)

/* Offset of words used in ps key for Source AHI config. */
#define SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET (0)
#define SOURCE_AHI_CONFIG_APP_MODE_OFFSET                 (1)

/* Default value for USB HID Datalink */
#define SOURCE_AHI_CONFIG_USB_HID_DATALINK_STATE_DEFAULT  source_ahi_usb_hid_datalink_enabled

/* Default value for app mode */
#define SOURCE_AHI_CONFIG_APP_MODE_DEFAULT                ahi_app_mode_normal

/* Value used for indicating Source AHI errors with LEDs */
#define SOURCE_AHI_LED_ERR_ID                             (50)



/* Private functions */
static ahi_application_mode_t getAppModeFromPsKey(void);
static ahi_status_t initAhi(Task app_task, ahi_application_mode_t app_mode);
static source_ahi_status_t checkSourceAhiConfig(void);
static source_ahi_status_t createDefaultSourceAhiConfig(void);
static void readConfigItem(uint16 offset, uint16* item);
static source_ahi_status_t writeConfigItem(uint16 offset, uint16 item);
static uint16 getDefaultConfigValue(uint16 offset);
static bool isUsbHidDatalinkStateCorrect(uint16 state);
static bool isAppModeCorrect(uint16 app_mode);


ahi_application_mode_t currentAppMode;


/******************************************************************************/
void sourceAhiEarlyInit(void)
{
    currentAppMode = getAppModeFromPsKey();
}


/******************************************************************************/
void sourceAhiInit(Task app_task)
{
    if( checkSourceAhiConfig() != source_ahi_status_succeeded )
        LedsIndicateError(SOURCE_AHI_LED_ERR_ID);
    
    if( initAhi(app_task, sourceAhiGetAppMode()) != ahi_status_success )
        LedsIndicateError(SOURCE_AHI_LED_ERR_ID);
}


/******************************************************************************/
bool sourceAhiIsRebootRequired(ahi_application_mode_t new_app_mode){
    
    ahi_application_mode_t current_app_mode = sourceAhiGetAppMode();
    
     /* Reboot is needed if we are switching from or to config mode */
    if(((current_app_mode == ahi_app_mode_configuration) && (new_app_mode != ahi_app_mode_configuration)) ||
       ((current_app_mode != ahi_app_mode_configuration) && (new_app_mode == ahi_app_mode_configuration)))
    {
        return TRUE;
    }

        return FALSE;
}


/******************************************************************************/
bool sourceAhiIsUsbHidDataLinkEnabled(void)
{
    uint16 usb_enabled;

    readConfigItem(SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET, &usb_enabled);
    return (usb_enabled == source_ahi_usb_hid_datalink_enabled ? TRUE : FALSE );
}


/******************************************************************************/
ahi_application_mode_t sourceAhiGetAppMode(void)
{
    return currentAppMode;
}


/******************************************************************************/
source_ahi_status_t sourceAhiSetUsbHidDataLinkState(source_ahi_usb_hid_datalink_state_t state)
{
    if( !isUsbHidDatalinkStateCorrect(state) )
    {
        return source_ahi_status_wrong_param;
    }
        
    return writeConfigItem(SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET, state);
}


/******************************************************************************/
source_ahi_status_t sourceAhiSetAppMode(ahi_application_mode_t mode)
{
    if( !isAppModeCorrect(mode) )
    {
        return source_ahi_status_wrong_param;
    }
    
    if( sourceAhiIsRebootRequired(mode) )
    {
        return writeConfigItem(SOURCE_AHI_CONFIG_APP_MODE_OFFSET, mode);
    }
    else
    {
        currentAppMode = mode;
        return source_ahi_status_succeeded;
    }
}


/***************************************************************************
NAME
    getAppModeFromPsKey
 
DESCRIPTION
    Function that retrieves the stored app mode from PS Store.

    This should only ever be called once from sourceAhiEarlyInit.
    Once source_ahi is intitialised all app mode get and set requests
    must go via sourceAhiGetAppMode and sourceAhiSetAppMode.

RETURNS
    Application mode stored in dedicated PS key.
*/
static ahi_application_mode_t getAppModeFromPsKey(void)
{
    uint16 app_mode;

    readConfigItem(SOURCE_AHI_CONFIG_APP_MODE_OFFSET, &app_mode);

    /* Always revert the app mode value in the ps key to "normal",
       so that it does not persist over another reboot. */
    writeConfigItem(SOURCE_AHI_CONFIG_APP_MODE_OFFSET, ahi_app_mode_normal);

    return app_mode;
}


/***************************************************************************
NAME
    initAhi
 
DESCRIPTION
    Function that initializes AHI library.
    
PARAMS
    app_task Task that AHI will send messages intended for the application to.
    app_mode The current application mode
    
RETURNS
    ahi_status_success if everything was OK, err code otherwise.
*/
static ahi_status_t initAhi(Task app_task, ahi_application_mode_t app_mode)
{
    ahi_status_t status;

    status = AhiInit(app_task, app_mode);
    if (ahi_status_success != status)
    {
        return status;
    }
    
#ifdef ENABLE_AHI_USB_HOST
    AhiUSBHostInit();
#endif

#ifdef ENABLE_AHI_SPI
    AhiSpiHostInit();
#endif
    
    return ahi_status_success;
}


/***************************************************************************
NAME
    checkSourceAhiConfig
 
DESCRIPTION
    Function that checks if Source Ahi config stored in dedicated PS Key
    has correct values.
 
RETURNS
    source_ahi_status_succeeded if everything was OK, err code otherwise.
*/
static source_ahi_status_t checkSourceAhiConfig(void){

    uint16 read_data_size;
    uint16 usb_enabled;
    uint16 app_mode;
    
    /* Check if the size of config data stored in ps key is correct */
    read_data_size = PsRetrieve(SOURCE_AHI_CONFIG_PS_KEY, 0, 0);
    if( read_data_size == 0 )
    {
        /* There is no data in source ahi ps key */
        return createDefaultSourceAhiConfig();
    }
    else if( read_data_size != SOURCE_AHI_CONFIG_ITEMS )
    {
        return source_ahi_status_config_incorrect;
    }

    readConfigItem(SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET, &usb_enabled);
    if( !isUsbHidDatalinkStateCorrect(usb_enabled) )
    {
        return source_ahi_status_config_incorrect;
    }

    readConfigItem(SOURCE_AHI_CONFIG_APP_MODE_OFFSET, &app_mode);
    if( !isAppModeCorrect(app_mode) )
    {
        return source_ahi_status_config_incorrect;
    }
    
    return source_ahi_status_succeeded;
}


/***************************************************************************
NAME
    createDefaultSourceAhiConfig
 
DESCRIPTION
    Function that writes default configuration for Source AHI to the
    ps key which is selected for that purpose.
 
RETURNS
    source_ahi_status_succeeded if everything was OK, err code otherwise.
*/
static source_ahi_status_t createDefaultSourceAhiConfig(void)
{
    uint16 default_config[SOURCE_AHI_CONFIG_ITEMS];
    uint16 data_written;

    /* Set default source ahi config data */
    default_config[SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET] = SOURCE_AHI_CONFIG_USB_HID_DATALINK_STATE_DEFAULT;
    default_config[SOURCE_AHI_CONFIG_APP_MODE_OFFSET] = SOURCE_AHI_CONFIG_APP_MODE_DEFAULT;
    /* Write default source ahi congig to ps key */
    data_written = PsStore(SOURCE_AHI_CONFIG_PS_KEY, (const void*)default_config, SOURCE_AHI_CONFIG_ITEMS);
   
    return (data_written == SOURCE_AHI_CONFIG_ITEMS ? source_ahi_status_succeeded : source_ahi_status_config_write );
}


/***************************************************************************
NAME
    readConfigItem
 
DESCRIPTION
    Function that reads selected item from Source AHI config ps key.
*/
static void readConfigItem(uint16 offset, uint16* item)
{
    uint16 read_data_size;
    uint16 config_data[SOURCE_AHI_CONFIG_ITEMS];


    read_data_size = PsRetrieve(SOURCE_AHI_CONFIG_PS_KEY, (void*)config_data, SOURCE_AHI_CONFIG_ITEMS);

    if( read_data_size == SOURCE_AHI_CONFIG_ITEMS )
    {
        *item = config_data[offset];
    }
    else
    {
        *item = getDefaultConfigValue(offset);
    }
}


/***************************************************************************
NAME
    WriteConfigItem
 
DESCRIPTION
    Function that writes selected item to the Source AHI config ps key.
 
RETURNS
    source_ahi_status_succeeded if everything was OK, err code otherwise.
*/
static source_ahi_status_t writeConfigItem(uint16 offset, uint16 item)
{
    uint16 config_data_size;
    
    /* Check if the size of config data stored in ps key is correct */
    config_data_size = PsRetrieve(SOURCE_AHI_CONFIG_PS_KEY, 0, 0);
    if( config_data_size == SOURCE_AHI_CONFIG_ITEMS )
    {
        uint16 written_data_size;
        uint16 config_data[SOURCE_AHI_CONFIG_ITEMS];
        /* Retrieve whole source ahi config */
        config_data_size = PsRetrieve(SOURCE_AHI_CONFIG_PS_KEY, (void*)config_data, SOURCE_AHI_CONFIG_ITEMS);
        if( config_data_size != SOURCE_AHI_CONFIG_ITEMS )
        {
            return source_ahi_status_config_read;
        }
        /* Modify selected item */
        config_data[offset] = item;
        written_data_size = PsStore(SOURCE_AHI_CONFIG_PS_KEY, (const void*)config_data, SOURCE_AHI_CONFIG_ITEMS);
        
        if( written_data_size != SOURCE_AHI_CONFIG_ITEMS )
        {
            return source_ahi_status_config_write;
        }
        
        return source_ahi_status_succeeded;
    }
        
    return source_ahi_status_config_incorrect;
}


/***************************************************************************
NAME
    getDefaultConfigValue
 
DESCRIPTION
    Function that returns default config item
    for a given item offset in Source AHI config ps key.
    
PARAMS
    offset offset of a given item.

RETURNS
    default config value.
*/
static uint16 getDefaultConfigValue(uint16 offset)
{
    switch(offset)
    {
        case SOURCE_AHI_CONFIG_USB_HID_DATALINK_ENABLED_OFFSET:
            return SOURCE_AHI_CONFIG_USB_HID_DATALINK_STATE_DEFAULT;
        case SOURCE_AHI_CONFIG_APP_MODE_OFFSET:
            return SOURCE_AHI_CONFIG_APP_MODE_DEFAULT;
        default:
            return 0;
    }
}


/***************************************************************************
NAME
    isUsbHidDatalinkStateCorrect
 
DESCRIPTION
    Function that checks if passed USB HID state
    has correct value.
    
PARAMS
    state USB HID state that is being checked.

RETURNS
    True if value is correct, false otherwise.
*/
static bool isUsbHidDatalinkStateCorrect(uint16 state)
{
    if( state == source_ahi_usb_hid_datalink_enabled ||
        state == source_ahi_usb_hid_datalink_disabled )
    {
        return TRUE;
    }
    return FALSE;
}


/***************************************************************************
NAME
    isAppModeCorrect
 
DESCRIPTION
    Function that checks if passed app mode
    has correct value.

PARAMS
    app_mode application mode that is being checked.
 
RETURNS
    True if value is correct, false otherwise.
*/
static bool isAppModeCorrect(uint16 app_mode){
    
    if( app_mode == ahi_app_mode_normal ||
        app_mode == ahi_app_mode_configuration ||
        app_mode == ahi_app_mode_normal_test )
    {
        return TRUE;
    }
    return FALSE;
}
