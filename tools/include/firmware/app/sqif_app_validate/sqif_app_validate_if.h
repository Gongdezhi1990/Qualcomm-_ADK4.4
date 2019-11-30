/****************************************************************************
        Copyright (c) 2015 - 2018 Qualcomm Technologies International, Ltd.
        All Rights Reserved.
        Qualcomm Technologies International, Ltd. Confidential and Proprietary.
FILE
    sqif_app_validate_if.h

CONTAINS
    Status code of the validation of executable filesystems residing in
    SQIF

DESCRIPTION
    This file is seen by the stack, and VM applications, and
    contains things that are common between them.

*/


#ifndef __SQIF_APP_VALIDATE_IF_H__
#define __SQIF_APP_VALIDATE_IF_H__

/*! @brief Status codes returned by sqif_app_validate task 

    The expected status of the validation process could be pass, fail, running
    and not required. Before starting the validation, if the application
    security is found to be disabled, then validation will not be performed and
    the status will be reported as SQIF_APP_VALIDATION_NOT_REQUIRED.
    As soon as the validation starts, the status will be set to running. After
    the validation passes, firmware will continue running normally and the
    status of the validation process will be maintained as PASS.
    At any time, the firmware cannot return the validation result as fail
    because in that case the VM (and DSP) application will be stopped by the
    firmware and further appropriate action will result in reset of the device.
    Therefore the status returned by the firmware will be either
    SQIF_APP_VALIDATION_RUNNING or SQIF_APP_VALIDATION_PASS. Additionally,
    if there is nothing to validate then the firmware will consider the
    validation as pass and report the status as SQIF_APP_VALIDATION_PASS_NO_APP.
*/
typedef enum 
{
    /*! Validation is Running */
    SQIF_APP_VALIDATION_RUNNING = 0x0,
    /*! Validation Passed */
    SQIF_APP_VALIDATION_PASS = 0x1,
    /*! Validation Passed but without any application */
    SQIF_APP_VALIDATION_PASS_NO_APP = 0x2,
    /*! Validation not required */
    SQIF_APP_VALIDATION_NOT_REQUIRED = 0x3
} sqif_app_validate_status;

#endif /* __SQIF_APP_VALIDATE_IF_H__ */
