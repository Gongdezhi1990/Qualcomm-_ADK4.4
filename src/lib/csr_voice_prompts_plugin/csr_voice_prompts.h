/****************************************************************************
Copyright (c) 2005 - 2017 Qualcomm Technologies International, Ltd.

FILE NAME
    csr_voice_prompts.h

DESCRIPTION
    
    
NOTES
   
*/

#ifndef _CSR_SIMPLE_TESXT_TO_SPEECH_H_
#define _CSR_SIMPLE_TESXT_TO_SPEECH_H_

#include "voice_prompts_defs.h"

vp_context_t *VoicePromptsGetContext(void);


void CsrVoicePromptsPluginPlayPhrase(FILE_INDEX prompt_index , FILE_INDEX prompt_header_index, int16 ap_volume , AudioPluginFeatures features, Task app_task);
void CsrVoicePromptsPluginStopPhrase ( void ) ;
void CsrVoicePromptsPluginPlayTone (const ringtone_note * tone, AudioPluginFeatures features);
void CsrVoicePromptsPluginHandleStreamDisconnect(void);

#ifdef HOSTED_TEST_ENVIRONMENT
void CsrVoicePromptsPluginTestReset(void);
#endif

#endif


