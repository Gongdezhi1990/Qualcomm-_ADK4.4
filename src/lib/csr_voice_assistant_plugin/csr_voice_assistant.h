/****************************************************************************
Copyright (c) 2005 - 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_voice_assistant.h

DESCRIPTION
    
    
NOTES
   
*/

#ifndef _CSR_VOICE_ASSISTANT_H_
#define _CSR_VOICE_ASSISTANT_H_

#include "csr_voice_assistant_defs.h"
#include "audio_plugin_if.h"

/****************************************************************************
DESCRIPTION
    Starts the voice capture used for Voice Assistance.
    This is the common place to configure the voice capture for VA
    with/without DSP loaded.
*/
void VoiceAssistantPluginStartCapture(AUDIO_PLUGIN_START_VOICE_CAPTURE_MSG_T *msg);

/****************************************************************************
DESCRIPTION
    Stops the voice capture used for Voice Assistance.
*/

void VoiceAssistantPluginStopCapture(void);

/****************************************************************************
DESCRIPTION
   retrieve the context from Voice Assistant
*/
va_context_t *VoiceAssistantGetContext(void);

#endif


