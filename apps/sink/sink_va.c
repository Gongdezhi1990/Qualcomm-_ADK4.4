/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    sink_va.c

DESCRIPTION
    Manages Voice Assistant Application.
    
NOTES

*/

#include "sink_va.h"
#include "sink_private_data.h"
#include "sink_gaia.h"
#include "sink_callmanager.h"
#include "sink_a2dp.h"
#include "sink_audio_routing.h"
#include "sink_main_task.h"
#include "sink_audio_indication.h"

#ifdef ENABLE_VOICE_ASSISTANT
#include <message.h>
#include <audio.h>
#include <audio_config.h>
#include <vmtypes.h>
#include <voice_assistant_packetiser.h>
#include <audio_plugin_if.h>

/* Return the task associated with Voice Assistant */
#define VaGetTask() (&va.task)

/* ID to define the internal msg */
#define VA_INTERNAL_MSG_BASE                   0x7000
#define VA_COMMAND_RSP_TIMEOUT_MSG    VA_INTERNAL_MSG_BASE + 1

#define VA_SESSION_STAGE_IDLE                                       0x01
#define VA_SESSION_STAGE_TRIGGERED                            0x02
#define VA_SESSION_STAGE_VOICE_CAPTURE_START        0x04
#define VA_SESSION_STAGE_VOICE_CAPTURE_END            0x08

/* SBC Encoder Params masks */
#define VA_SBC_SAMPL_FREQ                    0x3e80 

#define VA_SBC_NUM_BCK                       0x10

#define VA_SBC_SUB_BAND                      0x08

/* Bit pool for 16KHz */
#define VA_SBC_BIT_POOL             28

/* Check whether HFP is in call or not. */
#define VA_IS_NOT_IN_HFP_CALL \
    ((hfp_call_state_idle == sinkCallManagerGetHfpCallState(hfp_primary_link))\
      && (hfp_call_state_idle == sinkCallManagerGetHfpCallState(hfp_secondary_link)))

/* Check whether VA session is on-going. */
#define VA_IS_SESSION_RUNNING \
    ((VaGetState() == va_state_session_started)\
        || (VaGetState() == va_state_voice_in_progress)\
        || (VaGetState() == va_state_session_cancelling))

/* VA events IDs */
typedef enum __va_event_id
{
     /*! start the session  */
    va_event_start_session,                         /* 0 */
    
    /*! indicate to start capture of mic data */
    va_event_start_voice_capture,               /* 1 */

     /*! indicate to stop the capture */
    va_event_stop_voice_capture,              /* 2 */

     /*! cancel the on-going session */
    va_event_cancel_session,                     /* 3 */

    /*! indicate the active session got cancelled */
    va_event_session_cancelled,               /* 4 */

    /*! indicate start of the answer for the active session  */
    va_event_answer_start,                         /* 5 */

    /*! indicate stop of the answer for the active session  */
    va_event_answer_stop,                      /* 6 */
    
    /*! indicate to abort the on-going session  */
    va_event_abort_session,                      /* 7 */

    /* Update gap_events[] array if adding new item */
    va_event_last                      /* Always leave as last item in enum */ 
} va_event_id_t;

/* VA states */
typedef enum __va_state
{
    /*! Idle state, not busy in session   */
    va_state_idle,                                                 /* 0 */

    /*! Trigger for new session */
    va_state_session_started,                               /* 1 */

    /*! voice capture session in progress */
    va_state_voice_in_progress,                       /* 2 */

    /*! Cancelling the ongoing session */
    va_state_session_cancelling,                         /* 3 */

    /* Update gap_states[] array if adding new item */
    va_state_last                      /* Always leave as last item in enum */
} va_state_t;

typedef struct __va
{
    TaskData   task; /*! VA task handler */
    va_state_t state; /*! Current VA state */
    uint8         session_stage; /*! mask to indicate the current stage in the session */
}va_t;

static va_t va;

/* VA event structure */
typedef struct __va_event
{
    va_event_id_t id;
    /* TODO SS78: if any arg is req */
    /*va_event_args_t *args;*/
} va_event_t;

typedef struct __va_configuration
{
    uint16 cmd_rsp_timeout_s;
} va_configuration_t;

/* Default BLE configuration */
static const va_configuration_t va_config = {
                        1,   /* command rsp timeout */
};

#ifdef DEBUG_VA
#define VA_INFO(x) DEBUG(x)
const char * const va_states[va_state_last] = {
    "IDLE",
    "SESSION_STARTED",
    "VOICE_IN_PROGRESS",
    "SESSION_CANCELLING",
};
const char * const va_events[va_event_last] = {
    "START_SESSION",
    "START_VOICE_CAPTURE",
    "STOP_VOICE_CAPTURE",
    "CANCEL_SESSION",
    "SESSION_CANCELLED",
    "ASNWER_START",
    "ANSWER_STOP",
    "ABORT_SESSION",
};
#else
#define VA_INFO(x)
#endif /* DEBUG_VA */


/* Forward Decleration for VA Eveet handling Function */
static void VaHandleEvent(va_event_t event);

/****************Helper Funtions to access the VA instance****************************/
/* helper function to set the new state */
static void VaSetState(va_state_t new_state)
{
    VA_INFO(("Changing VA state from %s to %s\n", va_states[va.state], va_states[new_state]));
    va.state = new_state;
}
/* Helper function to get the current state */
static va_state_t VaGetState(void)
{
    VA_INFO(("VA state is %s\n",va_states[va.state]));
    return va.state;
}
/* helper function to set Session Active flag */
static void VaSetSessionStage(uint8 stage)
{
    va.session_stage = stage;
}
/* helper function to get Session Active flag */
static bool VaIsSessionStageIdle(void)
{
    VA_INFO(("VA Session Stage is %d\n", va.session_stage));
    return ((va.session_stage & VA_SESSION_STAGE_IDLE) != 0);
}

/* helper function to get Session Active flag */
static bool VaIsSessionStageVoiceCaptureStart(void)
{
    VA_INFO(("VA Session Stage is %d\n", va.session_stage));
    return ((va.session_stage & VA_SESSION_STAGE_VOICE_CAPTURE_START) != 0);
}

static bool VaIsSessionStageVoiceCaptureEnd(void)
{
    VA_INFO(("VA Session Stage is %d\n", va.session_stage));
    return ((va.session_stage & VA_SESSION_STAGE_VOICE_CAPTURE_END) != 0);
}

/****************Helper Funtions to configure VA****************************/
static const va_configuration_t *VaGetConfiguration(void)
{
    return &va_config;
} 

/* Helper function to start the cmd rsp timer */
static void VaStartCommandRspTimer(void)
{
    uint16 cmd_rsp_timeout = VaGetConfiguration()->cmd_rsp_timeout_s;
    MessageCancelAll(VaGetTask(), VA_COMMAND_RSP_TIMEOUT_MSG);
    /* Post the Start Session message, once we go to idle state */
    MessageSendLater(VaGetTask(), VA_COMMAND_RSP_TIMEOUT_MSG, NULL, D_SEC(cmd_rsp_timeout));
}
/* Helper function to stop the cmd rsp timer */
static void VaStopCommandRspTimer(void)
{
    MessageCancelAll(VaGetTask(), VA_COMMAND_RSP_TIMEOUT_MSG);
}

/****************Helper Funtions to trigger VA events****************************/
/* utility function to trigger start_voice_capture event */
static void VaStartVoiceCaptureEvent(void)
{
    va_event_t event;
    /* TODO SS78: What if USB/Line-in or A2DP is already playing? */
    event.id = va_event_start_voice_capture;
    VaHandleEvent(event);
}

/* utility function to trigger stop_voice_capture event */
static void VaStopVoiceCaptureEvent(void)
{
    va_event_t event;
    event.id = va_event_stop_voice_capture;
    VaHandleEvent(event);
}

/* utility function to trigger va_session_cancelled event */
static void VaSessionCancelledEvent(void)
{
    va_event_t event;
    
    event.id = va_event_session_cancelled;
    VaHandleEvent(event);
}

/* utility function to trigger va_start_session event */
static void VaStartSessionEvent(void)
{
     va_event_t event;

    event.id = va_event_start_session;
    VaHandleEvent(event);
}

/* utility function to trigger va_cancel_session event */
static void VaCancelSessionEvent(void)
{
    va_event_t event;
    
    event.id = va_event_cancel_session;
    VaHandleEvent(event);
}

/* utility function to trigger va_cancel_session event */
static void VaAnswerStartEvent(void)
{
    va_event_t event;

    event.id = va_event_answer_start;
    VaHandleEvent(event);
}
/* utility function to trigger va_cancel_session event */
static void VaAnswerStopEvent(void)
{
    va_event_t event;

    event.id = va_event_answer_stop;
    VaHandleEvent(event);
}

/* utility function to trigger va_event_abort_session event */
static void VaAbortSessionEvent(void)
{
    va_event_t event;

    event.id = va_event_abort_session;
    VaHandleEvent(event);
}

/****************Utility VA functions****************************/
/*Helper function to setup mic params */
static void VaLoadSbcEncoderParams(sbc_encoder_params_t *sbcEncParams)
{
    sbcEncParams->allocation_method= sbc_encoder_allocation_method_snr;
    sbcEncParams->channel_mode= sbc_encoder_channel_mode_mono;
    sbcEncParams->number_of_blocks=VA_SBC_NUM_BCK;
    sbcEncParams->number_of_subbands=VA_SBC_SUB_BAND;
    sbcEncParams->sample_rate=VA_SBC_SAMPL_FREQ;
    sbcEncParams->bitpool_size = VA_SBC_BIT_POOL;
}
/*Helper function to start voice capture */
static void VaStartVoiceCapture(void)
{
    sbc_encoder_params_t param;
    /* configure the mic */
    /* Mic parameters as per HFP single mic use case */
    AudioConfigSetVaMicParams(sinkAudioGetMic1aParams());
    /* Load the sbc encoder params*/
    VaLoadSbcEncoderParams(&param);
    /* Configure SBC encoder params */
    AudioConfigSetSbcEncoderParams(param);

    /* Trigger the tone for user to start speaking */
    sinkAudioIndicationPlayEvent(EventSysVAStartVoiceCapture);
    /* Start capturing of voice data */
    AudioStartVoiceCapture(VaGetTask());

     /* Sending this event to main so that any additional handling can be done */
    MessageSend(sinkGetMainTask(), EventSysVAStartVoiceCapture , 0);
}

/*Helper function to stop va plugin and packetiser  */
static void VaStopVoiceCapture(void)
{
    /* Stop capturing mic data, as the VA session is done,
    just wait for response */
    AudioStopVoiceCapture();
    /* Stop VA packetiser */
    VaPacketiserStop();
}

static void VaExitActiveSession(void)
{
    /* No active session */
    VaSetState(va_state_idle);
    /* We are done with active session */
    VaSetSessionStage(VA_SESSION_STAGE_IDLE);
}

/*Utility function to check existing A2DP link  */
static bool VaIsA2dpConnected(void)
{
    a2dp_index_t index;
    /* Currently not thinking of multi-point scenario, as its mutually exclusive feature w.r.t VA.
        Else we need to also check if A2DP source is the one with which GAIA is connected */
    return findCurrentA2dpSource(&index);
}

/****************************************
Handles the events in Idle state */
static void VaHandleEventsInIdle(va_event_id_t event)
{
    switch(event)
    {
        case va_event_start_session:
            {
                /* Trigger IVOR_START command via GAIA transport */
                gaiaVoiceAssistantStart();
                /* change the state */
                VaSetState(va_state_session_started);
                /* Session is in triggered stage now */
                VaSetSessionStage(VA_SESSION_STAGE_TRIGGERED);
                /* We need to start the cmd response timer */
                VaStartCommandRspTimer();
            }
            break;
            
        case va_event_stop_voice_capture:
        case va_event_cancel_session:
        case va_event_session_cancelled:
        case va_event_answer_start:
        case va_event_answer_stop:
        case va_event_abort_session:
            VA_INFO(("This event is not expected in this state\n"));
            break;

        default:
            VA_INFO(("Unkown Event\n"));
            break;
    }
}

/****************************************
Handles the events in session started state */
static void VaHandleEventsInSessionStarted(va_event_id_t event)
{
    switch(event)
    {
        case va_event_start_voice_capture:
            {  /* Only if its new session */
                if(!VaIsSessionStageVoiceCaptureStart() &&
                   !VaIsSessionStageVoiceCaptureEnd())
                {
                    VaStartVoiceCapture();
                    /* Move to the next state */
                    VaSetState(va_state_voice_in_progress);
                    /* An active session is triggered */
                    VaSetSessionStage(VA_SESSION_STAGE_VOICE_CAPTURE_START);
                    VA_INFO(("VA Active Session Started\n"));
                }
                else
                    VA_INFO(("VA Already an active session in progress\n"));
            }
            break;

        case va_event_cancel_session:
            {
                gaiaVoiceAssistantCancel();
                /* Move the state */
                VaSetState(va_state_session_cancelling);
                VaStartCommandRspTimer();
            }
            break;
            
        case va_event_session_cancelled:
            /* VA session needs to be cancelled. Since 
                we haven't started to capture any voice data
                just move to idle state */
            VaExitActiveSession();
            break;

        case va_event_answer_start:
            {
                VA_INFO(("VA Answer started\n"));
            }
            break;
            
        case va_event_answer_stop:            
            {
                VA_INFO(("VA Active Session Stopped\n"));
                /* We are done with one session */
                VaSetSessionStage(VA_SESSION_STAGE_IDLE);
            }
            break;

        case va_event_start_session:
            {
                /* Allow only if its new session */
                if(VaIsSessionStageIdle())
                {
                    /* Trigger IVOR_START command via GAIA transport */
                    gaiaVoiceAssistantStart();
                    /* An active session is triggered */
                    VaSetSessionStage(VA_SESSION_STAGE_TRIGGERED);
                    VaStartCommandRspTimer();
                    VA_INFO(("VA Active Session Started\n"));
                }
                else
                    VA_INFO(("VA Already an active session in progress\n"));
            }
            break;
            
        case va_event_abort_session:
            {
                VaStopCommandRspTimer();
                gaiaVoiceAssistantCancel();
                VaExitActiveSession();
            }
            break;

        case va_event_stop_voice_capture:
            VA_INFO(("This event is not expected in this state\n"));
            break;

        default:
            VA_INFO(("Unkown Event\n"));
            break;
    }
}

/****************************************
Handles the events when VA voice capture in progress */
static void VaHandleEventInVoiceInProgress(va_event_id_t event)
{
    switch(event)
    {
        case va_event_stop_voice_capture:
        case va_event_session_cancelled:
            {
                VaStopVoiceCapture();               
                if(event == va_event_session_cancelled)
                    VaExitActiveSession();
                else
                {
                    /* Host might again ask to start voice capture, so move to session_started state to be ready */
                    VaSetState(va_state_session_started);
                    VaSetSessionStage(VA_SESSION_STAGE_VOICE_CAPTURE_END);
                }
            }
            break;

        case va_event_cancel_session:
            {
                gaiaVoiceAssistantCancel();
                /* Move the state */
                VaSetState(va_state_session_cancelling);
                VaStartCommandRspTimer();
            }
            break;

        case va_event_abort_session:
            {
                gaiaVoiceAssistantCancel();
                VaStopVoiceCapture();
                VaExitActiveSession();
            }
            break;

        case va_event_start_session:
        case va_event_start_voice_capture:
        case va_event_answer_start:
        case va_event_answer_stop:            
            VA_INFO(("This event is not expected in this state\n"));
            break;

        default:
            VA_INFO(("Unkown Event\n"));
            break;
    }
}

/****************************************
Handles the events when VA session in progress */
static void VaHandleEventInSessionCancelling(va_event_id_t event)
{
    switch(event)
    {
        case va_event_session_cancelled:
            {
                VaStopVoiceCapture();
                VaExitActiveSession();
            }
            break;

        case va_event_abort_session:
            {
                VaStopCommandRspTimer();
                VaStopVoiceCapture();
                VaExitActiveSession();
            }
            break;

        case va_event_cancel_session:
        case va_event_stop_voice_capture:
        case va_event_start_voice_capture:
        case va_event_start_session:
        case va_event_answer_start:
        case va_event_answer_stop:
            VA_INFO(("This event can be ignored in this state\n"));
            break;

        default:
            VA_INFO(("Unkown Event\n"));
            break;
    }
}

/******************************************************
  * Handles the VA events based on the state */
static void VaHandleEvent(va_event_t event)
{
    VA_INFO(("Handle VA event: %s in state: %s\n", va_events[event.id], va_states[VaGetState()]));
    
    switch(VaGetState())
    {
        case va_state_idle:
        {
            VaHandleEventsInIdle(event.id);
        }
        break;

        case va_state_session_started:
        {
            VaHandleEventsInSessionStarted(event.id);
        }
        break;

        case va_state_voice_in_progress:
        {
            VaHandleEventInVoiceInProgress(event.id);
        }
        break;

        case va_state_session_cancelling:
        {
            VaHandleEventInSessionCancelling(event.id);
        }
        break;

        default:
            break;
    }
}

/*************************************************************************
NAME
    SinkVaHandleMessages

DESCRIPTION
    Handles messages dedicated to VA

RETURNS

*/
void SinkVaHandleMessages(Task task, MessageId id, Message message)
{
    UNUSED(task);

    switch(id)
    {
        case AUDIO_VA_INDICATE_DATA_SOURCE:
            {
                /* check if we are in proper state to accept the source */
                if(VaGetState() == va_state_voice_in_progress)
                {
                    /* Got the mic source, now trigger the VA packetizer. It shall 
                        add the required IVOR header and send it via GAIA transport */
                    AUDIO_VA_INDICATE_DATA_SOURCE_T *res = (AUDIO_VA_INDICATE_DATA_SOURCE_T*)(message);
                    VaPacketiserStart(res->data_src);
                }
            }
            break;

        case VA_COMMAND_RSP_TIMEOUT_MSG:
            {
                /* Command timed out. Need to get back to stable state*/
                VaStopVoiceCapture();
                VaExitActiveSession();
                /* Command timed-out, play the error tone to indicate the same to user */
                MessageSend(sinkGetMainTask(), EventSysVASessionError , 0);
            }
            break;
            
        default:
            break;
    }
}

/*****************Interface Functions***********************/    
void SinkVaInit(void)
{
    /* Set the inital values */
    VaSetState(va_state_idle);
    VaSetSessionStage(VA_SESSION_STAGE_IDLE);

    /* Set the handler */
    va.task.handler = SinkVaHandleMessages;
}

/********************************************************
        Interfaces to trigger the VA events
 ********************************************************/
void SinkVaStartSessionEvent(void)
{
    /* Make sure HFP it not in a call and A2DP SLC should be up!. */
    if ((VA_IS_NOT_IN_HFP_CALL) && VaIsA2dpConnected())
    {
       VaStartSessionEvent();
    }
    else
    {   /* Either in HFP call or No A2DP connection, play the error tone */
        MessageSend(sinkGetMainTask(), EventSysVASessionError , 0);
}
}

void SinkVaCancelSessionEvent(void)
{
    VaCancelSessionEvent();
}

/*******************************************************
        Interfaces to handle the IVOR responses
********************************************************/
void SinkVaHandleStartCfm(bool status)
{
    VaStopCommandRspTimer();

    if(!status)
    {
        /* Failed to start session, play error tone to user */
        MessageSend(sinkGetMainTask(), EventSysVASessionError , 0);
        VaExitActiveSession();
        return;
    }
    /* Successfully started VA session, wait for the remote application to trigger for 
        Mic data */
}

void SinkVaHandleCancelCfm(void)
{
    /* play error tone */
    MessageSend(sinkGetMainTask(), EventSysVASessionError , 0);

    VaStopCommandRspTimer();
    /* Successfully cancelled the VA session */
    VaSessionCancelledEvent();
}

void SinkVaHandleDataReqInd(void)
{
    /*  remote application now requires the va data, so start capturing the voice */
    VaStartVoiceCaptureEvent();
}

void SinkVaHandleCancelInd(void)
{
    /* Stop any cmd_rsp timer running */
    VaStopCommandRspTimer();
    /* The remote application cancel the session, so stop capturing voice data */
    VaSessionCancelledEvent();
    /* Got a cancel from remote application, need to inform user about it */
    MessageSend(sinkGetMainTask(), EventSysVASessionError , 0);
}

void SinkVaHandleVoiceEndInd(void)
{
    VaStopVoiceCaptureEvent();
}

void SinkVaHandleAnswerStartInd(void)
{
    VaAnswerStartEvent();
}
void SinkVaHandleAnswerStopInd(void)
{
    VaAnswerStopEvent();
}

void SinkVaHandlePowerOff(void)
{
    /* Cancel any on-going session */
    SinkVaCancelSessionEvent();
}

void SinkVaHandleDisconnect(void)
{
    /* Its as good as getting cancel indication */
    SinkVaHandleCancelInd();
}

/*******************************************************************************
NAME
    SinkVaAbortOnHFPCall

DESCRIPTION
    @brief Abort the VA session when HFP incoming/outgoing call starts.

PARAMETERS
    None
RETURNS
    None
*/
void SinkVaAbortOnHFPCall(void)
{
    VA_INFO(("SinkVaAbortOnHFPCall\n"));

    /* Abort the VA session when HFP incoming/outgoing call starts. */
    if((VA_IS_SESSION_RUNNING) && !VaIsSessionStageIdle())
    {
        VA_INFO(("VA Aborted\n"));
        VaAbortSessionEvent();
    }
}

/*******************************************************************************
NAME
    SinkVaAbortOnA2dpStream

DESCRIPTION
    @brief Abort the VA session when on A2DP streaming starts and VA is not in
           the answering stage.

PARAMETERS
    None
RETURNS
    None
*/
void SinkVaAbortOnA2dpStream(void)
{
    VA_INFO(("SinkVaAbortOnA2dpStream\n"));

    if((VA_IS_SESSION_RUNNING) && 
       !VaIsSessionStageVoiceCaptureEnd() && !VaIsSessionStageIdle())
    {
        VA_INFO(("VA Aborted\n"));
        VaAbortSessionEvent();
    }
}


#ifdef VA_TEST_BUILD
/*******************************************************************************
NAME
    sinkVaGetState

DESCRIPTION
    @brief ATest hook for unit tests to get VA state
PARAMETERS
    None
RETURNS
    VA state
*/
uint16 sinkVaGetState(void)
{
    return va.state;
}

#endif/* VA_TEST_BUILD */

#endif /* ENABLE_VOICE_ASSISTANT */

