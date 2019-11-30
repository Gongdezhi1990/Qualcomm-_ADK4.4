/*******************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_cvc_common_state_machine.c

DESCRIPTION
    State machine to handle connect/disconnect events in the CVC plugin
    
NOTES
    
*/

#include <csr_cvc_common_state_machine.h>
#include <csr_cvc_common.h>
#include <audio.h>
#include <stddef.h>
#include <print.h>

#define STATE_ERROR(state, id)  \
{ \
    PRINT(("CVC: State Error %s, %u\n", state, id)); \
    Panic(); \
}

/*******************************************************************************
STATE MACHINE
     ______________________  cvc_event_no_dsp_setup   __________________       
  ->| cvc_state_not_loaded |------------------------>| cvc_state_no_dsp |----- 
 |   ----------------------                           ------------------      |
 |          |  - cvc_event_dsp_loaded                                         |
 |   ______________________                                                   |
 |  |  cvc_state_loading   |                                                  |
 |   ----------------------                                                   |
 |          |  - cvc_ready_for_configuration                                  |
 |   ______________________                                                   |
 |  |cvc_state_loaded_idle |------------------                                |
 |   ----------------------                   |                               |
 |          |  - cvc_configuration_complete   |  - cvc_security_complete      |
 |   ______________________         ________________________                  |
 |  | cvc_state_codec_set  |       | cvc_state_security_set |                 |
 |   ----------------------         ------------------------                  |
 |          | - cvc_security_complete         |  - cvc_configuration_complete |
 |   _______________________                  |                               |
 |  |   cvc_state_running   |<----------------                                |
 |   -----------------------                                                  |
 |          |  - cvc_disconnect_request                                             |
  ---------- <----------------------------------------------------------------
*******************************************************************************/
typedef enum
{
    cvc_state_not_loaded,
    cvc_state_loading,
    cvc_state_loaded_idle,
    cvc_state_codec_set,
    cvc_state_security_set,
    cvc_state_running,
    cvc_state_no_dsp
} cvc_state_t;

static cvc_state_t cvc_state = cvc_state_not_loaded;

static void csrCvcCommonStateMachineHandler(Task task, MessageId id, Message msg);

static const TaskData cvc_state_machine_task = {csrCvcCommonStateMachineHandler};

/*******************************************************************************
DESCRIPTION
    Get the CVC state
*/
static cvc_state_t cvcGetState(void)
{
    return cvc_state;
}

/*******************************************************************************
DESCRIPTION
    Set the CVC state
*/
static void cvcSetState(cvc_state_t state)
{
    cvc_state = state;
}

/******************************************************************************/
void csrCvcCommonStateMachineReset(void)
{
    cvc_state = cvc_state_not_loaded;
}

/*******************************************************************************
DESCRIPTION
    CVC has connected with no DSP configuration
*/
static void handleEventNoDspSetup(void)
{
    /* CVC state is "no DSP", make sure DSP state is still "DSP_NOT_LOADED" */
    cvcSetState(cvc_state_no_dsp);
    SetCurrentDspStatus(DSP_NOT_LOADED);
}

/*******************************************************************************
DESCRIPTION
    CVC has been loaded, we must wait for it to complete initialisation so 
    we wait in loading state.
*/
static void handleEventDspLoaded(void)
{
    /* Now the kap file has been loaded, wait for the CVC_READY_MSG message from
       the dsp to be sent to the message_handler function. */
    SetCurrentDspStatus(DSP_LOADING);
    cvcSetState(cvc_state_loading);
}

/*******************************************************************************
DESCRIPTION
    CVC has reported it is ready to receive configuration, it is loaded-idle. 
    Time to connect the input/output ports and configure CVC parameters.
*/
static void handleEventDspReadyForConfiguration(cvc_event_t* event)
{
    Task cvc_task = event->ready_for_configuration.task;
    csrCvcCommonConnectAudio((CvcPluginTaskdata*)cvc_task);
    SetCurrentDspStatus(DSP_LOADED_IDLE);
    cvcSetState(cvc_state_loaded_idle);
}

/*******************************************************************************
DESCRIPTION
    CVC has been loaded and configured, wait for security confirmation
*/
static void handleEventDspCodecSet(void)
{
    cvcSetState(cvc_state_codec_set);
    SetCurrentDspStatus(DSP_RUNNING);
}

/*******************************************************************************
DESCRIPTION
    CVC has checked for a valid license and returned a response. Wait until 
    for codec configuration confirmation
*/
static void handleEventSecurityComplete(void)
{
    cvcSetState(cvc_state_security_set);
}

/*******************************************************************************
DESCRIPTION
    CVC has been loaded and we have had codec and security confirmation, make
    sure we are in running state and audio busy flag is cleared.
*/
static void handleEventDspConfigurationComplete(void)
{
    SetAudioBusy(NULL);
    cvcSetState(cvc_state_running);
    SetCurrentDspStatus(DSP_RUNNING);
}

/*******************************************************************************
DESCRIPTION
    CVC has been disconnected, return to the not loaded state
*/
static void handleEventDspDisconnectRequest(cvc_event_t* event)
{
	CvcPluginTaskdata* cvc_task = event->cvc_disconnect_request.cvc_task; 
	CsrCvcPluginDisconnect(cvc_task);
    cvcSetState(cvc_state_not_loaded);
    SetCurrentDspStatus(DSP_NOT_LOADED);
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_not_loaded
*/
static void handleStateDspNotLoaded(cvc_event_id_t id, cvc_event_t* event)
{
    UNUSED(event);
    switch(id)
    {
        case cvc_event_no_dsp_setup:
            handleEventNoDspSetup();
        break;
        
        case cvc_event_dsp_loaded:
            handleEventDspLoaded();
        break;
        
        default:
            STATE_ERROR("not_loaded", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_loading
*/
static void handleStateDspLoading(cvc_event_id_t id, cvc_event_t* event)
{
    switch(id)
    {
        case cvc_ready_for_configuration:
            handleEventDspReadyForConfiguration(event);
        break;
        
        default:
            STATE_ERROR("loading", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_loaded_idle
*/
static void handleStateDspLoadedIdle(cvc_event_id_t id, cvc_event_t* event)
{
    UNUSED(event);
    switch(id)
    {
        case cvc_configuration_complete:
            handleEventDspCodecSet();
        break;
        
        case cvc_security_complete:
            handleEventSecurityComplete();
        break;
        
        default:
            STATE_ERROR("loaded_idle", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_codec_set
*/
static void handleStateDspCodecSet(cvc_event_id_t id, cvc_event_t* event)
{
    UNUSED(event);
    switch(id)
    {
        case cvc_security_complete:
            handleEventDspConfigurationComplete();
        break;
        
        case cvc_configuration_complete:
            /* Ignore reconfiguration */
        break;
        
        default:
            STATE_ERROR("codec_set", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_codec_set
*/
static void handleStateDspSecuritySet(cvc_event_id_t id, cvc_event_t* event)
{
    UNUSED(event);
    switch(id)
    {
        case cvc_configuration_complete:
            handleEventDspConfigurationComplete();
        break;

        default:
            STATE_ERROR("security_set", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_running
*/
static void handleStateDspRunning(cvc_event_id_t id, cvc_event_t* event)
{
    switch(id)
    {
        case cvc_configuration_complete:
            /* Ignore reconfiguration */
        break;
        
        case cvc_disconnect_request:
		    handleEventDspDisconnectRequest(event);
        break;
        
        default:
            STATE_ERROR("running", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Handle an event in cvc_state_running
*/
static void handleStateNoDsp(cvc_event_id_t id, cvc_event_t* event)
{
    switch(id)
    {
        case cvc_disconnect_request:
		    handleEventDspDisconnectRequest(event);
        break;
        
        default:
            STATE_ERROR("no_dsp", id);
        break;
    }
}

/*******************************************************************************
DESCRIPTION
    Inject an event into the CVC state machine. 
*/
void csrCvcCommonStateMachineHandleEvent(cvc_event_id_t id, cvc_event_t* event)
{
    switch(cvcGetState())
    {
        case cvc_state_not_loaded:
            handleStateDspNotLoaded(id, event);
        break;
        
        case cvc_state_loading:
            handleStateDspLoading(id, event);
        break;
        
        case cvc_state_loaded_idle:
            handleStateDspLoadedIdle(id, event);
        break;
        
        case cvc_state_codec_set:
            handleStateDspCodecSet(id, event);
        break;
        
        case cvc_state_security_set:
            handleStateDspSecuritySet(id, event);
        break;
        
        case cvc_state_running:
            handleStateDspRunning(id, event);
        break;
        
        case cvc_state_no_dsp:
            handleStateNoDsp(id, event);
        break;
        
        default:
            STATE_ERROR("invalid", id);
        break;
    }
    
    csrCvcCommonStateMachineKick(id, event);
}

/*******************************************************************************
DESCRIPTION
    Handler for kick messages. This simply passes the ID and payload on to the
    state machine to be handled. Kicks are done via messages to avoid recursive
    calls into the state machine.
*/
static void csrCvcCommonStateMachineHandler(Task task, MessageId id, Message msg)
{
    cvc_event_t* event = (cvc_event_t*)msg;	
    UNUSED(task);
    csrCvcCommonStateMachineHandleEvent(id, event);
}

/******************************************************************************/
void csrCvcCommonStateMachineScheduleEvent(cvc_event_id_t id, cvc_event_t* event)
{
    MessageSend((Task)&cvc_state_machine_task, id, event);
}
