/****************************************************************************
Copyright (c) 2015 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    voice_assistant_dsp_if.h
 
DESCRIPTION
    DSP interface. It's implementation depends on underlying hardware.
*/

#ifndef CSR_VOICE_ASSISTANT_DSP_IF_H_
#define CSR_VOICE_ASSISTANT_DSP_IF_H_

#include <csrtypes.h>
#include "csr_voice_assistant_defs.h"
/*Encoder Params*/
#define VA_SBC_ENCODER_PARAMS 0x0133 /*Default Encoder Params */
#define VA_SBC_ENCODER_BITPOOL 0x001c /* Default Bitpool for SBC*/

/*******************************************************************************
DESCRIPTION
    Start Voice Assistant towards DSP.
*/
void VoiceAssistantDspStart(void);

/*******************************************************************************
DESCRIPTION
    Stop the DSP with respect to Voice assistant.
*/
void VoiceAssistantDspStop(void);

/*******************************************************************************
DESCRIPTION
    Message handler for DSP messages.
*/
void AudioPluginVaDspMessageHandler(Task task, Message message);

#endif /* CSR_VOICE_ASSISTANT_DSP_IF_H_ */
