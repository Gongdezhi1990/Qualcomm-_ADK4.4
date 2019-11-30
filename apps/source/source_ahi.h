/****************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    source_ahi.h

DESCRIPTION
    Header file for Source AHI utility.

*/
/*!
@file   source_ahi.h
@brief  Functions which are helping with maintenance of AHI related
        configuration of Source application.


*/

#ifndef SOURCE_AHI_H_
#define SOURCE_AHI_H_

#include <ahi.h>
#include <stdlib.h>


/*!
    @brief Source AHI operation status codes
 
    Defines all possible status codes that may be returned
    by Source AHI public API functions.
*/
typedef enum __source_ahi_status
{
    source_ahi_status_succeeded = 0,          /*! Operation Succeeded */
    source_ahi_status_config_incorrect,       /*! Existing configuration kept under Source Ahi ps key is incorrect */
    source_ahi_status_config_read,            /*! Retrieving Source AHI config from ps store failed */
    source_ahi_status_config_write,           /*! Storing Source AHI config in ps store failed */
    source_ahi_status_wrong_param             /*! Wrong parameters passed to the function */
 
} source_ahi_status_t;


/*!
    @brief States of AHI's USB HID Datalink transport
 
    It can be either enabled or disabled.
*/
typedef enum __source_ahi_usb_hid_datalink_state
{
    source_ahi_usb_hid_datalink_disabled = 0,    /*! USB HID Datalink transport disabled in Source App */
    source_ahi_usb_hid_datalink_enabled          /*! USB HID Datalink transport enabled in Source App */
 
} source_ahi_usb_hid_datalink_state_t;





/*
    @brief Function that initializes Source Ahi private data.
           It should be called before any other Source Ahi API is used.
*/
void sourceAhiEarlyInit(void);


/*
    @brief Function that initializes Source Ahi. If there are any errors
           with Source Ahi config, it will enter the infinite loop, and indicate
           error using LEDs.
           
    @param app_task Task that AHI will send messages intended for the
                         application to.
*/
void sourceAhiInit(Task app_task);


/*
    @brief Function that checks if after the transition to the new 
           application mode reboot will be required.

    @param new_app_mode Application mode into which we want to switch.

    @return TRUE if reboot is required, FALSE otherwise.
*/
bool sourceAhiIsRebootRequired(ahi_application_mode_t new_app_mode);


/*
    @brief  Function that checks if the USB HID Datalink transport is enabled.
    
    @return TRUE if USB HID Datalink is enabled, FALSE otherwise.
*/
bool sourceAhiIsUsbHidDataLinkEnabled(void);


/*
    @brief Function that returns the app mode that is currently set.

    @return app mode that is currently set.
*/
ahi_application_mode_t sourceAhiGetAppMode(void);


/*
    @brief Function that sets the USB HID Datalink transport status in source AHI
           configuration ps key with a given value.

    @param state USB HID Datalink transport state to be set.
                    
    @return      source_ahi_status_succeeded if everything was OK,
                 err code otherwise.
*/
source_ahi_status_t sourceAhiSetUsbHidDataLinkState(source_ahi_usb_hid_datalink_state_t state);


/*
    @brief Function that sets the application mode in source AHI configuration
           ps key with a given value.

    @param mode Application mode to be set.
                    
    @return     source_ahi_status_succeeded if everything was OK,
                err code otherwise.
*/
source_ahi_status_t sourceAhiSetAppMode(ahi_application_mode_t mode);


#endif /* SOURCE_AHI_H_ */
