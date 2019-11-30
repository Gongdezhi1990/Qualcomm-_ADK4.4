/*******************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_cvc_common_state_machine.h

DESCRIPTION
    State machine to handle connect/disconnect events in the CVC plugin
    
NOTES
    
*/

#ifndef _CSR_CVC_COMMON_STATE_MACHINE_H_
#define _CSR_CVC_COMMON_STATE_MACHINE_H_

#include <message.h>
#include <csrtypes.h>
#include "csr_cvc_common_plugin.h"

typedef enum
{
    cvc_event_invalid,
    cvc_event_no_dsp_setup,
    cvc_event_dsp_loaded,
    cvc_ready_for_configuration,
    cvc_configuration_complete,
    cvc_security_complete,
    cvc_disconnect_request
} cvc_event_id_t;

typedef struct
{
    Task task;
} cvc_ready_for_configuration_t;

typedef struct
{
    CvcPluginTaskdata* cvc_task;
} cvc_disconnect_request_t;

typedef union
{
    cvc_ready_for_configuration_t ready_for_configuration;
	cvc_disconnect_request_t cvc_disconnect_request;
} cvc_event_t;

/*******************************************************************************
DESCRIPTION
    Reset the state machine to it's default state
*/
void csrCvcCommonStateMachineReset(void);

/*******************************************************************************
DESCRIPTION
    Inject an event into the CVC state machine. This is the main entry point
    for any next CVC events.
*/
void csrCvcCommonStateMachineHandleEvent(cvc_event_id_t id, cvc_event_t* event);

/*******************************************************************************
DESCRIPTION
    Kick the state machine with the next event if necessary. Not to be called
    except from within the state machine.
*/
void csrCvcCommonStateMachineKick(cvc_event_id_t id, cvc_event_t* event);

/*******************************************************************************
DESCRIPTION
    Trigger an event via a message rather than direct call to handle event
*/
void csrCvcCommonStateMachineScheduleEvent(cvc_event_id_t id, cvc_event_t* event);

#endif
