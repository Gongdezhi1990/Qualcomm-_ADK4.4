/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    sink_va.h

DESCRIPTION
    Interface File to manage Voice Assistant Application.
    
NOTES

*/

#ifndef _SINK_VA_H_
#define _SINK_VA_H_

#include "sink_events.h"
#include "sink_audio_routing.h"
#include <message.h>
#include <csrtypes.h>

/*******************************************************************************
NAME
    SinkVaInit
    
DESCRIPTION
    Handles the VA events based on the state
    
PARAMETERS
    event   The VA event
    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaInit(void);
#else
#define SinkVaInit() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleMessages
    
DESCRIPTION
    Handles messages dedicated to VA
    
PARAMETERS
    task   Registered Task
    id      Message ID
    message Data (if any) associated with the ID
    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleMessages(Task task, MessageId id, Message message);
#else
#define SinkVaHandleMessages(task, id, message) ((void)(0))
#endif /* ENABLE_VOICE_ASSISTANT */

/*******************************************************************************
NAME
    SinkVaStartSessionEvent
    
DESCRIPTION
    Triggers the event to start the VA session
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaStartSessionEvent(void);
#else
#define SinkVaStartSessionEvent() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaCancelSessionEvent
    
DESCRIPTION
    Triggers the event to stop the VA session
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaCancelSessionEvent(void);
#else
#define SinkVaCancelSessionEvent() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleStartCfm
    
DESCRIPTION
    Handle the IVOR Session start cfm message
    
PARAMETERS
    status Return status, TRUE if success, else FALSE
    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleStartCfm(bool status);
#else
#define SinkVaHandleStartCfm(status) ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleCancelCfm
    
DESCRIPTION
    Handle the IVOR Session start cfm message
    
PARAMETERS
    None
    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleCancelCfm(void);
#else
#define SinkVaHandleCancelCfm() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleStartCfm
    
DESCRIPTION
    Handle the IVOR Data request indication message from remote application
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleDataReqInd(void);
#else
#define SinkVaHandleDataReqInd() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleCancelInd
    
DESCRIPTION
    Handle IVOR Cancel indication message from remote application
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleCancelInd(void);
#else
#define SinkVaHandleCancelInd() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleVoiceEndInd
    
DESCRIPTION
    Handle IVOR Stop Voice capture indication message from remote application
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleVoiceEndInd(void);
#else
#define SinkVaHandleVoiceEndInd() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleAnswerStartInd
    
DESCRIPTION
    Handle IVOR Answer Start indication message from remote application
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleAnswerStartInd(void);
#else
#define SinkVaHandleAnswerStartInd() ((void)(0))
#endif


/*******************************************************************************
NAME
    SinkVaHandleAnswerStopInd
    
DESCRIPTION
    Handle IVOR Answer Stop indication message from remote application
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleAnswerStopInd(void);
#else
#define SinkVaHandleAnswerStopInd() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandlePowerOff
    
DESCRIPTION
    Handle system power-off event
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandlePowerOff(void);
#else
#define SinkVaHandlePowerOff() ((void)(0))
#endif

/*******************************************************************************
NAME
    SinkVaHandleDisconnect
    
DESCRIPTION
    Handle link disconnect scenario
    
PARAMETERS
    None    
RETURNS
    None
*/
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaHandleDisconnect(void);
#else
#define SinkVaHandleDisconnect() ((void)(0))
#endif

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
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaAbortOnHFPCall(void);
#else
#define SinkVaAbortOnHFPCall() ((void)(0))
#endif /* ENABLE_VOICE_ASSISTANT */

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
#ifdef ENABLE_VOICE_ASSISTANT
void SinkVaAbortOnA2dpStream(void);
#else
#define SinkVaAbortOnA2dpStream() ((void)(0))
#endif /* ENABLE_VOICE_ASSISTANT */



/****************************************************************************
NAME
    sinkVaGetState

DESCRIPTION
    Test hook for unit tests to get VA state

*/
#ifdef VA_TEST_BUILD

#ifdef ENABLE_VOICE_ASSISTANT
uint16 sinkVaGetState(void);
#else
#define sinkVaGetState() (0)
#endif /* ENABLE_VOICE_ASSISTANT */

#endif /* VA_TEST_BUILD */

#endif /*_SINK_VA_H_*/

