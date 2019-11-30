/****************************************************************************

        Copyright (c) 2015 - 2018 Qualcomm Technologies International, Ltd.
        All Rights Reserved.
        Qualcomm Technologies International, Ltd. Confidential and Proprietary.

FILE
    operator_if.h

CONTAINS
    Definitions for the DSPManager subsystem from VM.

DESCRIPTION
    This file is seen by the stack, and VM applications, and
    contains things that are common between them.
*/

/*!
 @file operator_if.h
 @brief Parameters for OperatorCreate()
*/

#ifndef __OPERATOR_IF_H__
#define __OPERATOR_IF_H__

/*!
    @brief DSP operator framework power state.
*/
typedef enum {
    MAIN_PROCESSOR_OFF = 0,    /*!< Power-off DSP main processor */
    MAIN_PROCESSOR_ON = 1,     /*!< Load DSP software on main processor */
    SECOND_PROCESSOR_OFF = 2,  /*!< Reserved on BlueCore; meaningful on Hydra */
    SECOND_PROCESSOR_ON = 3    /*!< Reserved on BlueCore; meaningful on Hydra */
} OperatorFrameworkPowerState;

/*!
    @brief key-value pair to specify certain parameters for 
    creating the operator via OperatorCreate() API.
*/
typedef struct
{
    uint16 key;         /*!< Key for OperatorCreate. */    
    uint32 value;       /*!< Value for the key. */
} OperatorCreateKeys;

#endif /* __OPERATOR_IF_H__  */

